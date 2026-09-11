//! Where a declaration was written.
//!
//! Typst reports which chunks exist but not where, and it never will: elements
//! carry no source positions. So the declaration is its own anchor — `lp` looks
//! for the exact text the author wrote, `#file("src/main.rs"` or
//! `#chunk("imports"` — and counts lines from there. That is a lookup of a token
//! we defined, not a heuristic search of Typst's syntax: nothing here knows how a
//! code fence looks, because the code is not read from the source at all (the
//! declaration carries it).
//!
//! Two shapes are handled:
//!
//! * the declaration is written literally, so the line is exact;
//! * the name was built at run time (`#chunk("part-" + str(i), …)`), in which case
//!   the longest literal prefix is what remains in the source — the loop that
//!   built it, which is exactly where a reader would go and change something.
//!
//! Anything else is reported as having no line rather than given a plausible one.

use std::sync::Arc;

use crate::metadata::Decl;
use crate::source::FileText;

#[derive(Debug, Clone)]
pub enum Placed {
    /// The declaration was written here; `line` is the first line of its code.
    Exact { file: Arc<FileText>, line: usize },
    /// Only a literal prefix of the name was written here: this is the code that
    /// built the chunk.
    Generated { file: Arc<FileText>, line: usize },
    /// Nothing in the sources corresponds to it.
    Nowhere,
}

impl Placed {
    /// The source line for the `index`-th line of this chunk (0-based), if any.
    ///
    /// A generated chunk points every line at the code that built it, which is
    /// where a change has to happen.
    pub fn line_for(&self, index: usize) -> Option<(&Arc<FileText>, usize)> {
        match self {
            Placed::Exact { file, line } => Some((file, line + index)),
            Placed::Generated { file, line } => Some((file, *line)),
            Placed::Nowhere => None,
        }
    }
}

/// Place every declaration, in the order the document produced them.
pub fn places(sources: &[Arc<FileText>], declarations: &[Decl]) -> Vec<Placed> {
    let mut taken: Vec<(Arc<FileText>, usize)> = Vec::new();
    let mut placed = Vec::with_capacity(declarations.len());

    for declaration in declarations {
        let exact = tokens(declaration)
            .iter()
            .filter_map(|token| {
                occurrences(sources, token).into_iter().find(|candidate| {
                    !taken
                        .iter()
                        .any(|used| used.0.path == candidate.0.path && used.1 == candidate.1)
                })
            })
            .next();
        if let Some((file, line, starts_here)) = exact {
            taken.push((Arc::clone(&file), line));
            // The code begins on the same line as the call when the author wrote
            // it there (`#file("x", ```py print(1)```)`), otherwise one line down.
            placed.push(Placed::Exact {
                file,
                line: if starts_here { line } else { line + 1 },
            });
            continue;
        }

        placed.push(
            prefix(declaration, sources).map_or(Placed::Nowhere, |(file, line)| {
                Placed::Generated { file, line }
            }),
        );
    }
    placed
}

/// The exact call shapes an author may have written for this declaration.
fn tokens(declaration: &Decl) -> Vec<String> {
    let call = if declaration.is_file() {
        "file"
    } else {
        "chunk"
    };
    let name = &declaration.name;
    vec![
        format!("#{call}(\"{name}\""),
        format!("#lp.{call}(\"{name}\""),
        format!("#pkg.{call}(\"{name}\""),
        format!("#{call}('{name}'"),
    ]
}

/// The longest literal prefix of the name that appears as a declaration: the code
/// that built it.
fn prefix(declaration: &Decl, sources: &[Arc<FileText>]) -> Option<(Arc<FileText>, usize)> {
    let call = if declaration.is_file() {
        "file"
    } else {
        "chunk"
    };
    let name = declaration.name.as_str();
    let mut best = None;
    for end in (1..name.len()).rev() {
        if !name.is_char_boundary(end) {
            continue;
        }
        let token = format!("#{call}(\"{}", &name[..end]);
        if let Some((file, line, _)) = occurrences(sources, &token).into_iter().next() {
            best = Some((file, line));
            break;
        }
    }
    best
}

