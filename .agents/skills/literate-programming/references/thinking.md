# Why literate programming, when not to, and what the criticism actually says

Companion to [`../SKILL.md`](../SKILL.md). The long version, with the full argument map and
sources, is `agent-notes/research/2026-09-11-literate-programming-thinking.md` in the `lp`
repository.

## Four claims, which you can accept separately

Most arguments about literate programming (LP) are people disagreeing about different
claims. Keep them apart:

| | Claim | Who rejects it |
| --- | --- | --- |
| **C1** | The document is the source: code is tangled out of it | Javadoc/Doxygen/rustdoc school; anyone who thinks code plus generated docs is enough |
| **C2** | Write in the order a reader should meet the ideas, expand in the order the machine needs (named, recursive references) | Notebook school: cells must be executable, so execution order wins |
| **C3** | A program should be written as literature: prose is first-class, the reader comes before the machine | "Good code documents itself" school: naming, structure and tests already carry the intent |
| **C4** | The woven document has value on its own (typeset, publishable) | Most people: nobody reads printouts; the code is read in an editor |

`lp` implements all four, but the ones that carry the tool are **C1 and C2**. C3 is the
one to be honest about (see below), and C4 is a side effect of choosing Typst.

## The strongest criticism, in its strongest form

- **"This is over-commenting, and the comments will drift."** Naming, small functions,
  types and tests carry the intent now; prose adds little and costs maintenance. Readers
  who catch the prose lying once stop trusting all of it.
- **Conceded:** LP's value falls as the language's expressive power rises. So use it
  where *order and structure* are the hard part — algorithms, protocols, tooling,
  bootstrapping, teaching, decision records — not where a good name already says it.
- **"The order claim is unreachable in practice":** half-written code can be explained,
  but only if the tool lets the document not build. `lp` does: a document that fails to
  evaluate tangles nothing, and `lp watch` keeps the last good output.
- **"Tooling friction killed it"** (the historical reason WEB/CWEB stayed niche): an extra
  tool between the author and the compiler, no IDE support, no error mapping. The
  counter-move is not to argue but to remove the friction: `lp watch`, chunk-level
  provenance (`lp map`, `lp explain`), and `--check` as a gate.
- **"Reading code just got cheap"** (the LLM-era version): if an agent can read ordinary
  code, what does the document buy? Two things, and only two: the *why*, which was never
  in the code, and a single source that cannot drift. Both depend on the checks being
  real — which is why `lp tangle --check` and the self-reproduction test matter more in
  an agent workflow than the prose does.
- **Counter-risk to keep in mind:** generated prose can be confidently wrong. A plausible
  paragraph that contradicts the code is worse than a missing one, because it stops the
  next reader from checking. Prefer prose that names the trade-off over prose that
  narrates the statements.

## When it pays off, and when it does not

**Pays off:** teaching and tutorials; algorithms and protocols where the reading order is
the *point*; tools and bootstrapping you will return to; configuration and decision
records (why, not what); single-author projects; anything that has to hand a complete
context to another agent.

**Does not:** throwaway scripts; code refactored far more often than it is read;
boilerplate-dominated code; a team whose review flow is pull-request diffs and whose
members will never open the document.

**The misfit worth remembering** (Nørmark): programs are full of small named
abstractions, and chunk names compete with function names. When they compete, the chunk
should usually become coarser, not the function.

## Two ways to connect code and prose

- **Embed** (Knuth, WEB, noweb, `lp`): the code exists inside the document, so "out of
  sync" is physically impossible.
- **Relate** (Nørmark's suggestion): keep prose and code as separate entities and link
  them (hypertext, an index, a database). Cheaper to adopt, but the links need
  maintaining — unless the links are produced by the tangling step itself.

`lp` does both: the document is the sole source (embed), and the tangling step emits a
per-directory map from generated lines back to chunks (relate). The map costs nothing to
maintain because it is generated, which is the only reason the relate half is safe.

## Evidence

Worth being straight about, because the LP literature is mostly argument:

| Kind | Examples |
| --- | --- |
| Measured, reproducible | the adoption history (WEB/CWEB niche, noweb 35 years across languages, notebooks dominating data science); `typst-unlit` admitting it clobbers line numbers; `lp`'s own numbers (full tangle 3–7 ms, whole-repo ownership walk 0.82 s, 48 tests) |
| Reasoned testimony | Nørmark, Ramsey, Silver, apiad, Anticodians — decades of experience, no control groups |
| **Not found** | any reproducible study that LP reduces defects or maintenance cost. Knuth claims it, second-hand posts repeat it. Treat it as **unverified**, not as established fact. |

## Sources

- Knuth, *Literate Programming* (CSLI, 1992) and his definition page: <https://www-cs-faculty.stanford.edu/~knuth/lp.html>
- Knuth, "Literate programming", *The Computer Journal* 27(2):97–111, 1984: <https://academic.oup.com/comjnl/article-abstract/27/2/97/343244>
- Norman Ramsey, noweb: <https://www.cs.tufts.edu/~nr/noweb/> and "Literate Programming Simplified", *IEEE Software* 11(5):97–105, 1994: <https://www.cs.tufts.edu/~nr/cs257/archive/literate-programming/04-noweb.pdf>
- Kurt Nørmark, "Literate Programming — Issues and Problems": <https://people.cs.aau.dk/~normark/litpro/issues-and-problems.html>
- Nik Silver, "Literate programming, part 2: Problems and challenges": <https://niksilver.com/2019/10/22/literate-programming-part-2-problems-and-challenges/>
- Anticodians, "The End of Literate Programming": <https://anticodians.org/2024/12/04/the-end-of-literate-programming/>
- apiad, "The Best Way to Vibe Code is Literate Programming": <https://blog.apiad.net/p/the-best-way-to-vibe-code-is-literate>
- "A Literate Programming Environment for Human and Machine Agents" (arXiv 2608.24644): <https://arxiv.org/pdf/2608.24644>
