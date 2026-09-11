# 实施计划（M0–M3）

- 日期：2026-09-11
- 前置：`decisions/2026-09-11-mvp-decisions.md`（场景=多文件工程，形态=纯 `.typ`，实现=Rust→自举，生成物不入库，错误定位=D1）
- 原则：先把 spike 里已经验证过的语义**做扎实**（严格报错 + 可测），再加能力面。不做 watch 之外的花活。

## 里程碑

### M0 — 仓库与开发环境（本次完成）
- `flake.nix`：`typst` + `rustc/cargo/rustfmt/clippy` + `python3`（spike 用）。
- 目录定案：`src/`（原型 Rust）、`lit/`（Typst 库 `lit.typ`）、`experiments/`（已完成）、`agent-notes/`。
- 结论：任何"某方案可行"的说法都要有 `cargo test` 或 `run.sh` 支撑。

### M1 — 原型 tangle + check + map（核心语义）
把 `experiments/.../tangle.py` 的语义用 Rust 重写，并补齐 Python 版故意没做的：
- `lp tangle <doc.typ>... [--out DIR] [--check]`
- 严格报错：悬空引用、引用环、根 chunk 重名、根 chunk 与非根 chunk 重名（退出码非 0，信息带 `.typ` 行号）。
- 同名 label 多块按文档顺序拼接（noweb 语义）；**并且**在 `cargo test` 里放固定 fixture 守住"Typst 容忍重复 label"这个未文档化行为。
- `lp map --file out/foo.rs --line 42` → `doc.typ:16`（消费 D1 的 sidecar map）。
- `--check`：生成物与文档不一致 → 非零退出（CI 用）。
- 产物：`out/.lpmap.json`（schema 固定下来，写入 README/notes）。
- 质量门：错误信息一律形如 `doc.typ:16: dangling chunk <<body>> referenced from <<main.c>>`。

### M2 — 多文件工程 + watch + explain
- 多根 chunk → 目录结构（`src/`、`tests/`），一个文档可产出多个文件；`--out` 与文档相对路径的语义定死。
- `lp watch <doc.typ>`：轮询 mtime（原型够用，`ponytail:` 若频率成问题换 `notify`），改动即 tangle，出错只打印不崩。
- `lp explain`：读诊断文本/JSON → 翻译成 `.typ` 位置。第一个后端 **rustc/cargo JSON**（`cargo build --message-format=json`），第二个是通用 `file:line:col:` 正则。**纯查表，不含语言算法。**
- 负向测试：把生成物手改 → `--check` 失败；把 `.typ` 里引用写错 → 报错行号正确。

### M3 — 自举（bootstrap → self-host）
- 把原型冻结为 `bootstrap/`（仍然可编译、可跑），并把工具自身源码改写成 `self.typ`（literate 文档）。
- **自举不变量（固定点测试）**：`bootstrap tangle self.typ --out src` 产出的 `src/*.rs` 与 `bootstrap/` 的手写源码**逐字节相同**；然后 `cargo build` 用产出的源码构建出功能等价的工具。
- 达标后：`self.typ` 成为唯一真相，`bootstrap/` 只作为"种子"保留（因为生成物不入库，种子必须是可编译的、非工具生成的手写代码）。
- 之后所有开发在 `self.typ` 里做，用 `lp watch` 自举。

## CLI 表面（先定，避免实现时跑偏）

```
lp tangle <doc.typ>... [--out DIR] [--check] [--root DIR]
lp map    --file <generated> --line N [--col C]
lp explain [--format rustc|cargo|generic] < diagnostics
lp watch  <doc.typ> [--out DIR]
lp list   <doc.typ>            # 调试用：打印 chunk 名/根/引用图（agent 检索入口）
```
- 退出码：0 成功；1 语义错误（悬空引用/环/漂移）；2 用法或环境错误（找不到 typst 等）。
- `typst` 定位：`--typst` 参数 > `LP_TYPST` 环境变量 > `PATH`。
- 不做：`lp init`、配置文件、双向同步、`lp run`（交给用户的构建系统 + `lp explain`）。

## 依赖预算
- 必需：`serde_json`（解析 `typst eval` 输出）。
- 建议：无。参数解析手写（5 个命令、十来个 flag），watch 用 mtime 轮询。
- 明确不加：`clap`、`notify`、`anyhow`（错误信息要自己拼成 `doc.typ:行:列:` 格式，正好不需要 anyhow 的链路）。自举后这些依赖同样要在文档里维护，越少越好。

## 测试策略（ponytail：能失败的最小检查）
- `cargo test`：tangle 语义的 fixture 测试（拼接/缩进/悬空/环/重复 label 容忍）+ 固定点测试（M3）。
- `experiments/2026-09-11-chunk-spike/run.sh` 的模式沿用到 `tests/`：tangle → 跑生成物 → 比对期望输出 → `--check`。
- CI：`nix develop -c ./ci.sh`（typst compile 通过 + cargo test + tangle --check 无漂移）。

## 明确不做（YAGNI，等到有人真的需要）
- 双向同步（Entangled 路线）、IR/provenance 数据库、多 markup 适配器（Ravel 路线）、执行代码块（Calepin 路线）、编辑器插件、`codly` 深度集成（先用 `lit.typ` 自己的 show rule）。
