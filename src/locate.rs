//! Where a chunk was written — found by searching, not by parsing.
//!
//! Typst reports which chunks exist but not where they are, and re-implementing
//! Typst's grammar to find out would be both enormous and wrong (the two disagree
//! the moment a document generates anything). So positions come from plain
//! searching of the source text, in four tiers, most trustworthy first:
//!
//! 1. **Literal block** — the chunk's label appears in the source, and the lines
//!    above it (up to the opening fence, after removing the common indentation)
//!    are exactly the chunk's text. This is the normal case and it is exact.
//! 2. **The same text, elsewhere** — a label built at runtime (`"gen-" + str(i)`)
//!    leaves the *text* in the source once and produces many chunks: they all map
//!    to the template they came from, which is where a reader would go and edit.
//! 3. **The label's literal prefix** — content assembled by code
//!    (`raw("print(" + str(i) + ")")`) exists nowhere in the source, but
//!    `#label("built-" + str(i))` still leaves `built-` behind, and that line is
//!    the generator: the honest place to point at.
//! 4. **Nowhere** — reported as generated, with the file it came from if we know
//!    it. No line is invented.
//!
//! Nothing here understands Typst: it strips indentation, compares lines, and
//! looks for `<label>` / `#label("label")` tokens. A parser would have to be
//! updated in lockstep with Typst; this never does.

// Wired into `tangle::plan()` in the next step (ADR D12); unit-tested here.
#![allow(dead_code)]

use std::path::{Path, PathBuf};

use crate::metadata::Event;

/// A file the documents were read from.
pub struct Source {
    pub path: PathBuf,
    pub text: String,
}

impl Source {
    pub fn load(path: &Path) -> std::io::Result<Self> {
        Ok(Self {
            path: path.to_path_buf(),
            text: std::fs::read_to_string(path)?,
        })
    }

