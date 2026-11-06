# goose-glob

[![ci](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml)

Glob pattern matching and path tools for the Goose programming language.

## Features

- Pattern matching with `*`, `?`, `**`, character classes, and brace groups.
- Path helpers: `join`, `split`, `basename`, `dirname`, `ext`, `normalize`.
- A directory walk that filters the files by a pattern.
- Zero-copy. The functions read byte slices. They allocate only where the signature shows it.
- Pure Goose. No C code.

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

The paths in the result of `walk` are relative to `dir`. They use `/` as the separator.

## Limits

A pattern may come from a program that takes input from a user. Two limits
keep a pattern from exhausting the machine.

- A pattern with more than 4096 alternatives is not expanded. It stays one pattern.
- The time of a match grows with the size of the path and the pattern. It never repeats work.

## Test

```bash
goose run test/run.goose
goose run examples/list.goose
```

## License

MIT
