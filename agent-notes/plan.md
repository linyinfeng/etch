# 实施计划（M0–M3）

- 日期：2026-09-11（v2：按 ADR D6/D7 修正引擎与依赖）
- 前置：`decisions/2026-09-11-mvp-decisions.md`（场景=多文件工程，形态=纯 `.typ`，实现=Rust→自举，生成物不入库，错误定位=D1）、`decisions/2026-09-11-engine-and-deps.md`（D6 引擎、D7 依赖策略）
- 原则：tangle 的语义与报错精度是产品本体；CLI/watch/诊断渲染用成熟库，不手写已被解决的问题。

## 里程碑

### M0 — 仓库与开发环境（已完成）
- `flake.nix` + `flake.lock`：`typst` + `rustc/cargo/rustfmt/clippy` + `python3`。实测 `cargo 1.97.0 / rustc 1.97.1 / typst 0.15.1`。
- 目录：`src/`（原型）、`lit/`（Typst 渲染库）、`experiments/`、`agent-notes/`。

### M1 — 原型 tangle + check + map（已完成，2026-09-11）

实现：`src/{main,parse,tangle,map,explain,diag}.rs`（~600 行）+ `lit/lit.typ` + `tests/flow.rs`（11 个端到端用例 + 5 个单元用例）。

- ✅ `lp tangle <doc.typ>... [--out DIR] [--check]`
- ✅ 解析：`typst-syntax` 递归遍历 CST；接受两种 label 写法（`<name>` 与 `#label("path")`，见 ADR D8）；`raw.lines()` 取正文；`Source::lines().byte_to_line()` 得行号
- ✅ 严格报错（`miette` 渲染，指向 `.typ` 源 span）：悬空引用、引用环、空 chunk、不安全输出路径
- ✅ 同名 label 多块按文档顺序拼接；缩进按引用点传递（`tests/flow.rs` 覆盖）
- ✅ `lp map` + `.lpmap.json`（`[生成行, .typ 行]`，指向定义处）+ `lp list`
- ✅ `lp explain` 的**通用后端**（`file:line:col:` → `.typ` 源片段）；未引用 chunk 告警
- ⏳ 留到下一轮：`lp watch`（`notify`）、`lp explain --format cargo`（`cargo_metadata`）、诊断列位置精确到 span（现在高亮整行）、“同一 chunk 被多个根复用”与多文档合并的边界测试

**下一步起点**：`src/` 是普通 Rust 工程（`cargo test` 全绿）；演示与回归入口是 `examples/demo/run.sh`（tangle → 构建运行 → weave → `--check` → map → explain 回译 → 复原）。

### M2 — 多文件工程 + watch + explain（进行中）
- ✅ 多根 chunk → 目录结构（`src/`、`tests/`）；输出路径相对 `--out`。
- ✅ `lp watch <doc.typ>`：`notify` + `notify-debouncer-full`；只写字节变化的输出、语法错误不 tangle、出错只打印不退出。**行为契约见 ADR D9**，实测见 `research/2026-09-11-lazy-tangle.md`。
- ✅ `lp explain` 的通用后端（`regex` 表处理 `file:line:col:`），纯查表 + 通用解析，**不含目标语言算法**。
- ✅ `lp map` 双向（`--file` / `--typ`）。
- ⏳ 剩下：`lp explain --format cargo`（`cargo_metadata` 解析 `--message-format=json`，自举时天天用）、诊断列位置精确到 span（现在高亮整行）、`ci.sh`（typst compile + cargo test + `tangle --check`）。
- ✅ 删除语义（超出原计划）：删根 chunk 不再留孤儿。账本（`.lpmap.json`）+ 目录声明（`.lpignore`）+ `--prune` + `--check` 干跑，见 ADR D10，回归在 `tests/owned.rs`。

### M3 — 自举（bootstrap → self-host）
- 原型冻结为 `bootstrap/`（仍可编译可跑），工具自身源码改写为 `self.typ`（literate 文档）。
- **自举不变量（固定点测试）**：`bootstrap tangle self.typ --out src` 的产物与 `bootstrap/` 手写源码**逐字节相同**，且用产物 `cargo build` 出来的工具与原型行为一致（跑同一套测试）。
- 达标后 `self.typ` 成为唯一真相；`bootstrap/` 作为**非工具生成的种子**保留（因为生成物不入库，种子必须可编译）。
- 自举是可用性测试：如果天天退回手写源码，说明 chunk 语义或错误定位不可用。

## CLI 表面

```
lp tangle <doc.typ>... [--out DIR] [--check]
lp map    --file <generated> --line N [--col C]
lp explain [--format cargo|generic] [<diag-file>]
lp watch  <doc.typ> [--out DIR]
lp list   <doc.typ>            # 调试/agent 检索：chunk 名、根、引用图、源位置
```
- 退出码：0 成功；1 语义错误（悬空引用/环/漂移）；2 用法或环境错误。
- `typst` 二进制：**只在 weave 和 oracle 测试里需要**（tangle 走 `typst-syntax`）；定位顺序 `--typst` > `LP_TYPST` > `PATH`。

## 依赖（D7：成熟库优先）
见 ADR D7 的表格。首版新增依赖前必须在表里补一行"为什么是它"。当前：`typst-syntax`、`clap`、`serde`/`serde_json`、`thiserror`+`miette`、`notify`+`notify-debouncer-full`、`regex`、`cargo_metadata`、（dev）`tempfile`。

## 测试策略（ponytail：能失败的最小检查）
- `cargo test`：tangle 语义 fixture（拼接/缩进/嵌套块/悬空/环/重复 label）、oracle 一致性、固定点（M3）。
- 端到端沿用 `experiments/2026-09-11-chunk-spike/run.sh` 的模式：tangle → 跑生成物 → 比对期望输出 → `--check`。
- CI：`nix develop -c ./ci.sh`（`typst compile` + `cargo test` + `lp tangle --check` 无漂移）。

## 明确不做（YAGNI）
双向同步（Entangled 路线）、IR/provenance 数据库、多 markup 适配器（Ravel 路线）、代码块执行（Calepin 路线）、编辑器插件、`codly` 深度集成。
