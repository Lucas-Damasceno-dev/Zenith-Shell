# Zenith-Shell — Evolução Arquitetural & Especificação da Engine Base (v3)

> **Documento Oficial de Engenharia & Decisões Arquiteturais**  
> **Status:** Ativo / Especificação Normativa  
> **Público:** Desenvolvedores do Core, Agentes Autônomos (Antigravity, Hermes, Claude, Copilot)

---

## 1. Princípio Fundamental: Separação entre Engine Base e Shell do Usuário

O projeto Zenith adota formalmente o princípio de **desacoplamento estrito**:

1. **Zenith Base (Engine Framework):**  
   - Crate isolado em Rust responsável unicamente por: ciclo de vida Wayland (`wlr-layer-shell`), aceleração de hardware (EGL/GLES), layout engine (`taffy`), tipografia (`cosmic-text`), motor de reatividade e runtime Luau.
   - Deve ser agnóstico quanto à estética específica do usuário.
2. **Zenith Shell (Configuração / Aplicação do Usuário):**  
   - Scripts puramente declarativos em Luau (`bar.luau`, `dock.luau`, overlays) que consomem a API pública do framework.
   - Enquanto a engine base é estabilizada, a máquina de produção permanece operando sobre a shell estável (Quickshell), evitando bloqueio de produtividade diária.

```
┌─────────────────────────────────────────────────────────────────┐
│               ZENITH SHELL (User Config - Luau)                 │
│         bar.luau  │  dock.luau  │  overlays/  │  tokens.luau    │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Zenith API (Signals & Nodes)
┌────────────────────────────────▼────────────────────────────────┐
│               ZENITH BASE (Engine Core - Rust)                  │
├───────────────────┬─────────────────────────────┬───────────────┤
│ zenith-runtime    │ Luau VM + Reactive Signals  │ Node Cache    │
│ zenith-layout     │ Taffy 0.14 (Flexbox / Grid) │ Layout Box    │
│ zenith-wayland    │ SCTK 0.19 + Wayland EGL     │ GLES 3.0 Draw │
│ zenith-services   │ zbus (Native D-Bus)         │ PipeWire / IPC│
│ zenith-core       │ Spring Physics              │ Error Boundary│
└───────────────────┴─────────────────────────────┴───────────────┘
```

---

## 2. Pipeline Gráfico: Transição de SHM/tiny-skia para Wayland EGL + OpenGL ES 3.0

### Diagnóstico do Backend Legado (v2)
* O renderizador inicial utilizava `tiny-skia` sobre memória compartilhada de CPU (`wl_shm`).
* **Limitação:** Em telas de alta resolução ou CPUs com capacidade single-thread modesta (ex: AMD A8-9600 com GPU integrada Radeon R7), animações contínuas (springs, cava, spectrum) e multi-pass drop shadows na CPU geram picos de processamento desnecessários.

### Nova Arquitetura de Renderização (v3)
* **Backend Gráfico:** Wayland EGL + **OpenGL ES 3.0** nativo via `glow` / `femtovg`.
* **Vantagens Técnicas:**
  1. **Zero Sobrecarga de CPU:** Rasterização e preenchimento de polígonos delegados diretamente aos shaders da GPU.
  2. **Shaders Customizados:** Sombras analíticas com falloff exponencial e blur Kawase aplicados via fragment shaders a 60/120Hz com custo quase nulo.
  3. **Texture Atlas para Tipografia:** O `cosmic-text` mantém o layout dos glifos, mas as texturas dos caracteres são cacheadas em um atlas de textura na VRAM, evitando rasterização repetida por frame.
  4. **Fallback Transparente:** O backend `tiny-skia` (SHM) permanece compilável como modo de contingência para testes headless ou ambientes sem aceleração 3D.

---

## 3. Paradigma de Reatividade: Fine-Grained Reactive Signals

### O Gargalo do Modelo "Immediate Table Dump"
Na versão v2, a função `eval_ui` reexecuta o script Luau completo a cada tick ou evento, instanciando novas tabelas Luau e forçando o parse de uma nova árvore de nós. Isso causa churn contínuo no Garbage Collector do Luau.

### O Novo Modelo de Sinais (SolidJS / Leptos Model)
A UI é construída em Rust **uma única vez** na inicialização. As propriedades que mudam com o tempo são ligadas a **Sinais Reativos**:

```luau
-- zenith/lib/widgets/clock.luau
local Zenith = require("@zenith")

-- Sinal reativo (valor + setter)
local timeStr, setTime = Zenith.signal(os.date("%H:%M"))

Zenith.Services.Timer.every(1000, function()
    setTime(os.date("%H:%M"))
end)

return Zenith.Box {
    background = Zenith.Theme.surface,
    border_radius = 12,
    padding = { horizontal = 12, vertical = 6 },
    
    Zenith.Text {
        text = timeStr, -- Ligação direta! Não remonta a árvore.
        color = Zenith.Theme.text,
        font_weight = "bold",
    }
}
```

