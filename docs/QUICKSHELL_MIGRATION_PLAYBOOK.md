# 🧭 Playbook de Migração: Quickshell (Qt6) ➔ Zenith-Shell (Rust/Luau)

> **Instruções Mestras para Sessões de Desenvolvimento com IA**  
> **Objetivo:** Recriar e portar progressivamente toda a shell desktop customizada originalmente implementada em Quickshell (Qt6/QML/JS) para o framework nativo **Zenith-Shell** (Rust Engine v2 + Luau Declarativo + Wayland Layer-Shell).

---

## 📌 1. Diretórios e Regras de Limite

| Papel | Caminho | Permissão | Descrição |
| :--- | :--- | :---: | :--- |
| **Referência / Fonte** | `/etc/nixos/home/lucas/modules/desktop/quickshell/` | **STRICTLY READ-ONLY** | Implementação original em QML/JS/Nix. **Nunca alterar nenhum arquivo aqui.** |
| **Destino / Engine** | `./crates/` | Leitura / Escrita | Framework standalone em Rust (`zenith-core`, `zenith-services`, `zenith-wayland`, `zenith-runtime`, `zenith-cli`). |
| **Destino / UI** | `./config/zenith/` | Leitura / Escrita | Configurações declarativas em Luau (barra, dock, popups, overlays, widgets). |
| **Documentação** | `./docs/` | Leitura / Escrita | Matrizes de paridade (`QUICKSHELL_PARITY_MATRIX.md`) e checklists empíricos. |

---

## 🏗️ 2. Mapeamento de Conceitos: QML vs. Zenith

Ao analisar componentes no Quickshell, traduza para as estruturas nativas do Zenith conforme a tabela abaixo:

| Conceito Quickshell (QML/Qt6) | Equivalente Zenith-Shell (Luau / Rust) | Exemplo Zenith |
| :--- | :--- | :--- |
| `Item`, `Rectangle` | `Zenith.Box` (Taffy flexbox) | `Zenith.Box({ width = 200, height = 40, background = theme.surface, border_radius = 8 })` |
| `RowLayout`, `ColumnLayout` | `Zenith.Box` com `flex_direction` | `flex_direction = "row"` ou `"column"`, `gap = 8`, `align_items = "center"` |
| `Text`, `Label` | `Zenith.Text` | `Zenith.Text({ text = "Exemplo", font_size = 13, color = theme.text, weight = "semibold" })` |
| `MouseArea`, `TapHandler` | `Zenith.Box` callbacks | `on_click = function() Zenith.exec("wpctl ...") end, cursor = "pointer"` |
| `NumberAnimation`, `SpringAnimation` | `Zenith.Spring` | `local anim = Zenith.Spring(0.0, 1.0, 240.0, 22.0)` |
| `PopupWindow`, `AnimatedWindow` | Overlay Luau + Layer-Shell | Arquivo em `config/zenith/overlays/<Nome>.luau`, invocado via `zenith-cli toggle <Nome>` |
| `ColorScheme.qml`, `DesignTokens.qml` | `Zenith.Theme()` | `local theme = Zenith.Theme()` (sincronizado automaticamente com Matugen) |
| QML Services (`services/*.qml`) | Rust Services (`zenith-services`) | Implementados em Rust, expostos em Luau via `Zenith.Services.<Nome>()` ou `Zenith.Signals` |
| Comandos de Shell / Processos | `Zenith.exec` / `Zenith.dispatch` | `Zenith.exec("hyprctl dispatch ...")` ou `Zenith.dispatch("workspace", 2)` |

---

## 🔄 3. Protocolo Operacional Padrão (SOP) para IA em Cada Turno

Quando a IA receber uma tarefa de portar ou aprimorar um componente, **deve seguir estritamente este ciclo**:

```
[1. Inspecionar QML Original] ➔ [2. Checar Primitivas na Engine] ➔ [3. Implementar/Ajustar Luau] ➔ [4. Validar & Testar] ➔ [5. Atualizar Paridade]
```

### Passo 1: Inspeção do Código Original
* Ler o arquivo correspondente em `/etc/nixos/home/lucas/modules/desktop/quickshell/`.
* Identificar:
  1. Estados reativos (`property var`, `Timer`).
  2. Scripts auxiliares chamados (`scripts/ui/...`, `scripts/media/...`).
  3. Atalhos de teclado e regras de fechamento (click-outside, escape).
  4. Dimensões, padding, cores de tokens e alinhamento visual.

### Passo 2: Verificação de Primitiva no Rust
* Verificar se os dados necessários já são expostos em `crates/zenith-runtime/src/lib.rs` e `crates/zenith-services/src/`.
* **Se faltar primitiva:** Criar serviço cirúrgico em Rust sob `zenith-services` e registrá-lo em `zenith-runtime`.
  * Manter I/O assíncrono (evitar travar o loop de renderização do Wayland).
  * Validar compilação: `cargo check --workspace`.

### Passo 3: Implementação / Refatoração em Luau
* Se for módulo da barra: criar/editar em `config/zenith/widgets/<categoria>/<modulo>/init.luau` ou `config/zenith/bar/clusters/`.
* Se for overlay/janela/popup: criar/editar em `config/zenith/overlays/<Nome>.luau`.
* Utilizar sempre `Zenith.Theme()` para garantir paridade com Matugen / Material You.
* Garantir retorno de uma tabela de nó UI (`return Zenith.Box({ ... })`).

