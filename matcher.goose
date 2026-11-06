// The glob matcher for the glob package. Pure Goose. No C.
//
// The matcher compares a path with a pattern. Both are byte slices. It
// never copies them. The matcher never errors: a malformed pattern is
// treated as a literal.
//
// Pattern syntax:
//
//   *        matches any bytes in one segment
//   **       matches any number of segments, when it is a whole segment
//   ?        matches one byte in one segment
//   [abc]    matches one byte from the set
//   [a-c]    matches one byte from the range
//   [!abc]   matches one byte that is not in the set
//   {a,b}    matches either alternative. Groups may nest.
//   \x       the byte x, as a literal
//
// The matcher works in three steps.
//
// First it expands the brace groups. It writes each alternative into a
// list of patterns. The expansion runs in rounds. Each round takes the
// first group of every pattern and replaces it with its alternatives.
//
// Second it splits the path and the pattern into segments. A segment is
// the part between two separators.
//
// Third it matches the segment lists. A "**" segment matches any number of
// segments. A normal segment matches one segment.

namespace glob;

import std;

// matches returns true when the whole path matches the whole pattern.
fn matches(path: u8[:], pattern: u8[:]) -> bool {
    let variants = expand(pattern);
    let path_parts = split_segments(path);
    var start = 0;
    var i = 0;
    while i < variants.len {
        if variants[i] == 0 {
            let v = variants[start..i];
            let v_parts = split_segments(v);
            if match_segments(path_parts, v_parts, 0, 0) { return true; }
            start = i + 1;
        }
        i += 1;
    }
    return false;
}

// expand writes every alternative of the pattern into a list. The
// alternatives are separated by a zero byte. A pattern without a group
// gives one alternative: the pattern itself.
fn expand(pattern: u8[:]) -> u8[>..] {
    var work: u8[>..] = [];
    var next: u8[>..] = [];
    var out: u8[>..] = [];
    work.append(pattern);
    work.push(0);
    var round = 0;
    loop {
        let pending = if round % 2 == 0 {
            expand_round(work, next, out)
        } else {
            expand_round(next, work, out)
        };
        if !pending { break; }
        round += 1;
    }
    return out;
}

// expand_round takes every pattern in work and expands its first group
// into the next list. A pattern without a group goes to the out list. It
// returns true when some pattern had a group.
fn expand_round(work: u8[>..]&, next: u8[>..]&, out: u8[>..]&) -> bool {
    next.clear();
    var pending = false;
    var i = 0;
    while i < work.len {
        var j = i;
        while j < work.len && work[j] != 0 { j += 1; }
        let v = work[i..j];
        let g = find_group(v);
        if g < 0 {
            out.append(v);
            out.push(0);
        } else {
            let close = find_close(v, g);
            if close < 0 {
                // A group that is not closed is a literal.
                out.append(v);
                out.push(0);
            } else {
                // The alternatives are the parts between the commas.
                var start = g + 1;
                var k = g + 1;
                while k < close {
                    let c = v[k];
                    if c == '[' {
                        k = skip_class(v, k);
                        continue;
                    }
                    if c == '\\' {
                        k += 2;
                        continue;
                    }
                    if c == '{' {
                        let inner = find_close(v, k);
                        k += if inner < 0 { 1 } else { inner + 1 };
                        continue;
                    }
                    if c == ',' {
                        add_variant(next, v[..g], v[start..k], v[close + 1..]);
                        start = k + 1;
                    }
                    k += 1;
                }
                add_variant(next, v[..g], v[start..close], v[close + 1..]);
                pending = true;
            }
        }
        i = j + 1;
    }
    return pending;
}

// add_variant writes one alternative into the list. The alternative is the
// prefix, then the body, then the suffix.
fn add_variant(out: u8[>..]&, prefix: u8[:], body: u8[:], suffix: u8[:]) {
    out.append(prefix);
    out.append(body);
    out.append(suffix);
    out.push(0);
}

// find_group returns the index of the first '{' that is not in a class and
// not escaped. It returns -1 when there is none.
fn find_group(v: u8[:]) -> i64 {
    var i = 0;
    while i < v.len {
        let c = v[i];
        if c == '[' {
            i = skip_class(v, i);
            continue;
        }
        if c == '\\' {
            i += 2;
            continue;
        }
        if c == '{' { return i; }
        i += 1;
    }
    return -1;
}

