# 设计空间与决策清单

- 日期：2026-09-11
- 目标复述：一个**基于 Typst**、**与目标语言正交**的 literate programming 工具，weave + tangle 都是一等能力，且要让 AI agent 能用、能维护。
- 本文档只写"可选方案 + 取舍 + 待拍板项"。已定的事不写在这里，进 `decisions/`。

---

## 1. 四种候选架构

### A. 纯 `.typ` 为唯一真相，label 就是 chunk 名（推荐）
````
```py
<<imports>>
``` <hello.py>
````
- weave = `typst compile`（文档本身就是排版源，零预处理）。
- tangle = 外部 CLI：`typst eval 'query(raw.where(block:true)).map(...)'` → 展开 `<<ref>>` → 写文件。
- 优点：文件永远是合法 Typst ⇒ typst-lsp / typst-preview 直接可用；没有预处理器语法，agent 只需学一套规则；解析工作全部外包给 Typst 前端（含报错）。
- 代价：chunk 名靠 label（Typst 的 label 语义要绕开，见 engine-facts §4/§5）；`<<ref>>` 是纯文本约定，Typst 不会校验（tangle 必须严格报错：悬空引用、环、重复定义策略）。

### A′. 同上，但 tangle 逻辑用 Typst 写
`typst eval` 里能用 `read()`、字符串数组字典操作，所以可以 `#let tangle = ...` 把展开逻辑写成一个 `.typ` 库，CLI 退化成"跑 eval → 把 JSON 里的 filename/content 落盘"。
- 优点：整个工具链只有 Typst 一种语言；逻辑和文档共享类型系统；agent 改起来也只有一种语言。
- 代价：Typst 没有真正的文件系统写权限、错误处理/递归表达力偏弱（`bytes`/`str` 操作、无 while？其实有 for/while），性能一般。
- 定位：值得做一个 20 行的 spike 验证，但**不当作主线**（工具本身的健壮性/报错质量需要通用语言）。

### B. 独立 noweb 风格格式 + 预处理器（littst 路线）
```nw
= 标题
<<hello.py>>=
<<imports>>
@
```
- 优点：语法完全自由（可以做 `<<name>>+=`、可配置引用符号）；weave 时生成 `.typ`，目标语言正交性最容易做满。
- 代价：**主文件不是合法 Typst**，没有预览/补全/格式化；等于再发明一套 markup，与"基于 Typst"的初衷背离；已有 littst 占位。

### C. 目标源码为真相，`.typ` 只做 weave
`.typ` 里 `#raw(read("src/main.rs"))`（或 `codelst` 的带行号版本）。
- 优点：零 tangle、零漂移问题，上手成本最低。
- 代价：这就是"文档"，不是 literate programming：没有 chunk 组合、没有叙事重排、没有多块拼接。**作为工具的降级模式值得保留**（`.typ` 里直接引用生成物），但不满足本项目目标。

| 维度 | A | A′ | B | C |
| --- | --- | --- | --- | --- |
| 主文件是合法 Typst | ✅ | ✅ | ❌ | ✅ |
| 实时预览 / LSP | ✅ | ✅ | ❌ | ✅ |
| 自写解析器维护成本 | 无 | 无 | 有 | 无 |
| chunk 组合能力 | ✅ | ✅ | ✅ | ❌ |
| 错误定位可行性 | 中（见 §4） | 中 | 中 | N/A |
| agent 需要学的规则数 | 少（2 条：label=名字、`<<>>`=引用） | 少 | 中（新语法） | 极少 |

**结论：主线做 A，A′ 留作可行性 spike，C 作为"只 weave"的降级路径。**

---

## 2. A 方案下必须先定的语义

