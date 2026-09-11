# Literate programming 的思想：从 Knuth 到 agent（2026-09-11）

- 日期：2026-09-11（Asia/Shanghai）
- 问题：写一个给 agent 用的 literate programming（LP）skill 之前，先弄清这个思想本身到底主张什么、哪部分经不起实践检验、以及哪些部分在 agent 时代重新变得重要。
- 出处：文末「参考」。带引号的都是原文；`lp` 相关的结论来自本仓库的 `decisions/` 与实测。

## 结论（TL;DR）

1. **原始主张是"读者优先"**，不是"代码块能跑"。Knuth：*"The main idea is to treat a program as a piece of literature, addressed to human beings rather than to a computer."*（<https://www-cs-faculty.stanford.edu/~knuth/lp.html>）以及 *"Instead of imagining that our main task is to instruct a computer what to do, let us concentrate rather on explaining to human beings what we want a computer to do."*（Knuth 1984，引文见参考 [2]）。一个源，两个产物：**tangle** 给机器、**weave** 给人。
2. **核心机制是递归的名字替换，而不是"文档里嵌代码块"**。chunk 是**命名的想法**，引用可以嵌套，于是可以按**对读者最好的顺序**写、按**机器需要的顺序**展开（Ramsey 的摘要把这一点说得最清楚：*"tools let you arrange the parts of a program in any order and extract documentation and code from the same source file"*）。Jupyter/Quarto 这类 notebook 缺的正是这个：cell 必须**可执行**，于是顺序被运行时绑死（apiad 的对比）。
3. **写文档的收益在"被迫说清楚"这一步，不在文档本身**。Nørmark 的论证：理解本身才是大投资，*"It is a minor additional effort to formulate and articulate it"*，而*被迫*表述会在写的时候暴露出理解不够——这是 LP 的机制性收益，不是道德说教。【这条是我认为最有用的一个观点】
4. **chunk 的粒度应该跟"讲清楚一件事"对齐，而不是跟函数粒度对齐。** Nørmark 明确点出这个错位：现代程序有大量小抽象，*"there is a misfit between … being forced to name literal program fragment (scraps) and, on the other hand, named program abstractions"*。LP 的 chunk 名和语言里的函数名打架时，多数情况该让步的是 chunk 粒度。（对 `lp` 的直接含义：不要把一个函数拆成一个 chunk；chunk 是叙述单位。）
5. **没普及的原因是可分类的、且大部分与工具无关**（Nik Silver 的三类：工具链 / 个人 / 流程，+ 行业文化）。其中最硬的两条：(a) 现代 IDE/VCS/重构替代了一部分"必须靠文档才能读懂"的需求；(b) "设计文档是给未来的人的"，当下没有个人收益。→ 对工具的启示：**LP 工具必须让当下就爽**（实时同步、报错指回文档、漂移检测），否则它只是在收税。
6. **语言无关是 noweb 路线的全部要点**（Ramsey：simplicity, extensibility, language-independence；5 个控制序列 vs WEB 的 27；不做 prettyprint，因为那是语言相关的，而且*"most of my programs are edited at least as often as they are read"*）。`lp` 属于这条线：只做文本替换，语言差异只能是数据表。
7. **错误定位从第一天就是 LP 的一部分**：WEB 用 `#line` 让编译器报错指回 WEB 源；noweb 生态里有 `Noerr` 专门改写错误消息。不做这件事的工具会被使用者公开抱怨（`typst-unlit` 自己在文末写 *"this script does clobber the line numbers, so users beware"*，见 `prior-art.md`）。`lp` 的差异化位置：**chunk 级出处 + `lp explain` 回译 + 漂移检测**。
8. **AI/agent 时代 LP 的论证分两半，要分开看**：
   - 成立的一半：LP 文档**本身就是 context**——没有一段代码是文档里没解释过的（apiad）；"半成品也能解释"与 LLM 容忍 pseudo-code 契合；LP 的嵌套替换天然就是"顶层意图 → 逐层细节"的检索结构。
   - 需要警惕的一半：LLM 让"跳过写文档"变得极其便宜，所以**LP 在 agent 工作流里的价值更多是约束，而不是风格**：文档是唯一真相 → agent 只在文档里改 → 生成物由 `--check` 守漂移。我们自己的自举（ADR D15）就是这条约束的极端形态。
