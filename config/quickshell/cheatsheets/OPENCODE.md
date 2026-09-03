# 🤖 OpenCode Cheatsheet

Mapa do OpenCode em uso hoje no ambiente.

---

## 🔰 Estado atual
| Item | Valor | Observação |
| :--- | :--- | :--- |
| Binário base | `opencode` | Instalado via Home Manager. |
| Alias principal | `oc` | Abre o CLI direto. |
| Config local | `~/.config/opencode` | Sincronizado pelo Nix. |
| Integração de shell | `review`, `research`, `plan` | Aliases reais hoje. |
| Scratchpad Hyprland | `SUPER + SHIFT + P` | `kitty --class scratchpad-opencode opencode`. |
| Busca no launcher | `launcher_ai_opencode.sh` | Busca IA rápida no launcher. |

---

## 🧭 Comandos registrados
| Comando | Papel |
| :--- | :--- |
| `orchestrate` | Delegar para especialistas. |
| `review` | Revisão de mudanças. |
| `research` | Pesquisa contextual. |
| `plan` | Planejamento de trabalho. |
| `test` / `tests` | Execução de testes. |
| `shell` | Trabalho de shell. |
| `nixos` | Análise NixOS. |
| `home` | Análise Home Manager. |
| `git` | Auditoria de Git. |
| `docs` | Trabalho de documentação. |
| `maintain` | Manutenção de repo. |
| `security` | Auditoria de segurança. |
| `reliability` | Confiabilidade / restart loops. |
| `release` | Releases e changelog. |
| `quickshell` | Quickshell / QML. |
| `qml` | Auditoria QML. |
| `python` | Automação Python. |
| `perf` | Performance / latência. |
| `nixvim` | Nixvim / Neovim. |
| `nixpkgs` | Qualidade de pacotes. |
| `mcp` | MCP hygiene. |
| `incident` | Resposta a incidentes. |
| `systemd` | Auditoria systemd. |
| `uipolish` | Polimento visual/UI. |

---

## 🧠 Agentes disponíveis
| Agente | Uso |
| :--- | :--- |
| `orchestrator` | Delegação inteligente. |
| `oc` | Alias principal. |
| `review` | Revisão de mudanças. |
| `research` | Pesquisa ampla. |
| `plan` | Plano de execução. |
| `git-auditor` | Análise de Git/diffs. |
| `build` | Implementação multi-step. |
| `codebase-explorer` | Mapeamento do repositório. |
| `docs-writer` | Documentação. |
| `home-manager-expert` | Home Manager. |
| `nixos-expert` | NixOS. |
| `nixvim-auditor` | Nixvim. |
| `qml-auditor` | QML / Quickshell. |
| `quickshell-dev` | Quickshell dev. |
| `security-auditor` | Segurança. |
| `shell-expert` | Shell / Bash. |
| `systemd-expert` | systemd user units. |
| `performance-auditor` | Latência e memória. |
| `release-manager` | Versionamento. |
| `repo-maintainer` | Higiene do repo. |
| `test-engineer` | Cobertura e testes. |
| `ui-polish` | Polimento visual. |
| `advanced-debugger` | Debug profundo. |

---

## 🔎 O que ainda falta configurar
| Área | Falta | Observação |
| :--- | :--- | :--- |
| Shell | Atalhos diretos para `orchestrate`, `nixos`, `home`, `git` | Hoje só `oc/review/research/plan` estão no shell. |
| Commands | Confusão entre comandos e aliases | Alguns itens existem como comandos OpenCode, não shell aliases. |
| CLI | Menu rápido de comandos OpenCode | Ainda não há launcher dedicado. |
| Hyprland | Acesso separado para agentes específicos | Hoje tudo converge no scratchpad. |
| Sessões | Persistência / restore de contextos OpenCode | Não existe serviço próprio. |
| Docs | Mapa explicando comandos vs agentes | Útil para não confundir alias com comando interno. |
| MCP | Resumo dos MCPs em uso | Ainda não está documentado neste menu. |

---

## ✅ Já integrado ao desktop
| Item | Status |
| :--- | :--- |
| Scratchpad OpenCode | Implementado. |
| Launcher AI route | Implementado. |
| Classe Hyprland `scratchpad-opencode` | Implementada. |
| Área dedicada no cheat sheet | Implementada agora. |
