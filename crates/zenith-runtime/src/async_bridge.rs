//! Luau Promise and Async Worker Bridge.
//!
//! Exposes `Zenith.Promise`, `Zenith.spawn`, and `Zenith.delay` to Luau scripts,
//! dispatching completion callbacks on the main VM thread without blocking graphics rendering.

use std::sync::Arc;
use std::time::Duration;
use mlua::prelude::*;
use crate::worker::{TaskCompletion, TaskOutput, WorkerThreadPool};

const PENDING_PROMISES_KEY: &str = "__zenith_pending_promises";

/// Bootstraps the Luau Promise prototype and binds async primitives to the `Zenith` table.
pub fn setup_async_bridge(
    lua: &Lua,
    zenith_table: &LuaTable,
    pool: Arc<WorkerThreadPool>,
) -> Result<(), LuaError> {
    // Registry table tracking pending promise resolve/reject callbacks indexed by taskId
    let pending_table = lua.create_table()?;
    lua.set_named_registry_value(PENDING_PROMISES_KEY, pending_table)?;

    // Native Luau Promise implementation
    let promise_init_code = r#"
        local Promise = {}
        Promise.__index = Promise

        function Promise.new(executor)
            local self = setmetatable({
                _state = "pending", -- "pending" | "fulfilled" | "rejected"
                _value = nil,
                _handlers = {},
            }, Promise)

            local function resolve(val)
                if self._state ~= "pending" then return end
                self._state = "fulfilled"
                self._value = val
                for _, h in ipairs(self._handlers) do
                    if h.onFulfilled then
                        pcall(h.onFulfilled, val)
                    end
                    if h.onFinally then
                        pcall(h.onFinally)
                    end
                end
                self._handlers = {}
            end

            local function reject(err)
                if self._state ~= "pending" then return end
                self._state = "rejected"
                self._value = err
                for _, h in ipairs(self._handlers) do
                    if h.onRejected then
                        pcall(h.onRejected, err)
                    end
                    if h.onFinally then
                        pcall(h.onFinally)
                    end
                end
                self._handlers = {}
            end

            local ok, err = pcall(executor, resolve, reject)
            if not ok then
                reject(err)
            end
            return self
        end

        function Promise:andThen(onFulfilled, onRejected)
            return Promise.new(function(resolve, reject)
                local function handle()
                    if self._state == "fulfilled" then
                        if onFulfilled then
                            local ok, res = pcall(onFulfilled, self._value)
                            if ok then resolve(res) else reject(res) end
                        else
                            resolve(self._value)
                        end
                    elseif self._state == "rejected" then
                        if onRejected then
                            local ok, res = pcall(onRejected, self._value)
                            if ok then resolve(res) else reject(res) end
                        else
                            reject(self._value)
                        end
                    end
                end

                if self._state == "pending" then
                    table.insert(self._handlers, {
                        onFulfilled = function(val)
                            if onFulfilled then
                                local ok, res = pcall(onFulfilled, val)
                                if ok then resolve(res) else reject(res) end
                            else
                                resolve(val)
                            end
                        end,
                        onRejected = function(err)
                            if onRejected then
                                local ok, res = pcall(onRejected, err)
                                if ok then resolve(res) else reject(res) end
                            else
                                reject(err)
                            end
                        end,
                    })
                else
                    handle()
                end
            end)
        end

        function Promise:catch(onRejected)
            return self:andThen(nil, onRejected)
        end

        function Promise:finally(onFinally)
            return self:andThen(
                function(val)
                    pcall(onFinally)
                    return val
                end,
                function(err)
                    pcall(onFinally)
                    error(err)
                end
            )
        end

        function Promise.resolve(val)
            return Promise.new(function(res) res(val) end)
        end

        function Promise.reject(err)
            return Promise.new(function(_, rej) rej(err) end)
        end

        function Promise.all(promises)
            return Promise.new(function(resolve, reject)
                local results = {}
                local count = #promises
                if count == 0 then
                    resolve(results)
                    return
                end
                local completed = 0
                for idx, p in ipairs(promises) do
                    p:andThen(function(val)
                        results[idx] = val
                        completed = completed + 1
                        if completed == count then
                            resolve(results)
                        end
                    end, reject)
                end
            end)
        end

        return Promise
    "#;

    let promise_table: LuaTable = lua.load(promise_init_code).eval()?;
    zenith_table.set("Promise", promise_table.clone())?;

    // Zenith.spawn(cmd, args, timeout_ms): Promise<{ stdout: string, stderr: string, code: number }>
    let pool_spawn = Arc::clone(&pool);
    let p_ctor_spawn = promise_table.clone();
    let spawn_fn = lua.create_function(
        move |lua, (cmd, args, timeout_ms): (String, Option<Vec<String>>, Option<u64>)| {
            let args_vec = args.unwrap_or_default();
            let timeout = timeout_ms.map(Duration::from_millis);
            let task_id = pool_spawn.spawn_process_with_timeout(cmd, args_vec, timeout);

            let new_fn: LuaFunction = p_ctor_spawn.get("new")?;
            let executor = lua.create_function(move |lua, (resolve, reject): (LuaFunction, LuaFunction)| {
                let pending: LuaTable = lua.named_registry_value(PENDING_PROMISES_KEY)?;
                let pair = lua.create_table()?;
                pair.set("resolve", resolve)?;
                pair.set("reject", reject)?;
                pending.set(task_id, pair)?;
                Ok(())
            })?;

            new_fn.call::<LuaTable>(executor)
        },
    )?;
    zenith_table.set("spawn", spawn_fn.clone())?;
    zenith_table.set("spawn_async", spawn_fn)?;

    // Zenith.cancel(task_id): boolean
    let pool_cancel = Arc::clone(&pool);
    let cancel_fn = lua.create_function(move |_, task_id: u64| {
        Ok(pool_cancel.cancel_task(task_id))
    })?;
    zenith_table.set("cancel", cancel_fn)?;

    // Zenith.delay(ms): Promise<nil>
    let pool_delay = Arc::clone(&pool);
    let p_ctor_delay = promise_table.clone();
    let delay_fn = lua.create_function(move |lua, ms: u64| {
        let task_id = pool_delay.delay(Duration::from_millis(ms));

        let new_fn: LuaFunction = p_ctor_delay.get("new")?;
        let executor = lua.create_function(move |lua, (resolve, reject): (LuaFunction, LuaFunction)| {
            let pending: LuaTable = lua.named_registry_value(PENDING_PROMISES_KEY)?;
            let pair = lua.create_table()?;
            pair.set("resolve", resolve)?;
            pair.set("reject", reject)?;
            pending.set(task_id, pair)?;
            Ok(())
        })?;

        new_fn.call::<LuaTable>(executor)
    })?;
    zenith_table.set("delay", delay_fn.clone())?;
    zenith_table.set("timeout", delay_fn)?;

    Ok(())
}

