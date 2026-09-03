.pragma library

function makeAction(name, icon, callback) {
    return {
        name: name,
        icon: icon,
        callback: callback
    };
}

function buildFileActions(ctx) {
    var actions = [
        makeAction(ctx.isFolder ? "Abrir Pasta" : "Abrir", ctx.isFolder ? "\u{f07c}" : "\u{f15b}", function() {
            ctx.openPathInManager(ctx.filePath);
        }),
        makeAction("Copiar Caminho", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), ctx.filePath]);
        }),
        makeAction("Excluir", "\u{f1f8}", function() {
            ctx.previewActionProc.exec(["bash", ctx.launcherFileTool, "delete", ctx.filePath]);
        })
    ];

    if (ctx.isFolder) {
        actions.splice(1, 0, makeAction("Abrir Pasta Pai", "\u{f115}", function() {
            ctx.openPathInManager(ctx.parentDirectoryForPath(ctx.filePath));
        }));
        actions.splice(1, 0, makeAction("Terminal aqui", "\u{f120}", function() {
            ctx.openPathInTerminal(ctx.filePath);
        }));
    } else {
        actions.splice(1, 0, makeAction("Abrir na Pasta", "\u{f115}", function() {
            ctx.revealPathInManager(ctx.filePath);
        }));
        if (["nix", "sh", "py", "js", "ts", "qml", "md", "rs", "go", "toml", "json", "yaml", "yml"].indexOf(ctx.ext) >= 0) {
            actions.splice(1, 0, makeAction("Editar", "\u{f121}", function() {
                ctx.openPathInEditor(ctx.filePath);
            }));
        }
    }

    return actions;
}

function buildAppActions(ctx) {
    var actions = [makeAction("Abrir", "\u{f04b}", function() {
        ctx.launchItem(ctx.index);
    })];

    if (typeof ctx.toggleFavorite === "function" && ctx.app && ctx.app.id) {
        actions.push(makeAction(ctx.isFavorite ? "Remover dos Favoritos" : "Adicionar aos Favoritos", "\u{f005}", function() {
            ctx.toggleFavorite();
            return false;
        }));
    }

    if (ctx.execString !== "") {
        actions.push(makeAction("Rodar como Root", "\u{f084}", function() {
            ctx.runLauncherCommand("root", ctx.execString, false);
        }));
        actions.push(makeAction("Rodar no Terminal", "\u{f120}", function() {
            ctx.runLauncherCommand("terminal", ctx.execString, false);
        }));
        actions.push(makeAction("Copiar Exec", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), ctx.execString]);
        }));
    }

    if (ctx.previewRunningWindows.length > 0) {
        var firstWindow = ctx.previewRunningWindows[0];
        actions.push(makeAction("Focar Janela", "\u{f2d0}", function() {
            ctx.closeLauncher();
            ctx.hyprGoToWindow(firstWindow.address, firstWindow.workspaceId, firstWindow.ref);
        }));
        if (firstWindow.address !== "") {
            actions.push(makeAction("Trazer p/ atual", "\u{f0e8}", function() {
                ctx.closeLauncher();
                ctx.hyprMoveWindowToWorkspace(firstWindow.address, ctx.activeWorkspaceId(), firstWindow.ref);
            }));
        }
    }

    if (ctx.app && ctx.app.actions && ctx.app.actions.values) {
        var desktopActions = ctx.app.actions.values;
        for (var i = 0; i < desktopActions.length; i++) {
            (function(desktopAction) {
                actions.push(makeAction(desktopAction.name, "\u{f144}", function() {
                    desktopAction.execute();
                }));
            })(desktopActions[i]);
        }
    }

    if (ctx.dockService) {
        var appRawId = String((ctx.app && ctx.app.id) || "").replace(/\.desktop$/i, "").toLowerCase();
        var pinned = ctx.dockService.pinnedAppIds.indexOf(appRawId) >= 0;
        actions.push(makeAction(pinned ? "Remover da Dock" : "Adicionar à Dock", pinned ? "\u{f08d}" : "\u{f276}", function() {
            ctx.dockService.togglePin(appRawId);
        }));
    }

    if (ctx.app && ctx.app.id) {
        var desktopId = ctx.app.id;
        actions.push(makeAction("Abrir Pasta", "\u{f07c}", function() {
            ctx.commandRunner.exec(["bash", "-c",
                "for d in \"" + ctx.runtimePaths.appDataDir + "/applications\" /run/current-system/sw/share/applications /etc/profiles/per-user/lucas/share/applications; do" +
                "  f=\"$d/" + desktopId + ".desktop\";" +
                "  [ -f \"$f\" ] && thunar \"$d\" && exit;" +
                "done"
            ]);
        }));
    }

    return actions;
}

function buildWindowActions(ctx) {
    return [
        makeAction("Focar Janela", "\u{f2d0}", function() {
            ctx.closeLauncher();
            ctx.hyprGoToWindow(ctx.windowData.address, ctx.windowData.workspaceId, ctx.windowData.ref);
        }),
        makeAction("Trazer p/ atual", "\u{f0e8}", function() {
            ctx.closeLauncher();
            ctx.hyprMoveWindowToWorkspace(ctx.windowData.address, ctx.activeWorkspaceId(), ctx.windowData.ref);
        }),
        makeAction("Fechar", "\u{f00d}", function() {
            ctx.hyprCloseWindow(ctx.windowData.address, ctx.windowData.ref);
            return false;
        })
    ];
}

