# Where this stance comes from, and the case against it

Companion to [`../SKILL.md`](../SKILL.md). The long version, with the full map of positions and
sources, is `agent-notes/research/2026-09-11-literate-programming-thinking.md` in the `lp`
repository.

## The stance

- **The subject is the thinking, not the code.** A literate document is an exposition: the problem,
  the alternatives, the choice and why. The code is quoted into it as the evidence that makes the
  claims checkable. "Literate" is about what is being said — the code is what the saying produces.
- A program is a piece of literature addressed to human beings (Knuth): *"The main idea is to
  treat a program as a piece of literature, addressed to human beings rather than to a
  computer."* One source, two products — **tangle** for the machine, **weave** for the reader —
  and neither product is the original.
- **The order belongs to the reader.** The whole point of named references is that the text can
  be arranged in the order the design is understood, not the order the machine runs it (noweb:
  *"tools let you arrange the parts of a program in any order and extract documentation and code
  from the same source file"*). Where a fragment is declared — before or after it is first used —
  is part of that arrangement, and the tool does not vote (D18).
- **Chunks are parts of sentences and paragraphs, not of files.** A fragment exists because a
  section of the argument needed a name for something. When a chunk name and a function name
  compete, the chunk is usually the coarser thing, because it belongs to a thought.
- **Reading front to back is the contract**: idea → shape → steps → details. `lp` checks the
  mechanism only (references resolve, no cycles, generated files equal the text). Whether a
  section states a thought, whether the order suits a reader, whether the prose is *true* — none
  of that is checkable, and it is what [`../SKILL.md`](../SKILL.md) is for.
- **In an agent workflow** this is the point: the exposition is the complete context for the code
  (nothing is implemented that the text does not explain), and the checks are what stop the two
  from drifting. Writing prose is no longer the expensive part of literate programming — knowing
  what is true, and saying it clearly, is.

## The case against, in its strongest form

Keep these; they are the reasons this stance has to be argued rather than assumed.

1. **"It is over-commenting, and the comments drift."** Names, small functions, types and tests
   carry intent in a modern language; prose adds little and can lie. **Conceded where it is
   right**: the payoff falls as the language's expressive power rises, so the article earns its
   keep where *order and structure* are the difficulty — algorithms, protocols, tooling,
   bootstrapping, teaching — and in a mature codebase it earns it as explanation of *why*, not
   *what*. **Not conceded**: drift. In `lp` the drift is a check failure, not a matter of
   discipline.
2. **"Tooling friction is why WEB and CWEB stayed niche."** An extra tool between the author and
   the compiler, no editor support, and diagnostics that point at generated code. **Answered by**
   `lp watch` (only changed bytes are rewritten), chunk-level provenance (`lp map`, `lp explain`)
   and `--check`. **Conceded**: it is still another tool, and a fresh clone has to bootstrap.
3. **"Reading code just got cheap."** If an agent can read ordinary source, what does the article
   buy? **Answered**: the *why*, which was never in the code, and a single source that cannot
   drift. **Conceded**: if all you ever do is modify code and never explain it to anyone, the
   article is overhead — that is a claim about the work, not about the tool.
4. **"Generated prose can be confidently wrong."** A plausible paragraph contradicting its chunk
   is worse than no paragraph, because the next reader stops looking at the code. **Answered**:
   the enforced invariants and the read-it-back rule exist for exactly this; **conceded**: the
   risk lands on the writer, and no check catches it.
5. **"It does not fit multi-writer, PR-diff-centred teams."** Also true: the argumentative
   structure and the review flow pull in different directions. This document's audience is the
   author and the agent working alongside them, not a review queue.
6. **The historical counter-fact.** What actually won was generated documentation (Javadoc,
   rustdoc) and notebooks; strict tangling stayed a niche. That is an argument about adoption, not
   about correctness — and the reason the position here is "the document is the source" rather
   than "everyone should do this".

## Evidence

| Kind | Examples |
| --- | --- |
| Measured, reproducible | adoption history (WEB/CWEB niche, noweb in dozens of languages for decades, notebooks dominating data science); `typst-unlit` clobbering line numbers; `lp`'s own numbers (full tangle 3–7 ms, whole-repo ownership walk 0.82 s, 49 tests) |
| Reasoned testimony | Knuth, Ramsey, Nørmark, Silver, apiad, Anticodians — decades of practice, no control groups |
| **Not found** | any reproducible study showing literate programming reduces defects or maintenance cost. Knuth claims it, second-hand posts repeat it. Treat it as **unverified**, not as fact. |

## Sources

- Knuth, *Literate Programming* (CSLI, 1992) and his definition page: <https://www-cs-faculty.stanford.edu/~knuth/lp.html>
- Knuth, "Literate programming", *The Computer Journal* 27(2):97–111, 1984: <https://academic.oup.com/comjnl/article-abstract/27/2/97/343244>
- Norman Ramsey, noweb: <https://www.cs.tufts.edu/~nr/noweb/>; "Literate Programming Simplified", *IEEE Software* 11(5):97–105, 1994: <https://www.cs.tufts.edu/~nr/cs257/archive/literate-programming/04-noweb.pdf>
- Kurt Nørmark, "Literate Programming — Issues and Problems": <https://people.cs.aau.dk/~normark/litpro/issues-and-problems.html>
- Nik Silver, "Literate programming, part 2: Problems and challenges": <https://niksilver.com/2019/10/22/literate-programming-part-2-problems-and-challenges/>
- Anticodians, "The End of Literate Programming": <https://anticodians.org/2024/12/04/the-end-of-literate-programming/>
- apiad, "The Best Way to Vibe Code is Literate Programming": <https://blog.apiad.net/p/the-best-way-to-vibe-code-is-literate>
- "A Literate Programming Environment for Human and Machine Agents" (arXiv 2608.24644): <https://arxiv.org/pdf/2608.24644>
