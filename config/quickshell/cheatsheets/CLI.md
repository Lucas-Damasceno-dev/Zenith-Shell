# ⌨️ CLI & Dev Environment Cheatsheet

Guia do shell e das ferramentas de desenvolvimento mais usadas.

---

## 🛠️ Ferramentas core
| Comando | Substituto | Descrição |
| :--- | :--- | :--- |
| `ls` | `eza` | Listagem com ícones. |
| `cat` | `bat` | Visualização com sintaxe. |
| `grep` | `rg` | Busca ultrarrápida. |
| `ps` | `procs` | Processos em formato legível. |
| `top` | `btm` | Monitor visual. |
| `df` | `duf` | Disco mais legível. |
| `du` | `dust` | Uso por pasta. |
| `ping` | `gping` | Ping visual. |
| `dig` | `doggo` | DNS amigável. |
| `y` | `yazi` | File manager TUI. |
| `sf` | `superfile` | File manager moderno. |
| `d` | `difft` | Diff sintático. |

---

## 🐚 Shell aliases reais
| Alias | Expande para | Descrição |
| :--- | :--- | :--- |
| `oc` | `opencode` | Abre o CLI do OpenCode. |
| `review` | `opencode run --agent review` | Revisor de mudanças. |
| `research` | `opencode run --agent research` | Pesquisa e contexto. |
| `plan` | `opencode run --agent plan` | Planejamento. |
| `Status` | Shell aliases reais | Hoje não há `orchestrate/nixos/home/git` no shell. |
| `testos` | `nix flake check -L` | Suite completa. |
| `sysup` | `nh os switch` | Atualização do sistema. |
| `homeup` | `nh home switch` | Atualização do home. |
| `fullupgrade` | `sudo nix flake update ...` | Atualiza flakes e aplica tudo. |
| `garbage` | `nh clean all` | Limpeza de gerações. |
| `g` | `git` | Atalho para Git. |
| `gs` | `git status` | Status do Git. |
| `ga` | `git add .` | Adiciona tudo. |
| `gc` | `git commit -m` | Commit rápido. |
| `gp` | `git push` | Envia para o remoto. |
| `ghp` | `gh pr create` | Abre PR. |
| `lg` | `lazygit` | Git TUI. |
| `ld` | `lazydocker` | Docker TUI. |
| `lsgl` | `lazysql` | SQL TUI. |
| `of` | `onefetch` | Resumo do repo. |
| `tl` | `tokei` | Contagem de linhas. |
| `cs` | `cd ~/Documents/cheatSheet && ls` | Pasta dos cheatsheets. |
| `cst/csh/csn/csc` | `nvim ...` | Abrir TMUX/HYPRLAND/NIXOS/CLI. |

---

## 🧰 Dev extras
| Comando | Descrição |
| :--- | :--- |
| `nix-tree` | Analisa dependências Nix. |
| `nvd diff` | Compara gerações Nix. |
| `just` | Runner do repositório. |
| `hyperfine` | Benchmark de comandos. |
| `pre-commit` | Hooks de qualidade. |
| `tokei` | Métricas por linguagem. |
| `direnv` | Auto-load de ambientes. |
| `fzf` | Seleção fuzzy. |

---

## 🌿 Ambiente de shell
| Variável | Valor | Observação |
| :--- | :--- | :--- |
| `EDITOR` | `nvim` | Editor padrão. |
| `VISUAL` | `nvim` | Editor visual. |
| `JAVA_HOME` | `temurin-bin-21` | Java 21. |
| `MANPAGER` | `bat` pipeline | Manpages coloridas. |
| `PATH` | `.local/bin`, `.nix-profile/bin`, `.npm-global/bin` | Caminhos do usuário. |
