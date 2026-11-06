// Path helpers for the glob package. Pure Goose. No C.
//
// Every function here reads byte slices. The results are views into the
// input, so a caller keeps them only as long as it keeps the input.

namespace glob;

import std;

// join2 writes "a/b" into out. Empty parts are skipped.
fn join2(out: u8[>..]&, a: u8[:], b: u8[:]) {
    join_into(out, a);
    if b.len == 0 { return; }
    if out.len > 0 { out.push('/'); }
    out.append(b);
}

// join3 writes "a/b/c" into out. Empty parts are skipped.
fn join3(out: u8[>..]&, a: u8[:], b: u8[:], c: u8[:]) {
    join2(out, a, b);
    if c.len == 0 { return; }
    if out.len > 0 { out.push('/'); }
    out.append(c);
}

// join writes every part into out, separated by '/'. Empty parts are skipped.
// The parts are a slice of slices, so a caller can pass any number of them.
fn join(out: u8[>..]&, parts: const u8[:][:]) {
    for part in parts {
        if part.len == 0 { continue; }
        if out.len > 0 { out.push('/'); }
        out.append(part);
    }
}

// join_into appends one part to out. It adds no separator.
fn join_into(out: u8[>..]&, part: u8[:]) {
    if part.len == 0 { return; }
    out.append(part);
}

// split returns the parts between the '/' separators. Empty parts are
// dropped. The parts are views into path.
fn split(path: u8[:]) -> const u8[:][>..] {
    var out: const u8[:][>..] = [];
    var start = 0;
    for i in 0..path.len {
        if path[i] == '/' {
            if i > start { out.push(path[start..i]); }
            start = i + 1;
        }
    }
    if start < path.len { out.push(path[start..]); }
    return out;
}

// basename returns the part after the last '/'. It returns the whole path
// when the path has no '/'. It returns "" for a path that ends with '/'.
fn basename(path: u8[:]) -> u8[:] {
    var end = path.len;
    while end > 0 && path[end - 1] == '/' { end -= 1; }
    if end == 0 { return path[..0]; }
    var i = end;
    while i > 0 {
        if path[i - 1] == '/' { return path[i..end]; }
        i -= 1;
    }
    return path[..end];
}

// dirname returns the part before the last '/'. It returns "" when the path
// has no '/'.
fn dirname(path: u8[:]) -> u8[:] {
    var end = path.len;
    while end > 0 && path[end - 1] == '/' { end -= 1; }
    var i = end;
    while i > 0 {
        if path[i - 1] == '/' { return path[..i - 1]; }
        i -= 1;
    }
    return path[..0];
}

// ext returns the extension of the last part of the path. The extension
// starts at the last '.' and includes it. It returns "" when there is none.
fn ext(path: u8[:]) -> u8[:] {
    let base = basename(path);
    var i = base.len;
    while i > 0 {
        i -= 1;
        if base[i] == '.' {
            // A leading dot is part of the name, not an extension.
            if i == 0 { return base[..0]; }
            return base[i..];
        }
    }
    return base[..0];
}

// normalize writes the lexical form of path into out. It resolves "." and
// "..". It keeps a leading "..".
fn normalize(out: u8[>..]&, path: u8[:]) {
    var parts: const u8[:][>..] = [];
    let segs = split(path);
    for seg in segs {
        if seg == "." { continue; }
        if seg == ".." {
            if parts.len > 0 && parts[parts.len - 1] != ".." {
                parts.pop();
                continue;
            }
            if path.len > 0 && path[0] == '/' { continue; }
        }
        parts.push(seg);
    }
    let absolute = path.len > 0 && path[0] == '/';
    if absolute { out.push('/'); }
    for i in 0..parts.len {
        if i > 0 { out.push('/'); }
        out.append(parts[i]);
    }
}
