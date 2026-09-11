# 接手说明（handoff）— 2026-09-11（`lp.typ` 重排成论证之后）

> 这是**快照**，会过期。行动前先 `git log --oneline -5`，然后读 `lp.typ`（唯一权威）与 `agent-notes/README.md`（索引 + 当前状态）。

## 30 秒

- **是什么**：`lp` —— 基于 Typst 的 literate programming 工具。同一个 `.typ` 既是可排版的文档（weave = `typst compile`），也是多种目标语言源码的唯一真相（tangle = `lp tangle`）。目标语言正交：算法里没有任何目标语言知识。
- **仓库形态（D19 + D21）**：tracked 只有 **五样**——`README.md`/`AGENTS.md`（各一行指针）、`lp.typ`、`seed/`、`agent-notes/`。其余一切——crate、包、示例、控制文件——都是 `lp tangle lp.typ --out .` 的产物。flake 与 skill 已于 2026-09-11 移除（D21）：前者被「nix 只认 tracked 文件」困住，后者被认为不需要（读这本书就能写出 skill）。
- **`lp.typ` 已重排成一篇论证**（约 6100 行，其中约 1250 行散文）。阅读顺序即"构建顺序"：

  ```text
  这个工具在说什么（含 literate 的四条主张）
  包：一个声明是什么            lit/lp.typ
  错误怎么报                    src/diag.rs
  问文档它声明了什么            src/metadata.rs
  一趟 pass 拿声明做什么         src/tangle.rs
  把诊断译回声明                src/explain.rs
  每行输出来自哪里              src/map.rs
  输出目录归谁                  src/status.rs
  边编辑边保持同步              src/watch.rs
  命令面                        src/main.rs
  测试怎么写                    tests/*.rs（五个文件，一个用例一个片段）
  构建环境 / 仓库携带什么 / git 忽略什么   Cargo.toml、.lpignore、.gitignore
  从零开始 / 换种子 / 规则
  例子                          examples/demo/**（按它自己的小节拆）
  ```

- **每个生成文件都是"骨架 + 命名片段"**：根声明正文只剩真实行与 `<<步骤>>`，每个片段都在解释它的那一节里定义。重排期间**十五个生成文件全部逐字节不变**。

## 现在是什么（契约）

| 问题 | 谁回答 | 机制 |
| --- | --- | --- |
| 有哪些 chunk、顺序、文本、语言 | **Typst 求值** | 文档 `#chunk`/`#file` 声明；工具 `typst eval 'query(<lp-decl>)'` 读回，**从不解析 Typst**（D13） |
| 引用展开、缩进、悬空/环/空报错 | `lp`（`tangle.rs`） | 纯文本替换 + 缩进；`@<<name>>` 是转义，原样输出 `<<name>>` 且不计为引用（D17） |
| 每行输出来自哪个声明 | `lp`（`map.rs`，schema v5） | chunk 区间；**没有 `.typ` 行号**（D14） |
| 输出目录里的东西归谁 | `lp`（`status.rs`） | produced / declared（`.lpignore`，匹配=保护）/ unaccounted（错误）；检查在写盘**之后**跑（D20） |
| weave | `typst compile` | 包由文档自己产出（"包"那一章） |

## 写这个文档时的四条规矩（都踩过）

- **只改 `lp.typ`**；生成物一律由 `tangle` 产出，手改会被 `tests/self.rs` 抓住。
- **私有片段名带文件前缀**（`map: …`、`tangle: …`、`flow: …`）：**chunk 名是全文档全局的**，两章同名会**拼接**进同一个文件——`map.rs` 一度被塞进 `explain.rs` 的开头。
- **缩进引用的片段里不许有空行**：引用点的缩进会加到片段的每一行，空行会变成一行空格（`cargo fmt --check` 报差异）。空行留在骨架里。
- **片段不能含它所在框架的收尾 `}`**：收尾括号留在骨架里。

## 重排的纪律（下次再重排时照做）

