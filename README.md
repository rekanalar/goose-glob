# goose-glob

Glob pattern matching and path tools for Goose.

## Features

- Pattern matching with `*`, `?`, `**`, character classes, and brace groups.
- Path helpers: `join`, `split`, `basename`, `dirname`, `ext`, `normalize`.
- Zero-copy. Functions read byte slices. They allocate only where the signature shows it.
- Pure Goose. No C code.

## Install

Put this line in the root file of your program:

```goose
import goose_glob from "rekanalar/goose-glob@v1";
```

## Example

```goose
import std;
import goose_glob from "rekanalar/goose-glob@v1";

fn main() {
    print(goose_glob::matches("src/main.goose", "**/*.goose"));   // true
    print(goose_glob::join("src", "", "main.goose"));             // src/main.goose
    return 0;
}
```

## License

MIT