9. **反方意见要记住**：Knuth 把 LP 限定给"计算机科学家与系统程序员"，却期待它成为"文学"——写的人少、读的人多（Anticodians）；实践上 LP 真正落地的社区是数据科学（RMarkdown/Jupyter/nbdev），而那是"weave 出结果"，不是"文档为唯一真相"。LP 不是银弹，**选择什么时候用它**是 skill 必须给出的一部分（见 §7）。

## 1. Knuth 的原始主张

- 定义与两处引文见 §结论 1，出处 [1][2]。
- 目标读者比他后来承认的窄：*"Renaissance"* 那种"为人类写程序"的抱负 vs 他在 "Retrospects and Prospects" 里承认 LP 是给计算机科学家/系统程序员的（[8]）。这个错位是后面所有"为什么没普及"讨论的起点。
- 一个容易被忽略的细节：Knuth 的 LP 是**排版（paper）导向**的，TeX/METAFont 的书就是产物（535 页的单行本）。Nørmark 因此说 *"Paper is not the main program medium"*，并主张屏幕上的 *"you can understand what you see"*（YCUWYS）——这是后来所有"LP in the editor"路线的依据。

## 2. 两个动作，两个受众

| 动作 | 产物 | 受众 | 约束 |
| --- | --- | --- | --- |
| tangle | 可编译的源码 | 编译器 / 运行时 | 必须逐字节可控、可 diff、可 `--check` |
| weave | 可读的文档（PDF/HTML） | 人 | 排版、引用、导航 |

要紧的是这两件事**从同一份源出发**，且源里的顺序是"讲道理的顺序"。`lp` 的实现选择：tangle 走声明流 + 文本替换（`tangle.rs`），weave 交给 `typst compile`（包负责渲染）——两者不共享代码，只共享 `.typ`。

## 3. 递归的名字替换：LP 与 notebook 的分界线

- 名字（chunk）可以**先使用后定义**，因为展开在最后发生。这允许"顶层先写 `<<处理错误>>`，细节放到后面"——`lp` 的 `#chunk`/`#file` 就是这个机制的直接实现。
- notebook（Jupyter/Quarto/RMarkdown）要求 cell 可执行、依赖已存在，因此**不能**按叙述顺序随意组织；它们的强项是"跑出来给你看"（可复现研究），弱项是"讲清楚结构"。
- apiad 的总结值得抄进 skill：LP *"forgoes any structural requirements for executing the code in favor of using the best structure to understand the code. So, in LP, you can leave half of a method undefined because its details are not important at that moment."*
- 反面：递归替换也是工具的难点——**disentangled 的源码很难做 lint/类型检查**（apiad），所以"检查"必须发生在 tangle 之后、并且能把诊断投影回文档。这正是 `lp explain` 的存在理由。

## 4. 名字、粒度与"文档的 API"

- chunk 名是文档的公共接口：读者看到 `<<解析命令行>>` 就知道下面要讲什么，而 `rg '#chunk("解析命令行"'` 是唯一的导航手段（`lp` 没有行号映射，见 ADR D14）。
- 因此命名规范在 LP 里比在普通代码里更"重"：名字要说明**意图**，不是说明**类型**（`<<imports>>` 是反例，但它是工程惯例，可接受）。
- 粒度错位（§结论 4）的实践解：一个 chunk ≈ 一个段落能讲完的一件事；把函数体当 chunk 是常见的过度切分。

## 5. 为什么没普及（分类表 + 对工具的启示）

