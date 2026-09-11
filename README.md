# literate

基于 [Typst](https://typst.app) 的 literate programming 工具：**同一个 `.typ` 文件既是可排版的文档（weave），也是目标语言源码的唯一真相（tangle）**，并且与目标语言正交（工具只做文本替换 + 缩进，不解析目标语言）。

## 状态

调研 + 可行性 spike + MVP 决策已完成，进入原型阶段（M1，见 [`agent-notes/plan.md`](agent-notes/plan.md)）。

开发环境：

```sh
nix develop                        # typst 0.15.1 + cargo 1.97 + python3
nix develop -c experiments/2026-09-11-chunk-spike/run.sh   # 跑通 spike
```

- 调研与决策记录：[`agent-notes/`](agent-notes/README.md)
- 可运行的最小验证：[`experiments/2026-09-11-chunk-spike/`](experiments/2026-09-11-chunk-spike/README.md)、[`experiments/2026-09-11-typst-syntax-probe/`](experiments/2026-09-11-typst-syntax-probe/README.md)
- tangle 用官方 **`typst-syntax`** crate 直读源文件（有精确 span，**不需要装 typst**）；weave 用 `typst compile`。

已验证的核心机制：

```typ
#import "lit.typ": lit
#show: lit

解释性散文随便写。

```py
<<imports>>
``` <hello.py>     // label 看起来像文件名 → 这是根 chunk

```py
import sys
``` <imports>     // 普通 chunk，被 <<imports>> 引用
```

然后 `typst compile hello.typ` 得到 PDF，`lp tangle hello.typ` 得到 `hello.py`。