/// Polls and resolves all completed background tasks in the main Luau VM context.
pub fn poll_async_completions(lua: &Lua, pool: &WorkerThreadPool) -> Result<usize, LuaError> {
    let completions = pool.try_recv_completions();
    if completions.is_empty() {
        return Ok(0);
    }

    let count = completions.len();
    let pending: LuaTable = lua.named_registry_value(PENDING_PROMISES_KEY)?;

    for TaskCompletion { task_id, result } in completions {
        let pair_opt: Option<LuaTable> = pending.get(task_id)?;
        if let Some(pair) = pair_opt {
            match result {
                Ok(output) => {
                    let resolve_fn: Option<LuaFunction> = pair.get("resolve").ok();
                    if let Some(func) = resolve_fn {
                        let lua_val = match output {
                            TaskOutput::Process { stdout, stderr, exit_code } => {
                                let tbl = lua.create_table()?;
                                tbl.set("stdout", stdout)?;
                                tbl.set("stderr", stderr)?;
                                tbl.set("code", exit_code)?;
                                LuaValue::Table(tbl)
                            }
                            TaskOutput::Text(t) => LuaValue::String(lua.create_string(&t)?),
                            TaskOutput::Empty => LuaValue::Nil,
                        };
                        let _ = func.call::<()>(lua_val);
                    }
                }
                Err(err) => {
                    let reject_fn: Option<LuaFunction> = pair.get("reject").ok();
                    if let Some(func) = reject_fn {
                        let _ = func.call::<()>(err);
                    }
                }
            }
            let _ = pending.set(task_id, LuaValue::Nil);
        }
    }

    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_promise_resolve_and_then() -> Result<(), LuaError> {
        let lua = Lua::new();
        let zenith_tbl = lua.create_table()?;
        let pool = Arc::new(WorkerThreadPool::new(2));

        setup_async_bridge(&lua, &zenith_tbl, pool)?;
        lua.globals().set("Zenith", zenith_tbl)?;

        let script = r#"
            local result = nil
            Zenith.Promise.resolve("hello_zenith"):andThen(function(val)
                result = val
            end)
            return result
        "#;

        let res: String = lua.load(script).eval()?;
        assert_eq!(res, "hello_zenith");
        Ok(())
    }

    #[test]
    fn test_promise_reject_and_catch() -> Result<(), LuaError> {
        let lua = Lua::new();
        let zenith_tbl = lua.create_table()?;
        let pool = Arc::new(WorkerThreadPool::new(2));

        setup_async_bridge(&lua, &zenith_tbl, pool)?;
        lua.globals().set("Zenith", zenith_tbl)?;

        let script = r#"
            local caught = nil
            Zenith.Promise.reject("fatal_error"):catch(function(err)
                caught = err
            end)
            return caught
        "#;

        let res: String = lua.load(script).eval()?;
        assert_eq!(res, "fatal_error");
        Ok(())
    }

    #[test]
    fn test_async_spawn_and_poll() -> Result<(), LuaError> {
        let lua = Lua::new();
        let zenith_tbl = lua.create_table()?;
        let pool = Arc::new(WorkerThreadPool::new(2));

        setup_async_bridge(&lua, &zenith_tbl, Arc::clone(&pool))?;
        lua.globals().set("Zenith", zenith_tbl)?;

        let script = r#"
            _G.async_res = nil
            Zenith.spawn("echo", {"background_worker_ok"}):andThen(function(out)
                _G.async_res = out.stdout
            end)
        "#;
        lua.load(script).exec()?;

        // Wait for background worker
        let start = std::time::Instant::now();
        let mut resolved = 0;
        while start.elapsed() < Duration::from_millis(5000) {
            std::thread::sleep(Duration::from_millis(20));
            resolved += poll_async_completions(&lua, &pool)?;
            if resolved >= 1 {
                break;
            }
        }
        assert_eq!(resolved, 1);

        let final_val: String = lua.load("return _G.async_res").eval()?;
        assert!(final_val.contains("background_worker_ok"));

        Ok(())
    }

    #[test]
    fn test_async_spawn_timeout() -> Result<(), LuaError> {
        let lua = Lua::new();
        let zenith_tbl = lua.create_table()?;
        let pool = Arc::new(WorkerThreadPool::new(2));

        setup_async_bridge(&lua, &zenith_tbl, Arc::clone(&pool))?;
        lua.globals().set("Zenith", zenith_tbl)?;

        let script = r#"
            _G.timeout_err = nil
            Zenith.spawn("sleep", {"5"}, 50):catch(function(err)
                _G.timeout_err = err
            end)
        "#;
        lua.load(script).exec()?;

        let start = std::time::Instant::now();
        let mut resolved = 0;
        while start.elapsed() < Duration::from_millis(5000) {
            std::thread::sleep(Duration::from_millis(20));
            resolved += poll_async_completions(&lua, &pool)?;
            if resolved >= 1 {
                break;
            }
        }
        assert_eq!(resolved, 1);

        let final_err: String = lua.load("return _G.timeout_err").eval()?;
        assert!(final_err.contains("timed out"));

        Ok(())
    }
}
