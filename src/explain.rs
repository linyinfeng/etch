use std::path::Path;

use regex::Regex;

use crate::diag::EtchError;
use crate::map::{EtchMap, join, resolve_all};

pub fn run(out: &Path, input: &str) -> Result<usize, EtchError> {
    let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
        .map_err(|err| EtchError::plain(format!("internal: bad diagnostic pattern: {err}")))?;

    let maps = EtchMap::read_all(out);
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        let Some(caps) = pattern.captures(line) else {
            continue;
        };
        let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
        let Ok((dir, name, entry)) = resolve_all(&maps, file) else {
            continue;
        };
        let Some((run, offset)) = entry.locate(out_line) else {
            continue;
        };
        let rel = join(dir, name);
        println!(
            "  ↳ chunk ⟪{}⟫, line {offset} of it  ({rel}:{out_line})",
            run.chunk
        );
        mapped += 1;
    }

    Ok(mapped)
}