| 类别 | 具体反对意见（出处 [7][8]） | 对 `lp`/skill 的含义 |
| --- | --- | --- |
| 工具链 | 现代 IDE、VCS、重构取代了"必须靠文档理解"的一部分场景；LP 是额外依赖；主流编辑器没有 LP 模式 | 工具必须让"当下"受益：`lp watch` 实时、报错回译、`--check` 防漂移；不能让作者为了写文档而失去 IDE 能力（错误指回 chunk 就是为此） |
| 个人 | "代码很快就过时"；开发者不是作家；设计文档是给未来的人的 | skill 要给出**什么时候值得**的判断标准，而不是"所有代码都该 LP" |
| 流程 | 更慢、要纪律；改故事难；难以叙述"演进的代码"；样板代码也要写叙述；大系统怎么拆（TeX 是 535 页单册） | 支持增量：文档可以长出来；允许"这一节只讲结构、细节别处"；多文件工程（`lp` 的多根 chunk + `#include`）是回答"大系统怎么拆"的机制 |
| 文化 | 敏捷/精益把文档降级；缺少有说服力的案例（Knuth 的 TeX 几乎是唯一的） | 我们能提供的案例是**自举**：这个仓库自己的源码就是一份 LP 文档（`lp.typ`，ADR D15/D19） |

## 6. 语言无关路线（noweb）与 `lp` 的谱系

Ramsey 的三条设计目标（[4]）：**simplicity**（5 个控制序列）、**extensibility**（后端/过滤器可插）、**language-independence**（不做 prettyprint，不假设目标语言）。`lp` 继承的位置：

- 只做"名字替换 + 缩进"，目标语言知识为零（ADR D7/设计空间的正交性）；语言只出现在**数据**里（`lang` 标签）。
- 不做 prettyprint：渲染交给 Typst 包 + `codly` 之类的第三方包，这与 Ramsey 的理由一致（编辑/阅读不对称）。
- 不跟随 WEB 的 `#line` 注入（ADR D5）：产物保持与手写文件逐字节一致，代价是必须自己实现"诊断 → chunk"的回译（`explain.rs`）。

## 7. 什么时候值得、什么时候不值得（skill 的判断依据）

**值得**：教学/教程；需要跨多个文件解释一个算法或协议；裸机/自举/工具自身；配置与决策记录（"为什么这样"比"是什么"重要）；单人项目（Anticodians 指出多人大项目是 LP 的弱项）；需要给 agent 一份"完整 context"（§结论 8）。

**不值得**：一次性脚本；会被大量重构、且重构比阅读多得多的代码；样板代码占主体的工程；团队协作流程以 PR diff 为中心、没人会读文档的时候（apiad：LP 与"频繁 code review + 并行改不同模块"天然别扭）。

**misfit 的兜底**：文档是唯一真相时，任何"绕过文档改生成物"的行为都必须被机器拦住（`lp tangle --check` + `tests/self.rs`），否则 LP 退化成会漂移的注释。

## 8. 与 `lp` 现有契约的对应（设计输入）

| LP 的思想 | `lp` 里的机制 | 出处 |
| --- | --- | --- |
| 一个源、两个产物 | `.typ` → `lp tangle` / `typst compile` | D2 |
| 顺序由叙述决定 | 声明流按文档顺序；同名声明按序拼接 | D13 |
| 名字是接口 | `#chunk(name, …)` / `#file(path, …)`；`rg` 到声明 | D13/D14 |
| 诊断要指回文档 | `lp map` / `lp explain`（chunk 级出处） | D5/D14 |
| 文档不能漂移 | `lp tangle --check`、`.lpignore` 所有权 | D4/D10 |
| 当下就要爽（反"收税"） | `lp watch`：只写变化字节、语法错误不 tangle | D9 |
| 大系统拆章节 | 多文档 + `#include`（求值层面合并） | `research/2026-09-11-typst-structure-and-include.md` |
| agent 时代的约束 | `lp.typ` 唯一真相 + `tests/self.rs` 自复现 | D15 |