### Comportamento no Engine Rust:
1. `setTime(...)` altera apenas o slot de memória do sinal na runtime.
2. O Rust identifica os nós dependentes através de um grafo de dependências DAG simples.
3. Se o novo texto alterar as dimensões da caixa, apenas o ramo afetado no Taffy é recalculado (`taffy.mark_dirty(node_id)`).
4. Se o tamanho for mantido, apenas a textura/quad do glifo é atualizada no buffer da GPU.
5. **Resultado:** Consumo de CPU em repouso reduzido para **0.00%**.

---

## 4. Camada de Serviços e Telemetria: Adoção Estrita de `zbus`

O spawn de subprocessos de shell (`std::process::Command::new("sh")`) para comandos como `wpctl`, `nmcli` ou `playerctl` é estritamente proibido no caminho crítico da engine.

### Arquitetura de Comunicação Assíncrona:
* **D-Bus Nativo:** Implementado exclusivamente via crate `zbus` (assíncrono, type-safe, pure-Rust).
  * `org.freedesktop.Notifications`: Servidor de notificações nativo sem necessidade de `dunst` ou `mako`.
  * `org.mpris.MediaPlayer2`: Rastreamento de faixas, capa de álbum e controles de reprodução via IPC binário.
  * `org.freedesktop.NetworkManager`: Sinais de nível de sinal Wi-Fi e status de conexão.
  * `org.freedesktop.UPower`: Métricas de bateria e perfil energético.
* **Compositor IPC:** Socket streaming dedicado e assíncrono para Hyprland (`.socket2.sock`) com canal MPSC para o loop de eventos principal (`calloop`).

---

## 5. Experiência de Desenvolvimento (DX): Tipagem Estática `zenith.d.luau`

Para garantir produtividade e eliminar erros de digitação em propriedades de layout e estilos, a engine fornece definições de tipos formais para o Luau Language Server:

```luau
-- Exemplo de assinatura exportada no ambiente global
export type BoxProps = {
    width: (number | "auto" | "100%")?,
    height: (number | "auto" | "100%")?,
    flex_direction: ("row" | "column" | "row_reverse" | "column_reverse")?,
    justify_content: ("flex_start" | "center" | "flex_end" | "space_between" | "space_around")?,
    align_items: ("flex_start" | "center" | "flex_end" | "stretch")?,
    gap: number?,
    padding: (number | { horizontal: number?, vertical: number?, left: number?, right: number?, top: number?, bottom: number? })?,
    background: string?,
    border_radius: number?,
    border_width: number?,
    border_color: string?,
    on_click: (() -> ())?,
    cursor: ("default" | "pointer" | "text")?,
}
```

---

## 6. Filosofia de Resiliência: "Zero-Panic & Self-Healing"

Uma shell de sistema deve ser tão estável quanto o próprio kernel do sistema operacional.

1. **Reconexão Resiliente ao Compositor:**  
   Se o Hyprland reiniciar ou recarregar (`hyprctl reload`), o thread de IPC do Zenith entra em estado de espera com backoff exponencial e reconecta sem abortar a engine.
2. **Isolamento de Falhas em Scripts (Error Boundaries):**  
   Se o usuário introduzir um erro de sintaxe ou runtime em um arquivo `.luau` durante a edição ao vivo:
   * A engine rejeita a troca de nó corrompida.
   * Mantém o último frame válido na tela.
   * Emite uma notificação de erro ou log com arquivo e linha exatos sem fechar a barra nem encerrar o daemon.

---

## 7. Matriz de Paridade Comparativa Atualizada

| Requisito | Quickshell (Qt6) | Noctalia v5 (C++23) | Zenith Base v3 (Rust + GLES) |
| :--- | :--- | :--- | :--- |
| **Linguagem do Core** | C++ / Qt6 | C++23 | **Rust (Memory-Safe)** |
| **Aceleração Gráfica** | Qt Quick Scenegraph | OpenGL ES nativo | **Wayland EGL + OpenGL ES 3.0** |
| **Linguagem de UI** | QML + JS | TOML estático + Luau plugins | **Luau puro com Taffy Flexbox** |
| **Segurança contra Segfaults** | Média (depende do Qt) | Baixa (C++ manual) | **Total (Safe Rust)** |
| **Consumo de Memória (RAM)** | ~180 – 250 MB | ~20 – 40 MB | **~15 – 25 MB** |
| **Hot-Reload de UI** | ~1.5s (service restart) | Rápido (re-parse TOML) | **Sub-5ms (Luau Hot-Bytecode)** |
| **Modelo Reativo** | QML Property Bindings | Polling / Eventos fixos | **Fine-Grained Signals (Leptos/Solid)** |
| **Empacotamento NixOS** | Módulo complexo com Qt | Derivação C++ com CMake | **Flake estático Rust via Cargo** |

---

## 8. Cronograma de Engenharia da Engine Base

* **Fase 1 (Atual):** Concluir a abstração gráfica EGL / GLES 3.0 em `zenith-wayland` com Texture Atlas para `cosmic-text`.
* **Fase 2:** Implementar primitiva de Sinais (`Zenith.signal`) e Node Cache persistente em `zenith-runtime`.
* **Fase 3:** Migrar serviços de sistema em `zenith-services` para `zbus` puro.
* **Fase 4:** Adicionar arquivo de tipos `zenith.d.luau` e validação com Luau LSP.
* **Fase 5:** Validação de estabilidade em hardware modesto (AMD A8-9600) garantindo 0% de CPU em idle.
