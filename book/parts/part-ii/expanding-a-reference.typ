#import "../../package/lib.typ": chunk

= Expanding a reference

The expansion is the whole algorithm, and it is small: a line is a reference to be replaced, an escape to
be written out with its `@` removed, or text to be kept as it stands. This chapter is the two predicates
that decide which of the three, what an expansion produces while it runs, and the ways expanding a root can
fail.

== What a reference is

This predicate is the whole syntax of references: a line whose trimmed text starts with
`<<` and ends with `>>` around a non-empty name that contains no angle brackets. Anything
else is literal, which is what keeps `a << b` and `assert_eq!(x, "<<y>>")` out of trouble.

#chunk("tangle: what counts as a reference", ````rust
fn ref_target(line: &str) -> Option<(&str, &str)> {
    let trimmed = line.trim();
    let inner = trimmed.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some((inner, &line[..line.len() - line.trim_start().len()]))
}
````)

== And how to write one without it being one

`@<<name>>` stays literal, and it is not a reference for the purposes of the unused-fragment warning either
(D17). The pattern that recognises the escape, and the reason this document needed one, are in the chapter that
declares the package.

#chunk("tangle: how to write one without it being one", ````rust
fn escaped_ref(line: &str) -> Option<String> {
    let indent = &line[..line.len() - line.trim_start().len()];
    let rest = line.trim().strip_prefix('@')?;
    let inner = rest.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some(format!("{indent}<<{inner}>>"))
}
````)

== What an expansion produces

The result of expanding a root is text and a list of runs. Keeping the runs here, rather
than deriving them later, is the reason provenance costs nothing: the line numbers are
known at the moment the line is written.

#chunk("tangle: what comes out of an expansion", ````rust
pub struct Tangled {
    pub text: String,
    pub runs: Vec<Run>,
    lines: usize,
}
````)

#chunk("tangle: one line, with its indentation", ````rust
fn push(&mut self, chunk: &str, indent: &str, line: &str) {
    if !line.trim().is_empty() {
        self.text.push_str(indent);
        self.text.push_str(line);
    }
    self.text.push('\n');
    self.lines += 1;
    match self.runs.last_mut() {
        Some(run) if run.chunk == chunk && run.last + 1 == self.lines => run.last = self.lines,
        _ => self.runs.push(Run {
            chunk: chunk.to_string(),
            first: self.lines,
            last: self.lines,
        }),
    }
}
````)

== Expanding a root, and the three ways it can fail

Three fragments: the entry point, the cycle check that turns a loop into a named chain, and the
inner loop that does the substitution.

#chunk("tangle: expanding a root", ````rust
pub fn expand(set: &ChunkSet, root: &str) -> Result<Tangled, EtchError> {
    let mut out = Tangled {
        text: String::new(),
        runs: Vec::new(),
        lines: 0,
    };
    let mut stack = Vec::new();
    expand_chunk(set, root, "", &mut stack, &mut out)?;
    Ok(out)
}
````)

The recursion carries the indentation of the reference that pulled each chunk in, and a
stack of the names currently being expanded so that a cycle can be reported as the chain it
is. The stack is what makes the error message useful — "a -> b -> a" says where to look,
"cycle detected" does not.

Two consequences of that rule are worth knowing before writing a chunk. A fragment must not
contain the brace that closes the frame it is referenced in, because the indentation would move
it; and a fence has to be longer than the longest run of backticks inside the text it wraps
(which is why some blocks in this document open with five).

#chunk("tangle: a cycle, named", ````rust
if let Some(start) = stack.iter().position(|entry| entry == name) {
    let mut chain: Vec<String> = stack[start..].to_vec();
    chain.push(name.to_string());
    let message = format!("cycle in chunks: {}", chain.join(" -> "));
    let block = set.get(name).and_then(|blocks| blocks.first()).copied();
    return Err(match block {
        Some(block) => block.error(0, message),
        None => EtchError::plain(message),
    });
}
````)

#chunk("tangle: an empty chunk", ````rust
if block.text.trim().is_empty() {
    stack.pop();
    return Err(EtchError::plain(format!("chunk ⟪{name}⟫ is empty"))
        .with_help("delete the declaration, or give it a code block with a body"));
}
````)

The inner loop is the mechanism, and it is four lines of decision: an escaped reference is
written out with the `@` removed, an ordinary reference is looked up (missing names are an
error that lists what does exist) and expanded with the combined indentation, and anything
else is written as it stands.

#chunk("tangle: one line at a time", ````rust
for (index, line) in block.text.lines().enumerate() {
    if let Some(literal) = escaped_ref(line) {
        out.push(name, indent, &literal);
        continue;
    }
    match ref_target(line) {
        None => out.push(name, indent, line),
        Some((target, local_indent)) => {
            if set.get(target).is_none() {
                return Err(block
                    .error(index, format!("chunk ⟪{target}⟫ is not defined"))
                    .with_help(format!(
                        "referenced from ⟪{name}⟫; known chunks: {}",
                        set.names().collect::<Vec<_>>().join(", ")
                    )));
            }
            let nested = format!("{indent}{local_indent}");
            expand_chunk(set, target, &nested, stack, out)?;
        }
    }
}
````)