| 语义点 | 候选 | 倾向 |
| --- | --- | --- |
| 根 chunk 判定（写哪个文件） | (a) label 长得像文件名（含 `.` 且无空格）就是根；(b) 显式清单 `#let roots = (..)`；(c) 目录/前缀约定 `<file:main.c>` | (a) 简单直观、littst 先例；(b) 明确但要维护；(c) 无魔法但丑。倾向 (a) + 冲突时报错 |
| 同一 chunk 名多块 | (a) 按文档顺序拼接（noweb/org-babel 语义，实测可行）；(b) 报错；(c) 显式 `+=` | (a)，并在 CI 放一条回归测试（它依赖 Typst 未文档化的宽容） |
| 引用语法 | (a) 固定 `<<name>>`；(b) 可配置（因为 C++ `<<`、Java 泛型、shell heredoc 会撞） | 默认 (a)，配置项留好；(b) 的解析必须在"整行只有引用"时才展开（noweb 也是整行匹配），撞车概率低 |
| 缩进 | 子 chunk 整体缩进到引用点的缩进（noweb 语义） | 照做；提供 `--no-indent`（等价 noweb `-L`）给缩进敏感语言逃生 |
| 引用的求值时机 | 纯文本替换（不解析目标语言） | 必须如此，"正交"的定义 |
| 生成物 vs 手写文件 | 生成物一律可整体重写；检测到手改 → `--check` 报 STALE | 见 §4 |

---

## 3. 正交性的边界（"语言无关"在哪里会破）

1. **缩进敏感语言**（Python / Haskell / Fortran / YAML）：缩进调整会改语义。noweb FAQ 里 Fortran 固定列的例子是经典警示。<https://www.cs.tufts.edu/~nr/noweb/FAQ.html>
2. **行指令支持不均**：
   - 有：C/C++ `#line`、Go `//line`、Haskell `{-# LINE #-}`、OCaml `#line`、Rust（无原生，靠 `--remap-path-prefix` 之类也做不到行号）。
   - 没有：Python、JS/TS、Java、Shell…
   → 仅靠行指令无法做到语言无关，必须同时提供 sidecar 映射 + 包装命令（见 §4）。
3. **文件级语言约束**：Java `public class` 必须与文件名一致；Rust 需要 crate root / `lib.rs` 结构；Go 需要 `package`；shebang 必须在第 1 行；Python `from __future__` 与编码声明必须在最前。→ tangle 的"根 chunk = 一个文件"必须允许作者控制文件首行（chunk 内容里自己写 shebang 即可，但引用必须出现在第一行之后）。
4. **顺序语义**：文档顺序 ≠ 编译器需要的定义顺序（C 的前向声明、Rust 的 item 顺序宽松、Python 的 import 时机）。LP 的解法就是让作者显式用 chunk 组合把顺序写出来——这不是缺陷，是核心能力。
5. **注释语法无关**：tangle 产物里我们只能写"目标语言自己的注释"来做 provenance 标记 → 又需要语言知识。这是 §4 的另一个动机（sidecar 而非内联标记）。

**结论**：正交性的可交付定义 = "工具只做文本替换 + 缩进；语言差异只以**数据表**形式存在（扩展名→typst lang tag、扩展名→行指令模板（可选）、根 chunk 命名约定），不出现在算法里"。

---

## 4. 错误定位：本项目的核心差异化（也是最大技术债风险）

场景：tangled `foo.rs` 编译报错 `foo.rs:42`，人/agent 需要知道**改 `.typ` 的哪一行**。

| 方案 | 机制 | 优点 | 缺点 |
| --- | --- | --- | --- |
| D1 sidecar map | tangle 同时产出 `.lpmap.json`（spike 已实现：每个输出行 → `.typ` 行）；配一个 `lp run`/`lp map` 包装命令把诊断行号翻译回 `.typ` | 语言无关；无需改目标源码；可做成 `lp explain <diag>` 给 agent 用 | 需要用户走包装命令；与 IDE/编辑器集成要另外做 |
| D2 行指令注入 | 按目标语言注入 `#line`/`//line`/`{-# LINE #-}` | 原生工具链直接报 `.typ` 行号，零包装 | 只有部分语言支持；要维护语言表；产物里出现额外行，`--check`/diff 与手写文件不再逐字一致 |
| D3 生成物里的注释标记 | 每个 chunk 前后插入目标语言注释 `// <<chunk: foo>>` | 人眼友好、任何语言都行 | 需要语言注释语法（又是语言知识）；污染产物 |
| D4 不解决，只给 chunk 级 | 报"该行属于 chunk X（`.typ` 第 N 行起）" | 最简单 | agent 修 bug 时不够精确 |

