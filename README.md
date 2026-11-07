# goose-glob

[![ci](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml)

Glob pattern matching and path tools for the [Goose](https://github.com/aardappel/goose) programming language.

## Features

- Pattern matching with `*`, `?`, `**`, character classes, and brace groups.
- Path helpers: `join`, `split`, `basename`, `dirname`, `ext`, `normalize`.
- A directory walk that filters the files by a pattern.
- Zero-copy. The functions read byte slices. They allocate only where the signature shows it.
- Pure Goose, with one small C file that detects symbolic links.

## Install

Put this line in the root file of your program:

```goose
import glob from "rekanalar/goose-glob@v0.1.1";
```

## Example

```goose
import std;
import glob from "rekanalar/goose-glob@v0.1.1";

fn main() {
    print(glob::matches("src/main.goose", "**/*.goose"));   // true
    var out: u8[>..] = [];
    glob::join2(out, "src", "main.goose");
    print(out);                                             // src/main.goose
    return 0;
}
```

## Pattern syntax

| Pattern | Matches |
|---|---|
| `*` | any bytes in one segment |
| `**` | any number of segments, when it is a whole segment |
| `?` | one byte |
| `[abc]` | one byte from the set |
| `[a-c]` | one byte from the range |
| `[!abc]` | one byte that is not in the set |
| `{a,b}` | either alternative. The groups may nest. |
| `\x` | the byte x, as a literal |

The matcher reads bytes. The set `[a-c]` is a byte range.

## Functions

| Function | Result |
|---|---|
| `matches(path, pattern)` | true when the whole path matches the pattern |
| `join(out, parts)` | the parts, separated by `/` |
| `join2(out, a, b)` | "a/b" |
| `join3(out, a, b, c)` | "a/b/c" |
| `split(path)` | the parts between the separators |
| `basename(path)` | the part after the last `/` |
| `dirname(path)` | the part before the last `/` |
| `ext(path)` | the extension, with its dot |
| `normalize(out, path)` | the lexical form of the path |
| `walk(out, dir, pattern)` | the paths under dir that match the pattern |
| `walk_with(out, dir, pattern, opts)` | like `walk`. Option 1 enters hidden names. Option 2 puts a kind and a tab before each path. |
| `matches_fold(path, pattern)` | `matches` with no difference between the cases of ASCII letters |
| `matches_any(path, patterns)` | true when one line of the list matches |
| `matches_set(path, patterns)` | the list with `!` lines that remove paths. The last match decides. |

The paths in the result of `walk` are relative to `dir`. They use `/` as the separator.

## Limits

A pattern may come from a program that takes input from a user. Two limits
keep a pattern from exhausting the machine.

- A pattern with more than 4096 alternatives is not expanded. It stays one pattern.
- The time of a match grows with the size of the path and the pattern. It never repeats work.
- `walk` follows no symbolic link to a directory. It reports a link to a file as a file.
- `walk_with` uses three kinds. `d` is a directory. `l` is a link to a directory. `f` is any other file.
- The case fold covers ASCII letters only.
- There is no match for one name that lets `*` cross a separator, as Python `fnmatch` has.
- There is no `capture` of the parts that a pattern matched.

## Test

```bash
goose run test/run.goose
goose run examples/list.goose
```

## License

MIT
