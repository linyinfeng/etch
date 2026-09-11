# 怎么在这个仓库里干活（流程约定）

这些是**过程**约定，不是工具的设计规则——后者在 `lp.typ` 的 "The rules" 一节里。放在 agent-notes 是因为它们说的是"我们怎么做事"，与 lp 本身无关。

## 调研优先

任何"某方案可行/不可行"的结论，要么附一条可复现命令，要么标 **未验证**。结论写在 `research/YYYY-MM-DD-<topic>.md` 的最前面，出处内联在正文里。

## agent-notes 的约定

- `agent-notes/README.md` 是索引：一个主题一份笔记，做完决定就新建 `decisions/`。
- `decisions/` **追加不改写**：决定被推翻时新写一份、在旧的顶部标"已被 DXX 推翻"，把理由留档（D16 → D18 就是这么处理的）。
- 事实过期**就地改**并注明修正；不留两份互相矛盾的副本。
- 日期用本地日历日；"已验证"旁边写清用什么命令验的。

## 实验代码不是产品

`agent-notes/experiments/` 下是一次性验证，可以糙；产品代码不要从那里"长出来"，要新写。它们的运行产物（PDF、PNG、编译输出）不入库。

## 改动走 worktree

功能/修复在 `~/Projects/worktrees/literate/<topic>` 里做，分支 `<topic>`，从 `main` 切出；`main` 的 checkout 保持干净。调研笔记与文档可以直接在 main 上改。（单行文档改动、纯清盘这类"结构性整理"也按此办，除非它只动文档。）

## 工具链（NixOS）

- **环境不在仓库里**（2026-09-11：flake 已去掉，仓库不带 devshell）。要什么工具就借什么：
  `nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc nixpkgs#rustfmt nixpkgs#clippy -c <cmd>`。
  Rust 侧需要**含链接器**的完整工具链（只给 cargo 会失败在 `linker cc not found`）；typst 是 tangle 与 `cargo test` 的硬依赖。crate 在 `tangled/` 里，所以 cargo 命令带 `--manifest-path tangled/Cargo.toml`（或直接用 `dev.sh`）。 pi-lens 的 test runner 会报 `spawn cargo ENOENT`——基础 PATH 里没有 cargo，工具都是借来的；跑测试走 `dev.sh gates`，那条警告不是失败。
- 不用非 Nix 的包管理器，不用 `make install`、`curl | sh`。
- **flake 已从仓库移除**（D21）：它曾被这条规则困住（nix 只认 git 里 tracked 的 flake 文件），于是「环境由文档产出」走不通。**没有 `lp execute`**（2026-09-11 用户：目的不明确，不做）：工具链就是使用者的前提，或者借 `nix shell`。

## 语言与注释

与用户交流用中文；代码、标识符、注释用英文。注释只解释"为什么"（何时该写、何时不写见 `~/.pi/agent/AGENTS.md` 的 Code Comment Rules）。

## Typst 事实

写代码前先读 `research/2026-09-11-typst-engine-facts.md`：label、show rule、link 的几个反直觉行为，以及 fence info string 的坑。

## 本机噪声

pi-lens 偶尔报 `~/.config/pi-web/...` 的路径（例如 `src/main.rs`、`out/a.py`）：那是 harness 把仓库相对路径按自己的 cwd 解析的假象，那些文件不存在；以仓库内路径为准。