function buildAudioActions(ctx) {
    return [
        makeAction(ctx.launcherSinkMuted() ? "Desmutar" : "Mutar", ctx.launcherSinkMuted() ? "\u{f028}" : "\u{f026}", function() {
            ctx.launcherToggleMute();
            if (ctx.schedulePreviewUpdate) ctx.schedulePreviewUpdate(ctx.currentIndex);
            return false;
        })
    ];
}

function buildBluetoothActions(ctx) {
    return [
        makeAction(ctx.enabled ? "Desligar" : "Ligar", "\u{f293}", function() {
            ctx.previewActionProc.exec(["bash", ctx.launcherSystemTool, "bt-toggle", ctx.enabled ? "off" : "on"]);
            return false;
        })
    ];
}

function buildWifiActions(ctx) {
    return [
        makeAction(ctx.enabled ? "Desligar Wi-Fi" : "Ligar Wi-Fi", "\u{f1eb}", function() {
            ctx.previewActionProc.exec(["bash", ctx.launcherSystemTool, "wifi-toggle", "toggle"]);
            return false;
        })
    ];
}

function buildPowerActions(ctx) {
    return [
        makeAction("Bloquear", "\u{f023}", function() { ctx.previewActionProc.exec(["hyprlock"]); }),
        makeAction("Suspender", "\u{f4bc}", function() { ctx.previewActionProc.exec(["systemctl", "suspend"]); }),
        makeAction("Logout", "\u{f2f5}", function() { ctx.previewActionProc.exec(["hyprctl", "dispatch", "exit"]); }),
        makeAction("Reiniciar", "\u{f0e2}", function() { ctx.previewActionProc.exec(["systemctl", "reboot"]); }),
        makeAction("Desligar", "\u{f011}", function() { ctx.previewActionProc.exec(["systemctl", "poweroff"]); })
    ];
}

function buildClipboardActions(ctx) {
    return [
        makeAction("Copiar item", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("launcher_cliphist_copy.sh"), ctx.item.result || ""]);
        })
    ];
}

function buildProjectActions(ctx) {
    return [
        makeAction("Abrir no Terminal", "\u{f120}", function() {
            ctx.openPathInTerminal(ctx.item.path || ctx.homeDir);
        }),
        makeAction("Copiar Caminho", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), ctx.item.path || ""]);
        })
    ];
}

function buildSnippetActions(ctx) {
    return [
        makeAction("Copiar snippet", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), ctx.item.result || ""]);
        }),
        makeAction("Executar no Terminal", "\u{f120}", function() {
            var dangerous = ctx.isDangerousCommand(ctx.item.result || "");
            if (dangerous && !ctx.confirmDangerousCommand(ctx.item.result || ""))
                return false;
            ctx.runLauncherCommand("terminal", ctx.item.result || "", dangerous);
        })
    ];
}

function buildKillActions(ctx) {
    var pid = String(ctx.pid || "");
    var command = String(ctx.command || "");
    var actions = [
        makeAction("Encerrar (SIGTERM)", "\u{f00d}", function() {
            if (pid === "")
                return false;
            if (ctx.requestKillTerm)
                return ctx.requestKillTerm(pid, command);
            if (ctx.confirmDangerousCommand && !ctx.confirmDangerousCommand("kill -TERM " + pid))
                return false;
            if (ctx.commandRunner)
                ctx.commandRunner.exec(["kill", "-TERM", pid]);
            return false;
        })
    ];

    if (ctx.killForceAvailable === true) {
        actions.push(makeAction("Forçar (SIGKILL)", "\u{f071}", function() {
            if (pid === "")
                return false;
            if (ctx.requestKillForce)
                return ctx.requestKillForce(pid, command);
            if (ctx.confirmDangerousCommand && !ctx.confirmDangerousCommand("kill -KILL " + pid))
                return false;
            if (ctx.commandRunner)
                ctx.commandRunner.exec(["kill", "-KILL", pid]);
            return false;
        }));
    }

    actions.push(
        makeAction("Copiar PID", "\u{f0c5}", function() {
            if (ctx.commandRunner)
                ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), pid]);
        }),
        makeAction("Copiar comando", "\u{f0c5}", function() {
            if (ctx.commandRunner)
                ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), command]);
        })
    );

    return actions;
}

function buildAiAssistActions(ctx) {
    return [
        makeAction("Copiar Resposta", "\u{f0c5}", function() {
            ctx.commandRunner.exec(["bash", ctx.runtimePaths.scriptFile("utility_copy_text.sh"), ctx.aiPrimaryText || ""]);
            return false;
        }),
        makeAction("Abrir AI Chat Lab", "\u{f5dc}", function() {
            if (ctx.shellRoot && ctx.shellRoot.aiChatLabLoader)
                ctx.shellRoot.aiChatLabLoader.active = true;
            return false;
        })
    ];
}
