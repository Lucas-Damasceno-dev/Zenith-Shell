# 🧪 Zenith-Shell (Engine v2) — Checklist de Verificação Empírica

Este documento estabelece o roteiro exaustivo e sequencial para testes práticos no seu ambiente desktop Wayland (Hyprland / Sway).
A ordem foi priorizada da infraestrutura mais crítica (Core Wayland e IPC) até as superfícies contextuais e periféricas.

---

## 📋 Sumário de Prioridades de Teste

| Fase | Domínio de Teste | Criticidade | Comandos Principais |
| :--- | :--- | :---: | :--- |
| **Tier 1** | Boot do Daemon, Barra Wayland & Memória | 🔴 Alta | `just run`, `zenith inspect` |
| **Tier 2** | IPC de Compositor (Hyprland / Sway) & Workspaces | 🔴 Alta | `zenith dispatch`, Super+1..9 |
| **Tier 3** | Popups Layer-Shell, Click-Outside & Spring Physics | 🔴 Alta | `zenith toggle <id>`, Frame loop |
| **Tier 4** | Universal App Launcher & Teclado | 🟡 Média-Alta | `zenith toggle Launcher`, Digitação |
| **Tier 5** | Roteamento PipeWire Audio & Seletor de Sinks | 🟡 Média-Alta | `zenith toggle AudioPopup` |
| **Tier 6** | Daemon de Notificações (`org.freedesktop.Notifications`) | 🟡 Média-Alta | `notify-send`, Sino da barra |
| **Tier 7** | Dock Flutuante & Dynamic Island | 🟡 Média | `zenith toggle Dock`, `zenith toggle Island` |
| **Tier 8** | Screen Locker Nativo de Alta Segurança | 🔴 Alta | `zenith lock`, Desbloqueio |
| **Tier 9** | Rede, Bluetooth, Mídia MPRIS & Snipping/Gravação | 🟢 Média-Baixa | `zenith toggle NetworkPopup`, etc. |
| **Tier 10**| Sub-10ms Hot-Reload & Estresse de Memória (Leak Test) | 🔴 Alta | Edição ao vivo, `zenith reload` |

---

## 🎯 Tier 1: Boot do Daemon, Barra Wayland & Métricas de Memória

Objetivo: Garantir que o binário sobe nativamente sobre o compositor Wayland sem travamento, aloca a barra com transparência correta e cumpre o orçamento de < 15 MB de RAM.

- [ ] **1.1 Inicialização Limpa via Daemon**
  - **Comando:** `nix develop --command just run` ou `./target/debug/zenith daemon`
  - **Critério de Sucesso:** A barra superior aparece ancorada no topo do monitor em menos de 50ms, sem crash ou mensagens de `panic!`.
- [ ] **1.2 Inspeção de VmRSS e Heap Privado**
  - **Comando:** `zenith inspect` (em outro terminal)
  - **Critério de Sucesso:** Retorna JSON `{"status":"running","vmrss_mb": <15.0, "heap_mb": <2.0}`.
- [ ] **1.3 Clonagem Multi-Monitor (se aplicável)**
  - **Critério de Sucesso:** Conectando monitor secundário ou observando monitores existentes, uma instância independente da barra é instanciada para cada `wl_output`.
- [ ] **1.4 Renderização Vetorial e Fontes**
  - **Critério de Sucesso:** Cantos arredondados suavizados (anti-aliasing) com `tiny-skia` e ícones/números nítidos com `cosmic-text` (JetBrainsMono Nerd Font).

---

## 🎯 Tier 2: IPC do Compositor & Workspaces em Tempo Real

Objetivo: Validar que os sockets de compositor (`hyprland.socket2.sock` ou `$SWAYSOCK`) sincronizam os workspaces e janelas ativas com zero latência perceptível.

- [ ] **2.1 Rastreamento de Workspaces Ativos**
  - **Ação:** Trocar de workspace no Hyprland (`SUPER + 1`, `SUPER + 2`, etc.).
  - **Critério de Sucesso:** O chip do workspace na barra atualiza instantaneamente a pílula ativa com cor de destaque (`theme.primary`).
- [ ] **2.2 Despacho de Workspace por Clique**
  - **Ação:** Clicar com o mouse diretamente no número de um workspace inativo na barra.
  - **Critério de Sucesso:** O compositor muda imediatamente para o workspace correspondente.