**倾向**：D1 为主（已 spike 验证数据可得），D2 作为可选增强（数据表驱动），D4 作为第一版的保底（先给 chunk 级 + 起始行）。这一条必须在 MVP 里就有，否则和 littst/typst-unlit 没区别。

---

## 5. 生成物是否入库（决定 CI 与 agent 工作流的形态）

| 选择 | 好处 | 代价 |
| --- | --- | --- |
| 入库（提交生成物） | clone 即能编译；agent 直接看得到代码；不用装 typst 就能 review | 每次改文档都产生大 diff；必须靠 `--check` 防手改漂移 |
| 不入库（gitignore） | diff 干净；唯一真相明确 | 任何构建/agent 都要先跑 tangle；仓库里没有"可读代码" |

**倾向**：不入库 + CI 跑 `tangle --check`（漂移即失败）；同时提供 `lp watch` 让本地/agent 编辑时自动重新 tangle。理由：一旦生成物入库，AI agent 极容易去改生成物而不是文档——这是 AI 时代 LP 最现实的失败模式。

---

## 6. 待拍板（需要用户决策）

1. **首要使用场景**：个人文档型项目 / 多文件库 / agent 工作流，哪个先做透？
2. **主文件形态**：A（纯 `.typ`）还是 B（独立格式）还是两条都支持？
3. **实现语言**：Python 原型（最快）／Rust（`typst-syntax` 能拿 span，可发单文件二进制）／Node/TS（与 pi 生态一致，typst.ts 可选）。
4. **生成物入库 + CI 策略**：入库+check / gitignore+watch / 两者可配置。
5. **错误定位**：D1 / D2 / D1+D2。

（chunk 引用语法、根 chunk 判定、缩进语义按 §2 的倾向先定，属可逆细节。）

---

## 7. MVP 范围建议（lazy 版）

```
lp tangle <doc.typ> [--out DIR] [--check] [--watch]   # 核心
lit.typ                                                # Typst 库：chunk 渲染 + 引用链接 + 编号
```
- 不做：双向同步、IR/provenance 数据库、多格式适配器、语言执行（Calepin 那条线）、编辑器插件。
- 必须做（否则没差异化）：悬空引用/环/重复定义报错、`--check`、行号映射、`lp` 在文档有错时把 typst 诊断透出。
- 检查方式：spike 里已有的 `run.sh` 模式（tangle → 跑生成的程序 → 比对输出 → check）。

---

## 8. Backlog（下一步该调研/验证的）

- [ ] 把 A′ （tangle 逻辑写在 Typst 里）做成 20 行 spike，评估报错质量与性能。
- [ ] 错误定位 D1 的端到端体验：拿一个真实 `cargo`/`python` 报错，走 `lp explain` 翻译，看 agent 是否够用。
- [ ] `typst-syntax`（Rust）/ `typst.ts`（WASM）能否拿到精确 span 并替代 `typst eval` 路线（代价：版本漂移、要跟 Typst 语法演进）。
- [ ] 与 `codly` / `codelst` 共存策略（show rule 覆盖顺序、统一主题）。
- [ ] 多根 chunk + 目录结构（`src/`）与"生成物不入库"的配合。
- [ ] agent 集成：为使用本工具的目标仓库生成一段 AGENTS.md（告诉 agent"只改 `.typ`，改完跑 `lp tangle`"）。
- [ ] 精读 arXiv 2608.24644 的 name-graph 部分，看是否值得把 chunk 依赖图 + prose 引用做成可查询输出（agent 符号检索）。
- [ ] 论文级问题：同一 chunk 被多个根复用时，行号映射要能一对多（spike 的实现天然支持，未验证）。
