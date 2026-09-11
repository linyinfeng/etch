# 项目约定

- **语言**：与用户交流用中文；代码、标识符、注释用英文。注释只解释"为什么"（全局规则见 `~/.pi/agent/AGENTS.md`）。
- **调研优先**：本项目当前处于调研/设计阶段。任何"某方案可行/不可行"的结论要么附可复现命令，要么标 **未验证**。
- **agent-notes**：`agent-notes/README.md` 是索引，`research/YYYY-MM-DD-<topic>.md` 一个主题一份，结论放最前面。做了决定就新建 `agent-notes/decisions/`，追加不改写。事实过期就地改并注明修正。
- **实验代码不是产品**：`experiments/` 下是一次性验证，可以糙；产品代码不要从那里"长出来"，要新写。
- **工具链（NixOS）**：用 flake 的 devShell：`nix develop -c <cmd>`（提供 typst 0.15.1 / cargo 1.97 / rustfmt / clippy / python3）。临时单跑某个工具用 `nix shell nixpkgs#typst -c ...`。不要用非 Nix 的包管理器。
- **flake 的坑**：nix 只看 git 已跟踪的文件，新建/改完 `flake.nix` 要先 `git add`，否则 `nix develop` 报 `not tracked by Git`。
- **Typst 事实**：写代码前先读 `agent-notes/research/2026-09-11-typst-engine-facts.md`，那里记着 label/show rule/link 的几个反直觉行为和 fence info string 的坑。
- **worktree**：功能开发走 `~/Projects/worktrees/literate/<topic>`；调研笔记与文档可以直接在 main 上改。
