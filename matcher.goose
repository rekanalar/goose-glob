// The glob matcher for the glob package.
//
// The matcher compares a path with a pattern. Both are byte slices. It
// never copies them.
//
// A malformed pattern is a literal. The matcher never fails.
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
// First it expands the brace groups. Each round takes the first group of
// every pattern. It replaces the group with its alternatives.
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
            // The table marks the pairs of positions that failed. A pair
            // fails once, so the work has a bound.
            var failed: bool[>..] = [];
            for f in 0..(v_parts.len + 1) * (path_parts.len + 1) { failed.push(false); }
            if match_segments(path_parts, v_parts, 0, 0, failed) { return true; }
            start = i + 1;
        }
        i += 1;
    }
    return false;
}

// The most alternatives a pattern may give. A pattern with more gives a
// literal. The limit keeps a pattern from a program that takes input from
// a user from exhausting the memory of the machine.
const MAX_VARIANTS = 4096;

// expand writes every alternative of the pattern into a list. The
// alternatives are separated by a zero byte. A pattern without a group
// gives one alternative: the pattern itself.
//
// A pattern with too many alternatives is not expanded. It stays one
// pattern, and its braces are literal.
fn expand(pattern: u8[:]) -> u8[>..] {
    if variant_count(pattern, MAX_VARIANTS) > MAX_VARIANTS {
        var one: u8[>..] = [];
        one.append(pattern);
        one.push(0);
        return one;
    }
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
                var alst: i64[>..] = [];
                var ale: i64[>..] = [];
                split_alts(v, g, close, alst, ale);
                for k in 0..alst.len {
                    add_variant(next, v[..g], v[alst[k]..ale[k]], v[close + 1..]);
                }
                pending = true;
            }
        }
        i = j + 1;
    }
    return pending;
}

// variant_count returns the number of patterns the brace groups of the
// pattern give. It stops at the limit, so a count above the limit comes
// back as the limit plus one.
recursive fn variant_count(pattern: u8[:], limit: i64) -> i64 {
    var total = 1;
    var i = 0;
    while i < pattern.len {
        let c = pattern[i];
        if c == '[' {
            i = skip_class(pattern, i);
            continue;
        }
        if c == '\\' {
            i += 2;
            continue;
        }
        if c == '{' {
            let close = find_close(pattern, i);
            if close < 0 {
                i += 1;
                continue;
            }
            let count = group_count(pattern, i, close, limit);
            total *= count;
            if total > limit { return limit + 1; }
            i = close + 1;
            continue;
        }
        i += 1;
    }
    return total;
}

// group_count returns the number of patterns the group from open to close
// gives.
//
// The scan of the alternatives is its own. The function calls
// variant_count, which calls this function again. A rule of the language
// forbids a growable value in the scope of such a call.
recursive fn group_count(pattern: u8[:], open: i64, close: i64, limit: i64) -> i64 {
    var count = 0;
    var start = open + 1;
    var k = open + 1;
    while k < close {
        let c = pattern[k];
        if c == '[' {
            k = skip_class(pattern, k);
            continue;
        }
        if c == '\\' {
            k += 2;
            continue;
        }
        if c == '{' {
            let inner = find_close(pattern, k);
            k += if inner < 0 { 1 } else { inner + 1 };
            continue;
        }
        if c == ',' {
            count += 1;
            start = k + 1;
        }
        k += 1;
    }
    count += 1;
    // A group with alternatives gives the sum of them.
    var total = 0;
    var s = open + 1;
    var j = open + 1;
    while j < close {
        let c = pattern[j];
        if c == '[' {
            j = skip_class(pattern, j);
            continue;
        }
        if c == '\\' {
            j += 2;
            continue;
        }
        if c == '{' {
            let inner = find_close(pattern, j);
            j += if inner < 0 { 1 } else { inner + 1 };
            continue;
        }
        if c == ',' {
            total += variant_count(pattern[s..j], limit);
            s = j + 1;
        }
        j += 1;
    }
    total += variant_count(pattern[s..close], limit);
    return total;
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
    var starts: i64[>..] = [];
    var ends: i64[>..] = [];
    split_offsets(s, starts, ends);
    for i in 0..starts.len { out.push(s[starts[i]..ends[i]]); }
    return out;
}