- 抽取脚本按行范围抽片段（fence 长度自动、`@` 转义、空行断言），**但永远从纯净副本抽取**（`/tmp/*.before`）：`src/` 会被 tangle 重写，而 `git checkout -- lp.typ` 会连未提交的章节一起回退（都踩过）。
- 一章一提交；提交前四道闸门全绿：`--check`、`cargo test`（49）、`examples/demo/run.sh`、`typst compile lp.typ` 零警告。**每次都用 `diff` 对照重排前的副本**——`--check` 只能证明"文档与磁盘一致"，证不了"重排没有改写代码"。

## 教学清单（目标判据的可核对位置）

| 要教的 | 在文档哪里 | 怎么自己验 |
| --- | --- | --- |
| (a) literate 的四条可分别表态的主张 | 开头 "What literate programming is, in four claims"，紧跟一段"反方论证"（原来在 skill 的 `thinking.md`，skill 移除时折进正文） | `rg -n 'four claims' -A 22 lp.typ` |
| (b) tangle / weave 的分工 | 开头 + "The package"（渲染与声明为什么在同一个函数里） | `lp tangle lp.typ --out /tmp/x && ls /tmp/x/src \| head` 与 `typst compile lp.typ /tmp/lp.pdf` |
| (c) 名字即接口、顺序自由 | "The package"、"What a pass does with the declarations"（展开即递归替换）、"The rules"（D18） | `lp list lp.typ \| head`（看 frag/file 与顺序）；`lp metadata lp.typ \| head`（声明流即阅读顺序） |
| (d) 转义 `@<<name>>` 为什么存在 | "The package"（第二个 pattern）+ "how to write one without it being one" | `rg -n '@<<' lp.typ \| head`（`@` 只在文档里，tangle 之后就不见了） |
| (e) 没有行号、出处到 chunk 级 | "Reading a diagnostic back to the declaration" + "Where each generated line came from" | `lp map --out . --file src/diag.rs --line 5`；`echo 'src/diag.rs:5:1: boom' \| lp explain --out .` |
| (f) 所有权的三组与 `--check` | "Who owns the output directory" + "What this repository carries" | `lp unaccounted lp.typ --out .`；`touch /tmp/stray && lp tangle lp.typ --out . --check` |
| (g) 自举：种子、`cp -r seed/. .`、自复现 | "Starting from nothing"、"Replacing the seed"、"How the tests are written" | 文档里那四行 bootstrap 命令；`cargo test --test self` |

## 下一步候选

- `lp explain --format cargo`（`cargo_metadata` 解 `--message-format=json`）；现在命令面一章里就写着它是"not yet"。
- 把 `lit/lp.typ` 发布到 `@preview`（包现在由文档产出，剩下的是流程问题）。
- 文档再长时的退路：按章节拆成多个文档（工具已支持多文档、`#include` 也在求值层合并）。

## 环境陷阱

- **环境不在仓库里**（flake 已移除，D21）：`typst` 必须在 PATH（或 `LP_TYPST`；tangle 与 `cargo test` 都要它），Rust 侧要**含链接器**的完整工具链（只给 cargo 会失败在 `linker cc not found`）。
- **自用脚本**：`agent-notes/dev.sh gates`（或 `test`/`fmt`/`clippy`/`check`/`demo`/`weave`，或 `dev.sh <任意命令>`）。它是临时的，等 `lp execute` 出现就该删。
- **包是自包含的**：工具把内置包解压到 `<doc>/.lp/{local/lp/0.1.0}/` 并传给 `typst --package-path`；纯 `typst` 的步骤（weave、LSP）要自己设 `TYPST_PACKAGE_PATH=<doc>/.lp`。
- **`--out` 就是仓库根**：`lp tangle lp.typ --out . --check` 是干跑、随时可跑；`lp unaccounted … --delete` 等于对全仓库动刀，看清单再动手。
- **本机噪声**：pi-lens 偶尔报 `~/.config/pi-web/...` 的路径，那是 harness 的 cwd 假象；以仓库内路径为准。