    fn lines(&self) -> Vec<&str> {
        self.text.lines().collect()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Placed {
    /// A literal block: this file, this line of its opening fence.
    Exact { file: PathBuf, line: usize },
    /// The text was found, but not attached to this label (it was built at run
    /// time): all such chunks point at the same template.
    Template { file: PathBuf, line: usize },
    /// Only the label had a literal part; this is the generator that built it.
    Generated { file: PathBuf, line: usize },
    /// Nothing in the source corresponds to it.
    Nowhere,
}

impl Placed {
    pub fn position(&self) -> Option<(&Path, usize)> {
        match self {
            Placed::Exact { file, line }
            | Placed::Template { file, line }
            | Placed::Generated { file, line } => Some((file.as_path(), *line)),
            Placed::Nowhere => None,
        }
    }
}

/// Place every chunk of `chunks`, in document order.
///
/// Chunks are consumed in order, so a document that repeats a chunk text assigns
/// the occurrences left to right — the same order the document reads in.
pub fn chunks(sources: &[Source], chunks: &[Event]) -> Vec<Placed> {
    let mut anchors: Vec<(String, PathBuf, usize)> = Vec::new();
    for source in sources {
        anchors.extend(label_anchors(source));
    }

    let mut used_anchors: Vec<bool> = vec![false; anchors.len()];
    let mut placed = Vec::with_capacity(chunks.len());
    for event in chunks {
        let label = event.label().unwrap_or_default();
        let text = event.text();

        if let Some(position) = exact(sources, &anchors, &mut used_anchors, label, text) {
            placed.push(position);
            continue;
        }
        if let Some(position) = template(sources, text) {
            placed.push(position);
            continue;
        }
        if let Some(position) = generator(&anchors, label) {
            placed.push(position);
            continue;
        }
        placed.push(Placed::Nowhere);
    }
    placed
}

/// Every `<label>` or `#label("label")` token in a file, with its line.
fn label_anchors(source: &Source) -> Vec<(String, PathBuf, usize)> {
    let mut anchors = Vec::new();
    for (index, line) in source.lines().iter().enumerate() {
        for name in tokens_in(line) {
            anchors.push((name, source.path.clone(), index + 1));
        }
    }
    anchors
}

/// Labels written literally on one line. `#label("built-" + str(i))` yields
/// `built-`, the literal part, which is exactly what tier 3 needs.
fn tokens_in(line: &str) -> Vec<String> {
    let mut found = Vec::new();

    let mut rest = line;
    while let Some(start) = rest.find('<') {
        rest = &rest[start + 1..];
        let Some(end) = rest.find('>') else { break };
        let name = &rest[..end];
        if !name.is_empty()
            && name
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || "_.:-".contains(c))
        {
            found.push(name.to_string());
        }
        rest = &rest[end + 1..];
    }

    let mut rest = line;
    while let Some(start) = rest.find("label(\"") {
        rest = &rest[start + "label(\"".len()..];
        let Some(end) = rest.find('"') else { break };
        if !rest[..end].is_empty() {
            found.push(rest[..end].to_string());
        }
        rest = &rest[end + 1..];
    }

    found
}

/// Tier 1: an unused label anchor whose preceding block is this chunk.
fn exact(
    sources: &[Source],
    anchors: &[(String, PathBuf, usize)],
    used: &mut [bool],
    label: &str,
    text: &str,
) -> Option<Placed> {
    for (index, (name, file, line)) in anchors.iter().enumerate() {
        if used[index] || name != label {
            continue;
        }
        let source = sources.iter().find(|source| source.path == *file)?;
        if let Some(block) = block_above(source, *line)
            && dedent(&block.text) == text
        {
            used[index] = true;
            return Some(Placed::Exact {
                file: file.clone(),
                line: block.first_line,
            });
        }
    }
    None
}

/// Tier 2: the chunk's text, verbatim, somewhere in the sources.
fn template(sources: &[Source], text: &str) -> Option<Placed> {
    if text.is_empty() {
        return None;
    }
    let wanted: Vec<&str> = text.lines().collect();
    for source in sources {
        let lines = source.lines();
        for start in 0..lines.len() {
            let end = start + wanted.len();
            if end > lines.len() {
                break;
            }
            if dedent(
                &lines[start..end]
                    .iter()
                    .map(|line| line.to_string())
                    .collect::<Vec<_>>(),
            ) == text
            {
                return Some(Placed::Template {
                    file: source.path.clone(),
                    line: start + 1,
                });
            }
        }
    }
    None
}

/// Tier 3: the label's literal part, which is the code that built it.
///
/// A label like `built-0` was assembled from something; the longest literal
/// prefix that actually appears in the sources is what remains of the generator.
fn generator(anchors: &[(String, PathBuf, usize)], label: &str) -> Option<Placed> {
    let mut best: Option<&(String, PathBuf, usize)> = None;
    for anchor in anchors {
        if label.starts_with(anchor.0.as_str())
            && !anchor.0.is_empty()
            && best.is_none_or(|current| anchor.0.len() > current.0.len())
        {
            best = Some(anchor);
        }
    }
    best.map(|(_, file, line)| Placed::Generated {
        file: file.clone(),
        line: *line,
    })
}

struct Block {
    /// Lines of the block, in order.
    text: Vec<String>,
    /// 1-based line where the block starts.
    first_line: usize,
}

/// The fenced block whose label token is on `anchor_line`.
///
/// The label sits either on the closing fence (` ``` <name> `) or on the line
/// after it, so the closing fence is on the anchor line in the first case and
/// above it in the second.
fn block_above(source: &Source, anchor_line: usize) -> Option<Block> {
    let lines = source.lines();
    if anchor_line == 0 || anchor_line > lines.len() {
        return None;
    }
    let anchor = anchor_line - 1;
    let is_fence = |index: usize| lines[index].trim_start().starts_with("```");

    let mut end = anchor;
    if !is_fence(anchor) {
        end = (0..anchor).rev().find(|index| is_fence(*index))?;
    }
    let open = (0..end).rev().find(|index| is_fence(*index))?;

    Some(Block {
        text: lines[open + 1..end]
            .iter()
            .map(|line| line.to_string())
            .collect(),
        first_line: open + 1,
    })
}

/// Remove the indentation every non-blank line shares, the way Typst does when it
/// hands us the text of a block that was written inside a list or a quote.
fn dedent(lines: &[String]) -> String {
    let indent = lines
        .iter()
        .filter(|line| !line.trim().is_empty())
        .map(|line| line.len() - line.trim_start().len())
        .min()
        .unwrap_or(0);
    lines
        .iter()
        .map(|line| {
            if line.len() >= indent {
                &line[indent..]
            } else {
                line.as_str()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

#[cfg(test)]
mod tests {
    use super::{Placed, Source, chunks};
    use crate::metadata::Event;
    use std::path::PathBuf;

    fn event(label: &str, text: &str) -> Event {
        Event {
            kind: "chunk".into(),
            label: Some(label.into()),
            lang: Some("py".into()),
            text: Some(text.into()),
            level: None,
        }
    }

    fn source(text: &str) -> Source {
        Source {
            path: PathBuf::from("doc.typ"),
            text: text.into(),
        }
    }

    fn line_of(placed: &[Placed]) -> Vec<Option<usize>> {
        placed
            .iter()
            .map(|p| p.position().map(|(_, line)| line))
            .collect()
    }

    #[test]
    fn a_literal_block_is_found_exactly() {
        let source = source(
            "= Doc\n\n```py\nprint('one')\n``` <one>\n\n```py\nprint('two')\n``` #label(\"src/two.py\")\n",
        );
        let placed = chunks(
            &[source],
            &[
                event("one", "print('one')"),
                event("src/two.py", "print('two')"),
            ],
        );
        assert_eq!(line_of(&placed), vec![Some(3), Some(7)], "{placed:?}");
        assert!(matches!(placed[0], Placed::Exact { line: 3, .. }));
    }

    #[test]
    fn an_indented_block_in_a_list_is_found_too() {
        // Typst hands us the dedented text; the source has it indented.
        let source = source("1. step\n\n   ```py\n   print('indented')\n   ``` <in-list>\n");
        let placed = chunks(&[source], &[event("in-list", "print('indented')")]);
        assert_eq!(line_of(&placed), vec![Some(3)], "{placed:?}");
    }

    #[test]
    fn identical_texts_go_to_their_own_labels() {
        let source =
            source("```py\nprint('dup')\n``` <dup-a>\n\n```py\nprint('dup')\n``` <dup-b>\n");
        let placed = chunks(
            &[source],
            &[
                event("dup-a", "print('dup')"),
                event("dup-b", "print('dup')"),
            ],
        );
        assert_eq!(line_of(&placed), vec![Some(1), Some(5)], "{placed:?}");
    }

    #[test]
    fn a_label_built_at_runtime_points_at_the_template() {
        // <gen-i> exists in no source line; the text does.
        let source =
            source("#for i in range(3) [\n```py\nprint(#i)\n``` #label(\"gen-\" + str(i))\n]\n");
        let placed = chunks(
            &[source],
            &[event("gen-0", "print(#i)"), event("gen-1", "print(#i)")],
        );
        // Both come from the one template line that holds the text.
        assert_eq!(line_of(&placed), vec![Some(3), Some(3)], "{placed:?}");
    }

    #[test]
    fn content_assembled_by_code_points_at_its_generator() {
        // The text is nowhere (built by the loop); the label's literal part is.
        let source = source(
            "#for i in range(3) [\n  #raw(\"print(\" + str(i) + \")\", lang: \"py\", block: true) #label(\"built-\" + str(i))\n]\n",
        );
        let placed = chunks(&[source], &[event("built-0", "print(0)")]);
        assert_eq!(line_of(&placed), vec![Some(2)], "{placed:?}");
        assert!(matches!(placed[0], Placed::Generated { line: 2, .. }));
    }

    #[test]
    fn nothing_is_invented_when_the_source_says_nothing() {
        let source = source("= Doc\n");
        let placed = chunks(&[source], &[event("mystery", "print(1)")]);
        assert_eq!(placed, vec![Placed::Nowhere]);
    }
}