### Passo 4: Validação Empírica
Executar comandos de validação via terminal do workspace:
```bash
# 1. Checar compilação e tipagem da engine
just check

# 2. Testar o componente específico em tempo de execução
just toggle <NomeDoPopup>   # ex: just toggle AudioPopup

# 3. Recarregar instantaneamente (sub-10ms)
just reload

# 4. Verificar orçamento de memória (<15 MB VmRSS)
just inspect

# 5. Rodar testes de regressão
just test
```

### Passo 5: Atualização da Matriz de Paridade
* Atualizar a linha correspondente em [QUICKSHELL_PARITY_MATRIX.md](QUICKSHELL_PARITY_MATRIX.md).

---

## 🗺️ 4. Ondas de Migração (Roadmap de Fatias Verticais)

### 🌊 Onda 1: Componentes da Barra Superior (`modules/bar/`)
* [x] **Clock & Calendar Trigger:** `lib/widgets/clock.luau`
* [x] **Workspaces Hyprland:** `lib/widgets/workspaces.luau` (multi-monitor filtering ativo)
* [x] **Hardware Telemetry:** `lib/widgets/hardware.luau` (CPU, RAM, Bateria)
* [x] **Media Pill:** `lib/widgets/media.luau` (MPRIS status)
* [x] **Status Tray:** `lib/widgets/tray.luau` (SNI integration)
* [x] **Quick Status:** Sincronizar switches de modo (DND, GameMode, VPN) (`lib/widgets/quick_status.luau` + modular status cluster)

### 🌊 Onda 2: Popups e Centrais Essenciais (`overlays/`)
* [x] **AudioPopup:** Roteamento PipeWire, seletor de sinks e sliders de volume (`overlays/AudioPopup.luau`)
* [x] **NetworkPopup:** WiFi scanner, conexões ativas (`overlays/NetworkPopup.luau`)
* [x] **BluetoothPopup:** Dispositivos pareados e status (`overlays/BluetoothPopup.luau`)
* [x] **CalendarPopup:** Visualização mensal e eventos (`overlays/CalendarPopup.luau`)
* [x] **OSD HUD:** Volume, brilho e microfone em tempo real (`overlays/OSD.luau`)
* [x] **ControlCenterPopup:** Migrar central combinada (`overlays/ControlCenterPopup.qml` ➔ `overlays/ControlCenter.luau`)
* [x] **BatteryPopup:** Detalhes de saúde, perfis de energia (power-profiles-daemon) (`overlays/BatteryPopup.luau`)
* [x] **USBPopup:** Dispositivos USB e montagem de mídia removível (`overlays/USBPopup.luau`)

### 🌊 Onda 3: Superfícies de Input e Navegação
* [x] **App Launcher:** Fuzzy search XDG, keyboard grab, cursor navigation (`overlays/Launcher.luau`)
* [x] **PowerMenu:** Lock, Suspend, Reboot, Shutdown com confirmação (`overlays/PowerMenu.luau`)
* [x] **ClipboardPopup:** Histórico de cliphist com preview (`overlays/ClipboardPopup.luau`)
* [x] **WorkspaceSwitcher / Expose:** Visualizador de janelas e troca rápida (`overlays/ExposePopup.luau`)

### 🌊 Onda 4: Superfícies Avançadas do Desktop
* [x] **Dock Interativa:** Fixação de apps, indicadores de janelas ativas (`overlays/Dock.luau`)
* [x] **Dynamic Island:** HUD expansível animado com springs (`overlays/DynamicIsland.luau`)
* [x] **Desktop Canvas:** Widgets sobre o wallpaper (`overlays/DesktopCanvas.luau`)
* [x] **LockScreen Nativa:** Layer-shell exclusivo com relógio e pam auth (`overlays/LockScreen.luau`)
* [x] **Notification Center:** Daemon D-Bus completo com histórico (`overlays/NotificationCenter.luau`)

### 🌊 Onda 5: Utilitários & Ferramentas do Sistema
* [x] **Settings Center:** Configuração do ecossistema (`overlays/Settings.luau` + `lib/settings_store.luau`)
* [x] **System Monitor Popup:** Gráficos de processo, CPU, GPU e I/O (`overlays/SystemMonitorPopup.luau`)
* [x] **Scratchpad Drawer:** Gaveta lateral para janelas especiais Hyprland (`overlays/ScratchpadDrawer.luau`)
* [x] **ScreenDraw Overlay:** Desenho e anotações sobre a tela (`overlays/ScreenDrawOverlay.luau`)

---

## ⚠️ 5. Regras Críticas e Anti-Padrões para a IA

1. **PROIBIDO Reescritas Globais (Surgical Patch Only):** Altere apenas as funções e blocos necessários. Nunca delete arquivos Luau existentes para recomeçar do zero.
2. **Preservação de Memória:** O orçamento máximo do daemon é **15 MB de VmRSS**. Qualquer vazamento de heap Luau ou Rust que exceda 20 MB deve ser tratado como bug crítico.
3. **Não Poluir o Main Loop Wayland:** Todas as chamadas de I/O bloqueante (ex: `nmcli`, `curl`, `wpctl`, `git`) devem rodar em threads de background em `zenith-services`, entregando dados ao Luau via `Zenith.Signals` ou canais atômicos.
4. **Isolamento do NixOS:** O diretório `/etc/nixos/home/lucas/modules/desktop/quickshell/` está em partição gerenciada por NixOS. Não tente escrever, mover ou criar links simbólicos dentro dele.
5. **Estilo Declarativo Luau:** Mantenha os componentes puros e modulares. Separe lógica de dados (services) da montagem visual (`Zenith.Box`).
