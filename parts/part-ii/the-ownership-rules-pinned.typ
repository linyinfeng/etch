#import "../../package/lib.typ": chunk

= The ownership rules, pinned in the file

Five unit tests, and they live in the file they test rather than in `tests/`, because they are about one
function and need no binary. What they pin is the shape of the rule rather than its use: depth on both sides of
the accounting line, a subtree that overflows named once at the directory that overflows, and no accounting by
name at all — a `.lpignore` that neither the document declared nor a rule protects is still a stray, while the
two names the tool writes are not.

#chunk("status: the rules, pinned by five cases", ````rust
#[cfg(test)]
mod tests {
    use super::unaccounted;
    use std::collections::{BTreeMap, BTreeSet};
    use std::fs;
    use tempfile::TempDir;

    fn write(path: &std::path::Path, contents: &str) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, contents).unwrap();
    }

    fn names(dir: &str, list: &[&str]) -> (String, BTreeSet<String>) {
        (
            dir.to_string(),
            list.iter().map(|name| name.to_string()).collect(),
        )
    }

    #[test]
    fn only_files_nothing_accounts_for_are_reported() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "declared.txt\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("declared.txt"), "mine, not lp's");
        write(&out.join("stray.txt"), "who put this here");
        write(&out.join("stray-dir/inside.txt"), "and this");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".lpignore"])]
                .into_iter()
                .collect();
        let found = unaccounted(out, &produced).unwrap();

        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        let mut listed = listed;
        listed.sort();
        assert_eq!(
            listed,
            vec!["stray-dir/inside.txt".to_string(), "stray.txt".to_string()]
        );
    }

    #[test]
    fn a_directory_holding_only_declared_files_is_accounted_for() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "**/*.log\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("deep/nested/app.log"), "declared");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt", ".lpignore"])]
                .into_iter()
                .collect();
        assert!(unaccounted(out, &produced).unwrap().is_empty());
    }

    #[test]
    fn a_large_unaccounted_subtree_is_named_once() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("produced.txt"), "chunk output");
        for i in 0..20 {
            write(&out.join(format!("vendor/nested/file{i}.txt")), "x");
        }

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].dir, "vendor");
        assert_eq!(
            found[0].entries,
            vec!["nested/".to_string()],
            "one line, not twenty — the directory that actually overflows"
        );
    }

    #[test]
    fn the_output_directory_is_ours_all_the_way_down() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("src/produced.rs"), "chunk output");
        write(&out.join("src/next-to-it.rs"), "stray");
        write(&out.join("elsewhere/deep/a.txt"), "x");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("src", &["produced.rs"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        assert_eq!(
            listed,
            vec![
                "elsewhere/deep/a.txt".to_string(),
                "src/next-to-it.rs".to_string()
            ],
            "anything under the output directory, at any depth"
        );
    }

    #[test]
    fn the_ignore_file_is_not_exempt_and_the_tools_own_output_is() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "theirs.txt\n");
        write(&out.join("theirs.txt"), "protected");
        write(&out.join(".lp/package/lib.typ"), "the package");
        write(&out.join("src/.lpmap.json"), "the map");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["theirs.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        assert_eq!(
            listed,
            vec![".lpignore".to_string()],
            "the ignore file is reported; the tool's own two names are not"
        );
    }
}
````)
