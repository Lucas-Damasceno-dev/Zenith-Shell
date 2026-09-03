# 🦅 Hyprland & Desktop Cheatsheet

Guia de atalhos e automações do Hyprland em uso hoje.

---

## 🎹 Base do ambiente
| Item | Valor | Observação |
| :--- | :--- | :--- |
| `SUPER` | Mod principal | Base de quase todos os binds. |
| `SUPER + /` | Cheat Sheet | Abre este overlay. |
| `SUPER` (solto) | Launcher | Dispara o Super Launcher. |
| `Terminal` | `kitty` | Terminal padrão. |
| `Arquivos` | `thunar` | Gerenciador padrão. |
| `Navegador` | `brave` | Navegador padrão. |

---

## 🪟 Janelas e foco
| Tecla | Ação | Observação |
| :--- | :--- | :--- |
| `SUPER + Q` | Abrir terminal | Abre Kitty. |
| `SUPER + W` | Abrir navegador | Brave. |
| `SUPER + E` | Abrir arquivos | Thunar. |
| `SUPER + C` | Fechar janela | Kill active. |
| `SUPER + V` | Toggle floating | Alterna janela flutuante. |
| `SUPER + F` | Maximizar | Mantém a bar. |
| `SUPER + SHIFT + F` | Fullscreen total | Fullscreen real. |
| `SUPER + X` | Centralizar janela | Centraliza a janela ativa. |
| `SUPER + A` | Pin | Fixa a janela. |
| `SUPER + SHIFT + A` | Toggle pin do workspace | Pin por workspace. |
| `SUPER + P` | Pseudo tile | Alterna pseudo-tile. |
| `SUPER + J` | Toggle split | Alterna split do dwindle. |
| `SUPER + LEFT/RIGHT/UP/DOWN` | Mover foco | Navegação de foco. |
| `SUPER + mouse drag` | Mover/resize | Drag com botão do mouse. |

---

## 🚀 Menus e launches do Quickshell
| Tecla | Ação | Observação |
| :--- | :--- | :--- |
| `SUPER + Space` | Overview | Visão geral das janelas. |
| `SUPER + Tab` | Workspace switcher | Alternador de workspaces. |
| `SUPER + M` | Media popup | Popup de mídia. |
| `SUPER + SHIFT + M` | Session popup | Sessão/controle. |
| `SUPER + S` | Utility Hub | Screenshot/record. |
| `SUPER + F7` | Audio popup | Controle de áudio. |
| `SUPER + /` | Cheat Sheet | Este menu global. |
| `SUPER + SHIFT + P` | OpenCode scratchpad | Abre `opencode` num scratchpad. |

---

## 🖥️ Workspaces e scratchpads
| Tecla | Ação | Observação |
| :--- | :--- | :--- |
| `SUPER + 1..0` | Ir para workspace 1..10 | `0` = workspace 10. |
| `SUPER + SHIFT + 1..0` | Mover janela para 1..10 | Move a janela ativa. |
| `SUPER + ALT + 1..0` | Toggle special workspace | `sp1..sp10`. |
| `SUPER + ALT + SHIFT + 1..0` | Mover para special workspace | `special:sp1..sp10`. |
| `SUPER + Return` | Scratchpad de sistema | Terminal utilitário. |
| `SUPER + N` | Scratchpad de notas | Quick note. |
| `SUPER + ' ` | Scratchpad de chat | Scratchpad de chat/AI. |
| `SUPER + Scroll` | Alternar workspace | `mouse_up/down`. |
| `SUPER + [ / ]` | Foco de monitor | Anterior / próximo. |
| `SUPER + SHIFT + [ / ]` | Mover janela | Entre monitores. |

---

## 🎛️ Scripts e automações
| Tecla | Ação | Observação |
| :--- | :--- | :--- |
| `SUPER + R` | Gravador por região | Toggle de gravação. |
| `SUPER + T` | OCR | Copia texto da tela. |
| `Print` | Screenshot tela cheia | Sem mod. |
| `SUPER + SHIFT + Print` | Screenshot tela cheia | Variante com mod. |
| `SUPER + CTRL + Print` | Screenshot janela | Janela ativa. |
| `SUPER + ALT + Print` | Screenshot região | Seleção de área. |
| `SUPER + SHIFT + W` | Próximo wallpaper | Troca wallpaper. |
| `SUPER + CTRL + W` | Wallpaper anterior | Volta wallpaper. |
| `SUPER + ALT + W` | Salvar favorito | Marca wallpaper. |
| `SUPER + F9` | Perfil de energia | Alterna power profile. |
| `SUPER + F10` | Perfil de contexto | Cicla work/study/game. |
| `SUPER + CTRL + 1..4` | Scene preset | Work, study, gaming, streaming. |
| `SUPER + CTRL + D/C/Z` | Workspace macro | Dev, comms, focus. |
| `SUPER + BACKSLASH` | Ciclar layout | Muda layout. |
| `SUPER + CTRL + R` | Resize submap | Entra no submap. |
| `SUPER + F5` | Salvar sessão | Session save. |
| `SUPER + F6` | Restaurar sessão | Session restore. |
| `SUPER + CTRL + SHIFT + R` | Emergency reset | Reset de emergência. |

---

## 🎚️ Áudio, brilho e mídia
| Tecla | Ação | Observação |
| :--- | :--- | :--- |
| `XF86AudioPlay/Pause/Next/Prev` | Player control | Via `playerctl`. |
| `XF86AudioRaiseVolume` | Aumentar volume | Mostra OSD. |
| `XF86AudioLowerVolume` | Diminuir volume | Mostra OSD. |
| `XF86AudioMute` | Mute saída | Mostra OSD. |
| `XF86AudioMicMute` | Mute microfone | Sem OSD. |
| `XF86MonBrightnessUp` | Aumentar brilho | Mostra OSD. |
| `XF86MonBrightnessDown` | Diminuir brilho | Mostra OSD. |
| `SUPER + = / -` | Volume da saída | Atalho alternativo. |
| `SUPER + SHIFT + = / -` | Volume da entrada | Microfone. |
| `SUPER + SHIFT + F7` | Mute microfone | Atalho extra. |

---

## ✋ Gestures e submap
| Item | Ação | Observação |
| :--- | :--- | :--- |
| `3-finger horizontal` | Troca workspace | Gesture `workspace`. |
| `3-finger up` | Fullscreen | Atalho por gesto. |
| `3-finger down` | Float/scale | `scale: 0.8, float`. |
| `4-finger left/right` | Move workspace | `e-1 / e+1`. |
| `4-finger down` | Close window | Fecha a janela ativa. |
| `SUPER + CTRL + R` | Resize submap | Dentro do modo: `h/j/k/l` move 30px, `SHIFT+h/j/k/l` move janela, `Esc/Return/SUPER release` resetam. |

---

## ⏸️ Idle, lock e estado do shell
| Item | Valor | Observação |
| :--- | :--- | :--- |
| `SUPER + L` | Lock screen | Hyprlock. |
| `Hypridle` | Ativo | Dim, lock e suspend. |
| `monitor-hotplug-daemon` | Ativo | Hotplug de monitores. |
| `hypr-activewindow-ipc` | Ativo | Stream do window focus. |
| `thermal-profile-daemon` | Ativo | Perfil térmico/blur. |