- [ ] **2.3 Título e Classe da Janela Focada**
  - **Ação:** Alternar entre aplicativos abertos (Terminal, Navegador, Editor).
  - **Critério de Sucesso:** O centro/esquerda da barra reflete o título da janela e o ícone/classe em tempo real.
- [ ] **2.4 Gaps e Blur Automático de Camada**
  - **Critério de Sucesso:** A barra apresenta efeito de blur translúcido (compositor Dual-Kawase via `layerrule blur, zenith-bar` injetado pelo IPC).

---

## 🎯 Tier 3: Popups Layer-Shell, Click-Outside & Spring Physics

Objetivo: Verificar se superfícies contextuais secundárias abrem com interpolação física suave, respeitam margens e fecham de forma confiável.

- [ ] **3.1 Abertura via CLI IPC**
  - **Comando:** `zenith toggle Calendar` ou `zenith toggle AudioPopup`
  - **Critério de Sucesso:** A janela de overlay surge posicionada logo abaixo da barra superior no canto direito.
- [ ] **3.2 Animação Fluida de Molas (Spring Physics)**
  - **Ação:** Observar o movimento de entrada do popup ao abrir.
  - **Critério de Sucesso:** Entrada deslizante vertical (-16px -> 0px) e fade-in suave gerado pelo oscilador analítico `SpringAnimation` no refresh rate da tela (sem quedas bruscas de frame).
- [ ] **3.3 Fechamento Automático (Click-Outside)**
  - **Ação:** Com o popup aberto, clicar em uma área vazia da área de trabalho ou na barra.
  - **Critério de Sucesso:** O popup fecha imediatamente sem bloquear o cursor.
- [ ] **3.4 Não-Fechamento Prematuro durante Interações Internas**
  - **Ação:** Clicar e arrastar dentro do popup (ex: trocar dia no calendário, clicar no mixer).
  - **Critério de Sucesso:** O popup permanece aberto e funcional.

---

## 🎯 Tier 4: Universal Application Launcher (`Launcher.luau`)

Objetivo: Testar indexação de aplicativos XDG, pesquisa difusa (fuzzy search) e controle total por teclado.

- [ ] **4.1 Abertura e Foco de Teclado**
  - **Comando / Atalho:** `zenith toggle Launcher` (ou clicar no botão de menu da barra).
  - **Critério de Sucesso:** Launcher abre centralizado no topo com `KeyboardInteractivity::OnDemand` capturando teclas.
- [ ] **4.2 Digitação Interativa na Busca**
  - **Ação:** Digitar o nome de um aplicativo instalado (ex: `fire`, `code`, `term`).
  - **Critério de Sucesso:** A lista é filtrada e ordenada por relevância em tempo real com cursor de busca ativo.
- [ ] **4.3 Navegação e Seleção via Teclas de Seta**
  - **Ação:** Pressionar `Down` e `Up`.
  - **Critério de Sucesso:** O item selecionado avança na grade/lista com destaque visual.
- [ ] **4.4 Lançamento do Executável (`Enter`)**
  - **Ação:** Pressionar `Enter` sobre o aplicativo selecionado.
  - **Critério de Sucesso:** O aplicativo é iniciado em processo desanexado (`zenith-services::launcher`) e o Launcher fecha automaticamente.
- [ ] **4.5 Botão Limpar Busca (`󰅖`)**
  - **Ação:** Digitar texto e clicar no botão `󰅖` (`search:clear`).
  - **Critério de Sucesso:** A caixa de texto é limpa instantaneamente e a grade restaura todos os apps.

---

## 🎯 Tier 5: Roteamento PipeWire Audio & Seletor de Sinks

Objetivo: Comprovar que o controle de volume e a comutação de dispositivos de saída operam sem travamentos e com cache in-process.

- [ ] **5.1 Slider / Ajuste de Volume na Barra**
  - **Ação:** Rolar a roda do mouse sobre o pill de áudio da barra ou clicar nos botões de volume.
  - **Critério de Sucesso:** O volume muda no PipeWire (`wpctl`) e o rótulo percentual reflete a alteração imediatamente.
- [ ] **5.2 Popup de Áudio (`AudioPopup.luau`)**
  - **Comando:** `zenith toggle AudioPopup`
  - **Critério de Sucesso:** Exibe controle de volume máster, botão de mute e lista de sinks disponíveis (Fones, Caixas, HDMI).
