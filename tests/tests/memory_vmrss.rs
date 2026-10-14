//! Empirical Memory Diagnostics & VmRSS Stability Verification.

use std::sync::Mutex;
use zenith_cli::{read_self_memory, read_vmrss_kb};
use zenith_tests::{realistic_bar_script, realistic_complex_subsystems_script};
use zenith_wayland::HeadlessEngine;

static MEMORY_MUTEX: Mutex<()> = Mutex::new(());

#[test]
fn test_vmrss_reading_accuracy() {
    let _lock = MEMORY_MUTEX.lock().unwrap();
    let (vmrss_mb, heap_mb) = read_self_memory();
    let vmrss_kb = read_vmrss_kb();

    println!("Process Diagnostics -> VmRSS: {:.2} MB, Heap: {:.2} MB", vmrss_mb, heap_mb);

    assert!(vmrss_mb > 0.0, "VmRSS should be greater than 0 on Linux");
    assert!(heap_mb > 0.0, "Heap estimate should be greater than 0 on Linux");
    assert!(vmrss_kb.is_some(), "read_vmrss_kb should return Some value on Linux");

    // Ensure test runner process VmRSS is within expected debug bounds
    assert!(
        vmrss_mb < 25.0,
        "Base process VmRSS ({:.2} MB) exceeded expected test runner bounds",
        vmrss_mb
    );

    let kb = vmrss_kb.unwrap();
    let mb_from_kb = (kb as f64) / 1024.0;
    let diff = (vmrss_mb - mb_from_kb).abs();
    assert!(diff < 15.0, "VmRSS MB and KB readings should be consistent (diff: {:.2} MB)", diff);
}

#[test]
fn test_vmrss_stability_across_100_reloads() {
    let _lock = MEMORY_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    // Warmup 5 runs
    for i in 0..5 {
        let script = realistic_bar_script(&format!("warmup-{}", i), i, 100);
        let _ = engine.compute_layout(&script, 1920, 42).expect("Warmup layout failed");
    }

    let (initial_rss, initial_heap) = read_self_memory();
    println!("Baseline Memory -> VmRSS: {:.2} MB, Heap: {:.2} MB", initial_rss, initial_heap);

    let iterations = 100;
    for i in 0..iterations {
        let clock = format!("cycle-{:04}", i);
        let script = realistic_bar_script(&clock, (i * 3) % 100, 100 - (i % 20));
        let boxes = engine.compute_layout(&script, 1920, 42).expect("Layout compute failed");
        assert!(!boxes.is_empty());
    }

    let (final_rss, final_heap) = read_self_memory();
    let rss_delta = final_rss - initial_rss;
    let heap_delta = final_heap - initial_heap;

    println!(
        "Post-100-Reloads -> VmRSS: {:.2} MB (Δ: {:+.2} MB), Heap: {:.2} MB (Δ: {:+.2} MB)",
        final_rss, rss_delta, final_heap, heap_delta
    );

    // Target SLA verification: Zero memory leak across 100 reloads (RSS growth strictly < 5.0 MB)
    assert!(
        rss_delta < 5.0,
        "VmRSS delta ({:.2} MB) exceeded leak threshold of 5.0 MB across 100 reloads",
        rss_delta
    );
}

#[test]
fn test_vmrss_complex_subsystems_stability() {
    let _lock = MEMORY_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");

    // Warmup 3 runs with complex script (Sliders, Switches, TextInputs, Shaders, Shadows)
    for i in 0..3 {
        let script = realistic_complex_subsystems_script(20.0 + (i as f32) * 10.0, i % 2 == 0, "warmup");
        let _ = engine.compute_layout(&script, 800, 500).expect("Warmup complex failed");
    }

    let (initial_rss, initial_heap) = read_self_memory();
    println!("Complex Subsystems Baseline -> VmRSS: {:.2} MB, Heap: {:.2} MB", initial_rss, initial_heap);

    let iterations = 50;
    for i in 0..iterations {
        let slider_val = ((i * 7) % 100) as f32;
        let switch_val = i % 2 == 0;
        let query = format!("filter_{}", i);
        let script = realistic_complex_subsystems_script(slider_val, switch_val, &query);
        let boxes = engine.compute_layout(&script, 800, 500).expect("Complex layout failed");
        assert!(!boxes.is_empty());
    }

    let (final_rss, final_heap) = read_self_memory();
    let rss_delta = final_rss - initial_rss;
    let heap_delta = final_heap - initial_heap;

    println!(
        "Post-50-Complex-Cycles -> VmRSS: {:.2} MB (Δ: {:+.2} MB), Heap: {:.2} MB (Δ: {:+.2} MB)",
        final_rss, rss_delta, final_heap, heap_delta
    );

    // Assert that complex subsystems evaluation does not leak memory (delta < 5.0 MB)
    assert!(
        rss_delta < 5.0,
        "VmRSS delta ({:.2} MB) exceeded leak threshold of 5.0 MB for complex subsystems",
        rss_delta
    );
}

#[test]
fn test_storage_and_worker_memory_stability() {
    let _lock = MEMORY_MUTEX.lock().unwrap();
    use zenith_runtime::storage::StorageEngine;
    use zenith_runtime::worker::WorkerThreadPool;

    let storage = StorageEngine::new(None);
    let worker_pool = WorkerThreadPool::new(2);

    let (initial_rss, _) = read_self_memory();

    // 50 storage writes, reads, and worker tasks
    for i in 0..50 {
        let key = format!("k_{}", i);
        let val = serde_json::json!({ "index": i, "status": "active" });
        let _ = storage.set(&key, val);
        assert!(storage.get(&key).is_some());

        // Spawn a lightweight task on worker pool
        let _id = worker_pool.spawn_process("true".to_string(), vec![]);
    }

    // Give worker pool brief instant to complete tasks
    std::thread::sleep(std::time::Duration::from_millis(100));

    let (final_rss, _) = read_self_memory();
    let rss_delta = final_rss - initial_rss;

    println!("Storage & Worker Post-Run -> VmRSS: {:.2} MB (Δ: {:+.2} MB)", final_rss, rss_delta);

    // Assert zero memory leak from async tasks and storage in memory
    assert!(
        rss_delta < 5.0,
        "VmRSS delta ({:.2} MB) exceeded threshold for storage and worker pool",
        rss_delta
    );
}

#[test]
fn test_headless_render_buffer_memory_stability() {
    let _lock = MEMORY_MUTEX.lock().unwrap();
    let mut engine = HeadlessEngine::new().expect("Failed to initialize HeadlessEngine");
    let script = realistic_bar_script("12:00:00", 20, 80);

    // Warmup 1 frame
    let _ = engine.render_to_buffer(&script, 1920, 42).expect("Render failed");

    let (initial_rss, _) = read_self_memory();

    // Render 20 frames into buffer
    for i in 0..20 {
        let clock = format!("12:00:{:02}", i);
        let s = realistic_bar_script(&clock, i * 4, 100 - i);
        let buf = engine.render_to_buffer(&s, 1920, 42).expect("Render buffer failed");
        assert_eq!(buf.len(), 1920 * 42 * 4);
    }

    let (final_rss, _) = read_self_memory();
    let rss_delta = final_rss - initial_rss;

    println!("Headless Render Buffer -> VmRSS: {:.2} MB (Δ: {:+.2} MB)", final_rss, rss_delta);

    assert!(
        rss_delta < 5.0,
        "SHM rendering buffer memory leaked ({:.2} MB delta)",
        rss_delta
    );
}