// find_close returns the index of the '}' that closes the group at open.
// It returns -1 when the group is not closed.
fn find_close(v: u8[:], open: i64) -> i64 {
    var depth = 0;
    var i = open;
    while i < v.len {
        let c = v[i];
        if c == '[' {
            i = skip_class(v, i);
            continue;
        }
        if c == '\\' {
            i += 2;
            continue;
        }
        if c == '{' { depth += 1; }
        if c == '}' {
            depth -= 1;
            if depth == 0 { return i; }
        }
        i += 1;
    }
    return -1;
}

// skip_class returns the index after the ']' that closes the class at open.
// An unclosed class ends at the end of the pattern.
fn skip_class(v: u8[:], open: i64) -> i64 {
    var i = open + 1;
    if i < v.len && (v[i] == '!' || v[i] == '^') { i += 1; }
    if i < v.len && v[i] == ']' { i += 1; }
    while i < v.len {
        if v[i] == ']' { return i + 1; }
        i += 1;
    }
    return v.len;
}

// split_segments returns the parts of s between the separators. Empty
// parts are dropped. An empty input gives one empty segment, so a '*'
// can match it.
fn split_segments(s: u8[:]) -> const u8[:][>..] {
    var out: const u8[:][>..] = [];
    var start = 0;
    var i = 0;
    while i < s.len {
        if s[i] == '/' {
            if i > start { out.push(s[start..i]); }
            start = i + 1;
        }
        i += 1;
    }
    if start < s.len { out.push(s[start..]); }
    if out.len == 0 { out.push(s[..0]); }
    return out;
}

// match_segments matches the path segments against the pattern segments.
// It returns true when the rest of both lists match.
recursive fn match_segments(path: const u8[:][>..]&, pat: const u8[:][>..]&, pi: i64, si: i64) -> bool {
    if pi >= pat.len { return si >= path.len; }
    // A "**" segment matches any number of segments.
    if pat[pi] == "**" {
        var k = si;
        while k <= path.len {
            if match_segments(path, pat, pi + 1, k) { return true; }
            k += 1;
        }
        return false;
    }
    if si >= path.len { return false; }
    if !match_segment(path[si], pat[pi]) { return false; }
    return match_segments(path, pat, pi + 1, si + 1);
}

// match_segment matches one path segment against one pattern segment. The
// segment holds no separator, so a '*' in it matches any bytes.
recursive fn match_segment(path: u8[:], pat: u8[:]) -> bool {
    return match_seg(path, 0, pat, 0);
}

// match_seg matches the path from p against the pattern from s. It backs
// up over a '*' when the rest does not match.
recursive fn match_seg(path: u8[:], p: i64, pat: u8[:], s: i64) -> bool {
    if s >= pat.len { return p >= path.len; }
    let c = pat[s];
    if c == '*' {
        // The star matches no bytes, then one byte more each time.
        if match_seg(path, p, pat, s + 1) { return true; }
        if p < path.len { return match_seg(path, p + 1, pat, s); }
        return false;
    }
    if c == '?' {
        if p >= path.len { return false; }
        return match_seg(path, p + 1, pat, s + 1);
    }
    if c == '[' {
        let after = class_end(pat, s);
        if after == 0 {
            // An unterminated class is a literal.
            if p >= path.len || path[p] != '[' { return false; }
            return match_seg(path, p + 1, pat, s + 1);
        }
        if p >= path.len { return false; }
        if !class_has(pat, s, after, path[p]) { return false; }
        return match_seg(path, p + 1, pat, after);
    }
    if c == '\\' && s + 1 < pat.len {
        if p >= path.len || path[p] != pat[s + 1] { return false; }
        return match_seg(path, p + 1, pat, s + 2);
    }
    if p >= path.len || path[p] != c { return false; }
    return match_seg(path, p + 1, pat, s + 1);
}

// class_end returns the index after the class that starts at pos. It
// returns 0 when the class is not closed.
fn class_end(pat: u8[:], pos: i64) -> i64 {
    let end = skip_class(pat, pos);
    if end > pat.len || end <= pos + 1 || pat[end - 1] != ']' { return 0; }
    return end;
}

// class_has returns true when the byte c is in the class that starts at
// pos and ends at end.
fn class_has(pat: u8[:], pos: i64, end: i64, c: u8) -> bool {
    let body = pat[pos + 1..end - 1];
    if body.len == 0 { return false; }
    var negate = false;
    var i = 0;
    if body[0] == '!' || body[0] == '^' {
        negate = true;
        i = 1;
    }
    var found = false;
    while i < body.len {
        if i + 2 < body.len && body[i + 1] == '-' {
            if c >= body[i] && c <= body[i + 2] { found = true; }
            i += 3;
            continue;
        }
        if body[i] == c { found = true; }
        i += 1;
    }
    if negate { found = !found; }
    return found;
}