## 参考

1. Knuth, *Literate Programming*（CSLI Lecture Notes 27, 1992）与作者页上的定义：<https://www-cs-faculty.stanford.edu/~knuth/lp.html>（2026-09-11 取，本笔记的两段定义引文出自此页）
2. Knuth, "Literate programming", *The Computer Journal* 27(2):97–111, 1984：<https://academic.oup.com/comjnl/article-abstract/27/2/97/343244>。本笔记引用的 *"Instead of imagining that our main task is to instruct a computer…"* 一句取自该文，**经由二手页面的逐字引用**核对：<https://pqnelson.github.io/2024/05/29/literate-programming.html>（原始 PDF 本机抓取失败，见文末「未验证」）
3. Wikipedia, *Literate programming*：<https://en.wikipedia.org/wiki/Literate_programming>（tangle/weave 与历史脉络的概览）
4. Norman Ramsey, noweb 主页：<https://www.cs.tufts.edu/~nr/noweb/>（设计目标、prettyprint 的理由、`Noerr`、文末 McPhee 的引语）；论文摘要：Ramsey, "Literate Programming Simplified", *IEEE Software* 11(5):97–105, 1994，<https://www.cs.tufts.edu/~nr/cs257/archive/literate-programming/04-noweb.pdf>
5. Donald Knuth 的 LP 站点与程序集：<https://www-cs-faculty.stanford.edu/~knuth/programs.html>
6. Kurt Nørmark, "Literate Programming — Issues and Problems"（Aalborg）：<https://people.cs.aau.dk/~normark/litpro/issues-and-problems.html>（"understanding 才是投资"、paper 不是介质、YCUWYS、chunk 名与函数名的 misfit、"program lives in the documentation"）
7. Nik Silver, "Literate programming, part 2: Problems and challenges"（2019）：<https://niksilver.com/2019/10/22/literate-programming-part-2-problems-and-challenges/>（工具链/个人/流程/文化四类，指向 Bob Myers 与 Hacker News 的讨论）
8. Anticodians, "The End of Literate Programming"（2024-12-04）：<https://anticodians.org/2024/12/04/the-end-of-literate-programming/>（Knuth 的写作者/读者范围错位；LP 实际落地在数据科学；rustdoc/pydoc 是另一种"文档在程序里"的胜利）
9. apiad, "The Best Way to Vibe Code is Literate Programming"（Substack）：<https://blog.apiad.net/p/the-best-way-to-vibe-code-is-literate>（LP vs notebook 的递归宏 vs 可执行 cell；disentangled 源码难以 lint；AI 时代的论证；作者自己的工具 `illiterate`）
10. "A Literate Programming Environment for Human and Machine Agents"（arXiv 2608.24644）：<https://arxiv.org/pdf/2608.24644>（把 name 当一等对象、给 agent 提供符号检索；本仓库 `prior-art.md` §4 有摘要）
11. 本仓库内部：`research/2026-09-11-prior-art.md`（工具盘点与差异化）、`research/2026-09-11-design-space.md`（正交性边界、自举约束）、`decisions/2026-09-11-mvp-decisions.md`（D2/D3/D4/D5）、`decisions/2026-09-11-declared-chunks.md`（D13）、`decisions/2026-09-11-no-positions.md`（D14）、`decisions/2026-09-11-self-hosting-layout.md`（D15）

## 未验证 / 已知缺口

- Knuth 1984 原文 PDF 没抓下来（`literateprogramming.com/knuthweb.pdf` 抓取失败），所以那两句引文是**经二手页面逐字核对**的，没有对着原文 PDF 核。若要在公开材料里引用，先补一次原文核对。
- "LP 让 bug 更少"这类效果声明（Knuth 有、`byteiota` 之类二手文章也在说）**本笔记没有采信**：没有找到可复现的对照实验。别把它当论据。
- §7 的"值得/不值得"是从 [6][7][8][9] 的论点综合出来的工程判断，不是文献结论。