- [ ] **5.3 Comutação Dinâmica de Sink de Saída**
  - **Ação:** Clicar no botão de rádio de um sink inativo (`audio:set_sink:<id>`).
  - **Critério de Sucesso:** A saída padrão é alterada no WirePlumber, o marcador `●` muda para o novo sink e o áudio é redirecionado sem reiniciar o shell.
- [ ] **5.4 Invalidação de Cache por Evento**
  - **Ação:** Conectar/desconectar fone de ouvido ou alterar volume via teclado (`XF86AudioRaiseVolume`).
  - **Critério de Sucesso:** A barra atualiza instantaneamente via listener `pw-mon` sem disparar loops de polling.

---

## 🎯 Tier 6: Daemon de Notificações (`NotificationCenter.luau`)

Objetivo: Garantir captura confiável de toasts do sistema sobre o socket D-Bus `/run/user/<uid>/bus`.

- [ ] **6.1 Emissão de Notificação Externa**
  - **Comando:** `notify-send "Zenith Shell" "Notificação de teste com sucesso!" -u normal`
  - **Critério de Sucesso:** O ícone do sino na barra superior (`󰂚`) incrementa o contador para `1`.
- [ ] **6.2 Abertura da Central de Notificações**
  - **Comando:** `zenith toggle Notifications` (ou clicar no sino).
  - **Critério de Sucesso:** O painel lateral desliza exibindo o card da notificação com título, mensagem e hora.
- [ ] **6.3 Descarte de Notificação Individual**
  - **Ação:** Clicar no botão `󰅖` do card da notificação (`notification:close:<id>`).
  - **Critério de Sucesso:** O card é removido e o contador da barra decrementa.
- [ ] **6.4 Limpar Todas as Notificações**
  - **Ação:** Clicar em "Limpar Todas" (`notification:clear`).
  - **Critério de Sucesso:** A lista é esvaziada e o contador da barra zera.
- [ ] **6.5 Modo Não Perturbe (DND)**
  - **Ação:** Clicar no toggle DND (`notification:toggle_dnd`).
  - **Critério de Sucesso:** O estado DND alterna, inibindo novos alertas visuais.

---

## 🎯 Tier 7: Dock Flutuante & Dynamic Island

Objetivo: Testar os componentes de interface periféricos do ecossistema de desktop.

- [x] **7.1 Dock Flutuante (`Dock.luau`)**
  - **Comando:** `zenith toggle Dock` / autostart via `config.json`
  - **Critério de Sucesso:** Uma barra flutuante ancorada na borda inferior (`Anchor::BOTTOM`, margin 8, exclusive 56) com pílula centrada e sombra suave sem corte de quina reta.
- [x] **7.2 Indicador de Janelas Abertas no Dock**
  - **Ação:** Abrir aplicativos no desktop (`foot`, `brave`, `thunar`, `nvim`, `easyeffects`, `btop`).
  - **Critério de Sucesso:** O Dock exibe os ícones com marcadores de execução e pílulas dinâmicas perfeitamente centrados.
- [x] **7.3 Foco e Minimização de Janela via Dock**
  - **Ação:** Clicar no chip de uma janela minimizada ou em segundo plano.
  - **Critério de Sucesso:** Alterna entre minimizar para `special:minimized` e restaurar para o workspace ativo com identificação exata por endereço hex.
- [x] **7.4 Dynamic Island HUD (`DynamicIsland.luau`)**
  - **Comando:** `zenith toggle Island`
  - **Critério de Sucesso:** Pílula compacta no topo central expande suavemente exibindo status de mídia, volume ou alerta.

---

## 🎯 Tier 8: Screen Locker Nativo de Alta Segurança

Objetivo: Confirmar que a tela de bloqueio assume a camada Overlay exclusiva de teclado sem falhas de escape.

- [x] **8.1 Bloqueio via CLI / IPC**
  - **Comando:** `zenith lock`
  - **Critério de Sucesso:** O overlay de tela cheia `LockScreen.luau` cobre 100% dos displays na camada `Layer::Overlay` dinamicamente ajustado à resolução do monitor.
- [x] **8.2 Exclusividade de Teclado (`KeyboardInteractivity::Exclusive`)**
  - **Ação:** Tentar acionar atalhos do compositor (`SUPER + Q`, `SUPER + Return`, etc.).
  - **Critério de Sucesso:** Submap `zenith_lock` captura todos os inputs e inibe atalhos do compositor; ESC não descarta o bloqueio.
