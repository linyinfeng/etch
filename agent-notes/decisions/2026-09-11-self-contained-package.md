# D21 — 自包含的包；输出收进 `out/`；flake 不跟踪；skill 待评估（2026-09-11）

用户给的三条方向（按原话整理）：

1. **`flake.nix` 不想被仓库跟踪**；之后提供 `lp execute`，在 `out/` 里执行命令（例如 `lp execute nix flake check`）。
2. **skill 的意义待评估**——任何 agent 都可以直接读 `lp.typ` 这本"书"自己写一个 skill 出来。
3. **`lp` 必须自包含**：工具调用 typst 时把**内置**的 `lp.typ` 解压到文档所在目录的 `.lp/` 里，通过 `TYPST_PACKAGE_PATH` 提供给 Typst。用户本地 LSP 如何找到它**仍需考虑，先不管**。

## 调研：Rust 嵌入文本文件（用户点名要求）

**选 `include_str!`（标准库），不引入任何依赖。**

- 只需要嵌两个小文件（包清单 + 包正文）；`include_str!` 编译期校验 UTF-8、得到 `&'static str`、零运行时 IO、零依赖。
- 路径相对**源文件**（`src/metadata.rs` → `../lit/…`），这一点是常见坑，写代码时注意。
- 落选：`include_dir`（嵌整个目录树；我们只有一个目录两个文件，且它显著增加编译时间与二进制体积）、`rust-embed`（资产框架，带 dev/release 文件系统切换与 glob 过滤——我们用不上）。
- **不能退化成原始字符串常量**：包正文里有 `"#`（`rgb("#0a6")`），`r#"…"#` 会被它截断；`include_str!` 没有这个问题。

## 决定的形状（Typst 侧布局，已核实）

```text
<doc 目录>/.lp/                                  ← --package-path / TYPST_PACKAGE_PATH 指这里
└── local/lp/0.1.0/{typst.toml, lib.typ}
```

文档写 `#import "@local/lp:0.1.0": chunk, file, rule`，**不再依赖仓库里有一个 `lit/lp.typ`**。

- 工具在调用 `typst` **之前**解压内置包（内容来自二进制里的 `include_str!`），并把 `--package-path <root>/.lp` 传给 `typst eval`（等价于设 `TYPST_PACKAGE_PATH`，但不必改子进程环境）。
- 本仓库仍然产出 `lit/typst.toml` 与 `lit/lp.typ`：它们是**编译期要嵌入的源**，也是将来发布到 `@preview` 的东西。
- `.lp/` 是工具写的、不是声明 → 进 `.lpignore`（保护）与 `.gitignore`（忽略）。
- 用户侧 weave（`typst compile doc.typ`）与 LSP 需要自己设 `TYPST_PACKAGE_PATH=<doc>/.lp` ——**已明确推迟**（用户："现在先不用管"）。

## 状态（2026-09-11 当天实现）

- ✅ 工具内置包（`include_str!`，两个文件）并在调用 typst 前解压到 `<doc 目录>/.lp/{local/lp/0.1.0}/`，用 `--package-path` 指过去。
- ✅ 文档与示例改为 `#import "@local/lp:0.1.0"`；`.lp/` 由**所有权检查豁免**（像两个控制文件一样），项目不必声明它；`.gitignore` 忽略 `.lp/`。
- ✅ 用户视角验证：干净目录里只有一份 `doc.typ`（无 git、无包、无环境变量）→ tangle 出可运行代码，包被解压到 `<doc>/.lp/`。
- ✅ 示例的 `run.sh` 在两处纯 `typst` 步骤（weave 与渲染探针）里自己 `export TYPST_PACKAGE_PATH`——这正是用户编辑器要做的那一行。
- ⏳ 仍未做：用户侧 LSP 的便捷配置（用户明确推迟）。
- ❌ **`lp execute` 不做**（2026-09-11 用户：「目的不明确，暂时不要加」）：环境就是使用者的前提，或者一行 `nix shell`。

## 顺序：为什么先做自包含

自包含**消掉两个"必须在仓库根"的约束**：包不再需要手上有 `lit/`；种子也不必再提供包。之后把输出收进 `out/` 就只剩两件事要定（flake 与 skill），困难的部分先解决。

## 还没定

- **`lp execute`：不做**（用户 2026-09-11 决定）。它原本的动机是"在输出目录里带着环境跑命令"，但目的不明确：工具链是使用者的前提，借一行 `nix shell` 就够了；而 nix 的 tracked-flake 限制有别的解法（`path:`、非 flake 的 `shell.nix`），不值得为它发明一个命令。
- **skill 是否保留**：用户仍在评估（论点是"书本身够短、够清楚，agent 自己就能写出 skill"）。在评估结论出来之前，skill 保持现状（由文档产出），因为它的维护成本是零。
