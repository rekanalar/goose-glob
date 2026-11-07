# goose-glob

[![ci](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-glob/actions/workflows/ci.yml)

Glob pattern matching and path tools for the [Goose](https://github.com/aardappel/goose) programming language.

## Features

- Pattern matching with `*`, `?`, `**`, character classes, and brace groups.
- A match of one name, as Python `fnmatch` has.
- A capture of the parts of a match, as Node `micromatch` has.
- Path helpers: `join`, `split`, `basename`, `dirname`, `ext`, `normalize`.
- A directory walk that filters the files by a pattern.
- Zero-copy. The functions read byte slices. They allocate only where the signature shows it.
- Pure Goose, with one small C file that detects symbolic links.

## Install

Put this line in the root file of your program:

```goose
import glob from "rekanalar/goose-glob@v1.2.0";
```

The CI runs the gate on Linux, macOS and Windows. It uses Goose v2026.4
and v2026.3 on each.

## Example

```goose
import std;
import glob from "rekanalar/goose-glob@v1.2.0";

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
| `match_name(name, pattern)` | true when the whole name matches the pattern |
| `capture(out, text, pattern)` | the parts of the match, and their count. It gives -1 when the text does not match. |
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
| `matches_fold(path, pattern)` | `matches` with no difference between the cases of Unicode letters |
| `matches_any(path, patterns)` | true when one line of the list matches |
| `matches_set(path, patterns)` | the list with `!` lines that remove paths. The last match decides. |

The paths in the result of `walk` are relative to `dir`. They use `/` as the separator.

## Match one name

`match_name(name, pattern)` tests one name against one pattern. The rule is the rule of Python `fnmatch.fnmatchcase`.

- The whole name is one piece. A separator is an ordinary byte.
- A star matches any bytes, so it matches a separator.
- A question mark matches one byte, so it matches a separator.
- A class of characters matches one byte.
- A group of alternatives matches either alternative.
- A backslash gives the next byte as a literal.
- A malformed pattern is a literal.

The function has no case folding. Use `matches_fold` for that.

```goose
print(glob::match_name("notes.txt", "*.txt"));       // true
print(glob::match_name("dir/notes.txt", "*.txt"));   // true
print(glob::match_name("notes.md", "*.txt"));        // false
```

## Capture the parts of a match

`capture(out, text, pattern)` gives the parts of a match into `out`. The parts are separated by a newline byte. The function gives the count of the parts. It gives -1 when the text does not match.

- One part for each star, each class and each group of alternatives.
- The parts come in the order of the pattern.
- A star that matched the empty text gives an empty part.
- A question mark gives no part.
- A class gives the byte that it matched.
- A group of alternatives gives the text of the alternative that matched.
- A star takes the shortest text that still lets the rest match.

The rule of the match is the rule of `matches`. A part comes only for a text that `matches` also accepts.

```goose
var out: u8[>..] = [];
print(glob::capture(out, "axbyc", "a*b*c"));   // 2
print(out);                                    // x
                                               // y
```

## Limits

A pattern may come from a program that takes input from a user. The limits
below keep a pattern from exhausting the machine.

- A pattern with more than 4096 alternatives is not expanded. It stays one pattern.
- A capture with more than 1000000 entries in all its tables gives -1. The sum of the tables counts. A pattern with many alternatives and a long path gives -1 too.
- A capture whose expansion holds more than 4000000 bytes gives -1. The expansion holds the text of every alternative.
- The time of a match grows with the size of the path and the pattern. It never repeats work.
- `walk` follows no symbolic link to a directory. It reports a link to a file as a file.
- `walk_with` uses three kinds. `d` is a directory. `l` is a link to a directory. `f` is any other file.
- `matches_fold` uses the simple case fold of Unicode 16, from Python 3.14. The full fold is out, so `ß` does not match `SS`.
- A `?` and a class take one code point. A byte that is not valid UTF-8 counts as one item.
- The test of the loop guard needs a symbolic link. Windows checks the fixture out as a plain file, so the guard has no test there.
- The capture follows the rules of matching of this package, and not the rules of `micromatch`. A star of the segments gives the text of the segments that it took. `micromatch` gives a different text for a path that starts with a separator.
- The parts of a capture are separated by a newline byte. A part that holds a newline byte looks like a separator.

## Test

```bash
goose run test/run.goose
goose run examples/list.goose
goose run examples/name.goose
```

## License

MIT