- [x] **8.3 Entrada de Senha e Desbloqueio com PAM**
  - **Ação:** Digitar caracteres no campo mascarado (`● ● ● ▎`) e pressionar `Enter` (ou clicar em Desbloquear / `lock:unlock`).
  - **Critério de Sucesso:** Redesenho em tempo real da máscara de caracteres; autenticação via `unix_chkpwd` valida a senha real antes de fechar o overlay.
- [x] **8.4 Relógio e Telemetria no Lock Screen**
  - **Critério de Sucesso:** Exibe relógio digital grande, data, clima, status de bateria, MPRIS e controles de energia.

---

## 🎯 Tier 9: Rede, Bluetooth, Mídia MPRIS & Snipping/Gravação

Objetivo: Testar serviços adicionais e conectividade.

- [ ] **9.1 Menu de Conectividade Wi-Fi (`NetworkPopup.luau`)**
  - **Comando:** `zenith toggle NetworkPopup`
  - **Critério de Sucesso:** Exibe SSID atual, IP local (resolvido in-process via UDP routing) e lista de redes escaneadas.
- [ ] **9.2 Menu de Bluetooth (`BluetoothPopup.luau`)**
  - **Comando:** `zenith toggle BluetoothPopup`
  - **Critério de Sucesso:** Exibe toggle de energia do adaptador e lista de dispositivos pareados com status de conexão.
- [ ] **9.3 Controlador de Mídia MPRIS2**
  - **Ação:** Tocar uma música no Spotify, Firefox ou MPV.
  - **Critério de Sucesso:** A pílula de mídia na barra exibe `󰎆 Título - Artista`. Clicar abre `MediaPopup.luau` com botões funcionais de Play/Pause, Next e Prev.
- [ ] **9.4 Snipping Tool & REC Indicator**
  - **Ação:** Clicar no ícone de recorte `󰄀` na barra.
  - **Critério de Sucesso:** Dispara `grim + slurp` para captura de tela selecionada. Ao gravar tela com `wf-recorder`, o pill vermelho `● REC` aparece na barra.

---

## 🎯 Tier 10: Sub-10ms Hot-Reload & Estresse de Memória (Leak Test)

Objetivo: Comprovar a estabilidade do runtime em uso contínuo e a eficácia do cache de bytecode.

- [ ] **10.1 Live Hot-Reload sem Reiniciar Processo**
  - **Ação:** Com o shell rodando, editar uma cor ou margem em `config/zenith/bar.luau` e salvar (`:w` / `Ctrl+S`).
  - **Critério de Sucesso:** A barra atualiza visualmente em menos de 10ms mantendo todas as conexões Wayland abertas.
- [ ] **10.2 Cache de Bytecode no Hot-Reload**
  - **Critério de Sucesso:** O log em modo debug confirma `Hot-reload event received! Recomputing Luau UI tree...` e purga do cache de módulos sem vazamentos.
- [ ] **10.3 Teste de Estresse de Abertura/Fechamento (Ciclo Rápido)**
  - **Comando:** Abrir e fechar repetidamente todos os popups (Launcher, Audio, Network, Notifications, Calendar, PowerMenu).
  - **Critério de Sucesso:** Memória VmRSS estabiliza em torno de 13 MB - 16 MB sem crescimento linear (zero memory leak).
- [ ] **10.4 Desligamento Limpo**
  - **Ação:** Enviar `Ctrl+C` ou `kill` para o daemon.
  - **Critério de Sucesso:** Todas as superfícies são liberadas no compositor, o socket UNIX `~/.cache/zenith/ipc.sock` é removido e o processo termina com código 0.

---

## 📝 Registro de Resultados e Observações

| Item | Status (OK / REVISAR) | Observação / Bug Encontrado |
| :--- | :---: | :--- |
| Tier 1 (Core Shell) | `[   ]` | |
| Tier 2 (Compositor IPC) | `[   ]` | |
| Tier 3 (Popups & Springs)| `[   ]` | |
| Tier 4 (Launcher) | `[   ]` | |
| Tier 5 (Audio Sinks) | `[   ]` | |
| Tier 6 (Notificações) | `[   ]` | |
| Tier 7 (Dock & Island) | `[   ]` | |
| Tier 8 (Lock Screen) | `[   ]` | |
| Tier 9 (Rede & Periféricos) | `[   ]` | |
| Tier 10 (Reload & Estresse) | `[   ]` | |