// split_offsets writes the bounds of the parts of s between the
// separators into starts and ends. The empty parts are dropped. An empty
// input gives one empty part.
fn split_offsets(s: u8[:], starts: i64[>..]&, ends: i64[>..]&) {
    var start = 0;
    var i = 0;
    while i < s.len {
        if s[i] == '/' {
            if i > start {
                starts.push(start);
                ends.push(i);
            }
            start = i + 1;
        }
        i += 1;
    }
    if start < s.len {
        starts.push(start);
        ends.push(s.len);
    }
    if starts.len == 0 {
        starts.push(0);
        ends.push(0);
    }
}

// split_alts writes the bounds of the alternatives of the group from g to
// close into starts and ends. The alternatives are the parts between the
// commas. A comma in a class, after a backslash or in a nested group does
// not end an alternative.
fn split_alts(v: u8[:], g: i64, close: i64, starts: i64[>..]&,
    ends: i64[>..]&) {
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
            starts.push(start);
            ends.push(k);
            start = k + 1;
        }
        k += 1;
    }
    starts.push(start);
    ends.push(close);
}

// is_globstar tells whether the segment is a star of the segments. Such a
// segment matches any number of segments.
fn is_globstar(seg: u8[:]) -> bool {
    return seg == "**";
}

// match_segments matches the path segments against the pattern segments.
// It returns true when the rest of both lists match.
//
// The failed table holds one entry for each pair of positions. A pair that
// failed is not tried again. Without it, a pattern with many "**" segments
// takes a time that grows with the power of the count.
recursive fn match_segments(path: const u8[:][>..]&, pat: const u8[:][>..]&, pi: i64, si: i64, failed: bool[>..]&) -> bool {
    if pi >= pat.len { return si >= path.len; }
    let key = pi * (path.len + 1) + si;
    if failed[key] { return false; }
    // A "**" segment matches any number of segments.
    if is_globstar(pat[pi]) {
        var k = si;
        while k <= path.len {
            if match_segments(path, pat, pi + 1, k, failed) { return true; }
            k += 1;
        }
    } else if si < path.len && match_segment(path[si], pat[pi]) {
        if match_segments(path, pat, pi + 1, si + 1, failed) { return true; }
    }
    failed[key] = true;
    return false;
}

// match_segment matches one path segment against one pattern segment. The
// segment holds no separator, so a '*' in it matches any bytes.
//
// The matcher uses a table of reachable positions. The table holds one
// entry for every position in the path. The table grows with the path. It
// never grows with the pattern.
//
// The table keeps the work linear in the size of the path. A backtracking
// matcher can take a long time on a pattern with many stars.
fn match_segment(path: u8[:], pat: u8[:]) -> bool {
    // reached[i] is true when the part of the pattern that is done
    // matches the first i bytes of the path.
    var reached: bool[>..] = [];
    for i in 0..path.len + 1 { reached.push(i == 0); }

    var p = 0;
    while p < pat.len {
        let c = pat[p];
        if c == '*' {
            // A star reaches every position after the first one that the
            // pattern reached. Skip the other stars.
            while p < pat.len && pat[p] == '*' { p += 1; }
            var i = 1;
            while i < reached.len {
                if reached[i - 1] { reached[i] = true; }
                i += 1;
            }
            continue;
        }
        if c == '?' {
            // A question mark takes one code point, but not a separator.
            // The segment holds no separator.
            step_rune(reached, path, pat, p, 0);
            p += 1;
            continue;
        }
        if c == '[' {
            let after = class_end(pat, p);
            if after == 0 {
                // An unterminated class is a literal.
                var i = reached.len;
                while i > 1 {
                    i -= 1;
                    let ok = reached[i - 1] && i - 1 < path.len && path[i - 1] == '[';
                    reached[i] = ok;
                }
                reached[0] = false;
                p += 1;
                continue;
            }
            // A class takes the next code point when it is in the class.
            step_rune(reached, path, pat, p, after);
            p = after;
            continue;
        }
        if c == '\\' && p + 1 < pat.len {
            // An escaped byte is a literal.
            var i = reached.len;
            while i > 1 {
                i -= 1;
                let ok = reached[i - 1] && i - 1 < path.len && path[i - 1] == pat[p + 1];
                reached[i] = ok;
            }
            reached[0] = false;
            p += 2;
            continue;
        }
        // A literal byte.
        var i = reached.len;
        while i > 1 {
            i -= 1;
            let ok = reached[i - 1] && i - 1 < path.len && path[i - 1] == c;
            reached[i] = ok;
        }
        reached[0] = false;
        p += 1;
    }
    return reached[path.len];
}

