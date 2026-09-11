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

## 输出目录：`tangled/`，以及它自己的仓库（2026-09-11 实现）

用户接着要求：**所有产出收进一个 gitignore 的目录**，并且"解开后应保证它自己是一个 git repo，便于人类/agent 自行版本管理"。

- **名字**：`tangled/`（`out/` 只是占位）。**默认就是它，且是文档旁边的那个**：`--out` 未给时取文档所在目录下的 `tangled`（无文档的命令用 cwd 下的 `tangled`）。所以 `lp tangle lp.typ` 就够了。
- **声明路径不变**：`#file("src/…")` 依旧是相对输出目录的；搬的是*调用*与*文件的物理位置*，不是文档里的路径。这一点先做错过一次（给每个声明加 `tangled/` 前缀），结果是根目录成了输出目录、所有权检查开始抱怨根上的 README/AGENTS/seed——目录决定范围，前缀不行。
- **它自己的仓库由流程建立，不由工具建立**：`git init tangled` 写在 bootstrap 与 `dev.sh bootstrap` 里（幂等），`tangled/.lpignore` 里写一行 `/.git`。理由：工具在别人的输出目录里悄悄 `git init` 是越界；而且 ADR D10 明定了**没有 git 特例**（`.git/` 是普通内容，`tests/owned.rs` 里有用例钉着）。这样文档仓库管源、`tangled/` 管产物。
- **代价**：根上多一个 tracked 文件——`.gitignore`（3 行，`/tangled/`），因为忽略输出目录的文件不可能在输出目录里面；`cargo` 的命令带 `--manifest-path tangled/Cargo.toml`。
- **种子**：随之为 out 形状（`seed/tangled/{Cargo.toml,Cargo.lock,src,tests,lit}`），`cp -r seed/. .` 照旧铺下整棵树。

## 种子搬到分支（2026-09-11 同日晚；2026-09-12 分支由 `seed` 改名 `tangled`）

用户提议：用一个特别的 git branch 放 seed，它实质上就是"跟随 main 更新"的 main 的 tangle 产物。采纳。

- **main 的树回到纯源**：文档 + 手记 + 两个指针 + 根 `.gitignore`，没有 `seed/`。种子是**输出**，输出该住在分支上（这是唯一能不占工作树、又能被 clone 取到的地方）。
- **bootstrap**：`seed_ref=$(git rev-parse --verify --quiet seed || git rev-parse --verify --quiet origin/seed)` + `git archive "$seed_ref" | tar -x -C tangled`。clone 只带来 `origin/seed`，所以两种名字都试；不需要第二个 remote。
- **刷新**：`dev.sh seed`。踩到的事实：**git 不能 `add` 含 `.git` 的目录**（把它当嵌套仓库、静默跳过——第一次尝试因此得到一个空树）。所以用临时索引 + 从 `git -C tangled archive HEAD` 填出来的临时工作树 + `commit-tree`（父提交 = 上一个 seed）+ `update-ref`；工作树全程不动。
- **不变量**：seed 分支的树哈希必须等于 `tangled/` 自己 HEAD 的树哈希——"seed 就是这一代产物"的可检查形式；`dev.sh seed` 断言它，不等就 `MISMATCH` 非零退出。
- **何时刷新**：属于一次改动，不属于仪式。要求只有一条：seed 必须是**能读懂当前文档**的一代；落后一代就够，等于当前更好。`--check` 管不了这件事（它守树，不守分支）。
- **同时**：内层 `.gitignore` 的规则改成不锚定（`.lp`/`.lpmap.json`/`target` 落在树里任何位置都算工具状态——示例目录下也会出现），`[workspace] exclude` 去掉 `seed`。

### 分支不留工作树（2026-09-12）

用户决定：`tangled` 只是分支，不留常驻工作树，按需 checkout / `git show` / `git archive` 取用。好处是那个隐患消失——分支被 checkout 时，plumbing 的 `update-ref` 会让工作树静默变旧。代价是临时看一眼要自己敲命令；`dev.sh tangled` 因此加了一条守卫：发现该分支被某个工作树 checkout 就拒绝更新并打印位置（按需看完删掉再刷）。

### seed 分支里放什么（同日追问后写明）

用户问：`.lpmap.json` 不该出现在 seed 里吗？判断依据是什么？tangle 的哪些输出被排除出了 seed？

事实（读代码得到，不是感觉）：

- `map.rs::write_if_changed` —— `.lpmap.json` 只在内容变化时才写，是**纯派生**的（映射 = 文档的结构），每个收到文件的目录一份（所以有 `src/`、`tests/`、`lit/`、`examples/demo/` 各一份）。
- `status.rs::is_control_file` —— 所有权检查把 `.lpmap.json`（和 `.lpignore`）当**控制文件**豁免：工具自己就说这是它的记账，不是树的内容。

规则（现写入书中"seed 分支"章）：**分支携带树自己的仓库提交的东西**——声明产出的文件，加 `Cargo.lock`（种子里唯一不由声明产出的文件：钉住的解析结果是一个决定，不是推导）。排除的三类各有理由：`.lpmap.json`（控制文件、纯派生）、`.lp/`（解压出的包副本，同样派生）、`target/` 与示例的 `build/`（构建与嵌套文档的产物，不是本文档的产物）。验收标准只有一条、可跑：**从分支单独 bootstrap 必须绿**。

自我批评：这条规则此前是**隐含在内层 `.gitignore` 里**的——等于让一个手写的 git 设置悄悄定义种子的构成。现在它写在书里，`.gitignore` 只是它的实现。