/// Every place `token` occurs, in file order and then in document order, with the
/// line it is on and whether the code starts on that same line.
fn occurrences(sources: &[Arc<FileText>], token: &str) -> Vec<(Arc<FileText>, usize, bool)> {
    let mut found = Vec::new();
    for source in sources {
        for (at, _) in source.text.match_indices(token) {
            let line = source.text[..at].matches('\n').count() + 1;
            let rest = &source.text[at..];
            let same_line = rest.split('\n').next().unwrap_or(rest);
            // If a fence follows on the same line and there is text after its
            // language tag, the code starts here rather than one line down.
            let starts_here = same_line.split_once("```").is_some_and(|(_, after)| {
                let after = after.trim_start_matches('`');
                let code = after
                    .trim_start_matches(|c: char| c.is_ascii_alphanumeric() || "+-._".contains(c));
                !code.trim().is_empty()
            });
            found.push((Arc::clone(source), line, starts_here));
        }
    }
    found
}

#[cfg(test)]
mod tests {
    use super::{Placed, places};
    use crate::metadata::Decl;
    use crate::source::FileText;
    use miette::NamedSource;
    use std::sync::Arc;

    fn source(text: &str) -> Arc<FileText> {
        Arc::new(FileText {
            path: "doc.typ".into(),
            named: NamedSource::new("doc.typ", text.to_string()),
            text: text.into(),
        })
    }

    fn chunk(name: &str, text: &str) -> Decl {
        Decl {
            lp: "chunk".into(),
            name: name.into(),
            lang: Some("py".into()),
            text: text.into(),
        }
    }

    fn file(path: &str, text: &str) -> Decl {
        Decl {
            lp: "file".into(),
            name: path.into(),
            lang: Some("py".into()),
            text: text.into(),
        }
    }

    fn line_of(placed: &[Placed]) -> Vec<Option<usize>> {
        placed
            .iter()
            .map(|place| place.line_for(0).map(|(_, line)| line))
            .collect()
    }

    #[test]
    fn a_declaration_is_its_own_anchor() {
        let source = source(
            "#import \"lp.typ\": chunk, file\n\
             = Doc\n\
             \n\
             #file(\"src/main.py\", ```py\n\
             print('one')\n\
             ```)\n\
             \n\
             #chunk(\"body\", ```py\n\
             print('two')\n\
             ```)\n",
        );
        let placed = places(
            &[source],
            &[
                file("src/main.py", "print('one')"),
                chunk("body", "print('two')"),
            ],
        );
        // The code starts one line below the declaration.
        assert_eq!(line_of(&placed), vec![Some(5), Some(9)], "{placed:?}");
        assert!(matches!(placed[0], Placed::Exact { line: 5, .. }));
    }

    #[test]
    fn code_on_the_declaration_line_starts_here() {
        let source = source("#chunk(\"inline\", ```py print(1)```)\n");
        let placed = places(&[source], &[chunk("inline", "print(1)")]);
        assert_eq!(line_of(&placed), vec![Some(1)], "{placed:?}");
    }

    #[test]
    fn repeated_names_are_taken_left_to_right() {
        let source = source(
            "#chunk(\"body\", ```py\n\
             print('a')\n\
             ```)\n\
             \n\
             #chunk(\"body\", ```py\n\
             print('b')\n\
             ```)\n",
        );
        let placed = places(
            &[source],
            &[chunk("body", "print('a')"), chunk("body", "print('b')")],
        );
        assert_eq!(line_of(&placed), vec![Some(2), Some(6)], "{placed:?}");
    }

    #[test]
    fn a_name_built_at_runtime_points_at_its_loop() {
        let source = source(
            "#for i in range(2) [\n  #chunk(\"part-\" + str(i), ```py\n  print(i)\n  ```)\n]\n",
        );
        let placed = places(
            &[source],
            &[chunk("part-0", "print(i)"), chunk("part-1", "print(i)")],
        );
        assert_eq!(line_of(&placed), vec![Some(2), Some(2)], "{placed:?}");
        assert!(matches!(placed[0], Placed::Generated { line: 2, .. }));
    }

    #[test]
    fn nothing_is_invented_when_the_source_says_nothing() {
        let source = source("= Doc\n");
        let placed = places(&[source], &[chunk("mystery", "print(1)")]);
        assert!(matches!(placed.as_slice(), [Placed::Nowhere]));
    }
}