// class_end returns the index after the class that starts at pos. It
// returns 0 when the class is not closed.
fn class_end(pat: u8[:], pos: i64) -> i64 {
    let end = skip_class(pat, pos);
    if end > pat.len || end <= pos + 1 || pat[end - 1] != ']' { return 0; }
    return end;
}

// rune_len gives the length of the UTF-8 sequence that starts at i. A
// byte that starts no valid sequence counts as one.
fn rune_len(s: u8[:], i: i64) -> i64 {
    let c = s[i] as i64;
    var n = 0;
    if c >= 0xF0 && c < 0xF5 { n = 3; }
    else if c >= 0xE0 && c < 0xF0 { n = 2; }
    else if c >= 0xC2 && c < 0xE0 { n = 1; }
    if n == 0 || i + n >= s.len { return 1; }
    var k = 1;
    while k <= n {
        if (s[i + k] & 0xC0) != 0x80 { return 1; }
        k += 1;
    }
    return n + 1;
}

// rune_at gives the code point that starts at i. A byte that starts no
// valid sequence gives its value plus 0x200000, so it equals no code point.
fn rune_at(s: u8[:], i: i64) -> i64 {
    let n = rune_len(s, i);
    let c = s[i] as i64;
    if n == 1 { return if c < 0x80 { c } else { c + 0x200000 }; }
    var cp = if n == 2 { c & 31 } else if n == 3 { c & 15 } else { c & 7 };
    var k = 1;
    while k < n {
        cp = (cp << 6) | ((s[i + k] as i64) & 63);
        k += 1;
    }
    return cp;
}

// step_rune moves the table over one code point of the path. The pattern
// item is a question mark, or the class that starts at p and ends at end.
fn step_rune(reached: bool[>..]&, path: u8[:], pat: u8[:], p: i64, end: i64) {
    var next: bool[>..] = [];
    for i in 0..reached.len { next.push(false); }
    var i = 0;
    while i < path.len {
        if reached[i] && (end == 0 || class_has(pat, p, end, rune_at(path, i))) {
            next[i + rune_len(path, i)] = true;
        }
        i += 1;
    }
    for i in 0..reached.len { reached[i] = next[i]; }
}

// class_has returns true when the code point cp is in the class that
// starts at pos and ends at end.
fn class_has(pat: u8[:], pos: i64, end: i64, cp: i64) -> bool {
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
        let a = rune_at(body, i);
        let al = rune_len(body, i);
        if i + al + 1 < body.len && body[i + al] == '-' {
            let b = rune_at(body, i + al + 1);
            if cp >= a && cp <= b { found = true; }
            i += al + 1 + rune_len(body, i + al + 1);
            continue;
        }
        if a == cp { found = true; }
        i += al;
    }
    if negate { found = !found; }
    return found;
}
