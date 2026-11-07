// The capture of the glob package. Pure Goose.
//
// The capture gives the text that each wildcard of a pattern matched. It
// uses the rule of matches: a path splits at the separators, and a star
// never crosses a separator.
//
// The capture expands the groups of the pattern first. Every variant keeps
// the mark of each byte: the group that the byte came from. The mark gives
// the text of the group that matched.
//
// The work stays the product of the size of the pattern and the size of the
// path.

namespace glob;

import std;
import matcher;

// The kinds of a token.
const TK_LIT = 0;
const TK_STAR = 1;
const TK_QM = 2;
const TK_CLASS = 3;

// The most entries a table of the capture may hold. A pattern and a path
// that need more give no parts.
const MAX_TABLE_C = 1000000;

// The most bytes the expansion of a pattern may hold. The mark of every
// byte of the expansion costs more than the byte itself. A pattern with
// many alternatives and a long text must not take all the memory of the
// machine.
const MAX_EXPAND_C = 4000000;

// expand_marks writes the variants of the pattern into vt. Every variant
// keeps the mark of each byte in vm. The parent of each group goes into
// gparent. The bounds of the variants go into vs and ve.
//
// It gives false when the expansion of the pattern is too large.
fn expand_marks(pattern: u8[:], vt: u8[>..]&, vm: i64[>..]&,
    gparent: i64[>..]&, vs: i64[>..]&, ve: i64[>..]&) -> bool {
    vt.clear();
    vm.clear();
    gparent.clear();
    vs.clear();
    ve.clear();
    if variant_count(pattern, MAX_VARIANTS) > MAX_VARIANTS {
        // Too many variants. The pattern stays one pattern.
        vt.append(pattern);
        for i in 0..pattern.len { vm.push(-1); }
        vs.push(0);
        ve.push(pattern.len);
        return true;
    }
    // The bounds of the variants of the current round.
    var cs: i64[>..] = [];
    var ce: i64[>..] = [];
    vt.append(pattern);
    for i in 0..pattern.len { vm.push(-1); }
    cs.push(0);
    ce.push(pattern.len);
    loop {
        var ns: i64[>..] = [];
        var ne: i64[>..] = [];
        var changed = false;
        for i in 0..cs.len {
            let s = cs[i];
            let e = ce[i];
            let v = vt[s..e];
            let g = find_group(v);
            if g < 0 {
                // The variant has no group. It stays as it is.
                vs.push(s);
                ve.push(e);
                continue;
            }
            let close = find_close(v, g);
            if close < 0 {
                // A group that is not closed is a literal.
                vs.push(s);
                ve.push(e);
                continue;
            }
            changed = true;
            var alst: i64[>..] = [];
            var ale: i64[>..] = [];
            split_alts(v, g, close, alst, ale);
            for k in 0..alst.len {
                // The group takes the place of the text of its braces.
                let gid = gparent.len;
                gparent.push(vm[s + g]);
                let start = vt.len;
                // The text before the group keeps its marks.
                for x in s..(s + g) {
                    vt.push(vt[x]);
                    vm.push(vm[x]);
                }
                // The text of the alternative belongs to the group.
                for x in (s + alst[k])..(s + ale[k]) {
                    vt.push(vt[x]);
                    vm.push(gid);
                }
                // The text after the group keeps its marks.
                for x in (s + close + 1)..e {
                    vt.push(vt[x]);
                    vm.push(vm[x]);
                }
                ns.push(start);
                ne.push(vt.len);
            }
        }
        if !changed { break; }
        // The expansion of all the variants must stay small. Each byte of
        // it keeps a mark of eight bytes.
        if vt.len > MAX_EXPAND_C { return false; }
        cs.clear();
        ce.clear();
        for i in 0..ns.len {
            cs.push(ns[i]);
            ce.push(ne[i]);
        }
        if cs.len > MAX_VARIANTS { return false; }
    }
    return true;
}

// tokenize reads the segment of the variant between from and to into the
// token arrays. It gives the count of the tokens.
//
// A literal byte is one token. A star takes the whole run of stars. A
// question mark is one token. A class is one token that keeps its bounds
// in the segment.
fn tokenize(seg: u8[:], base: i64, kind: i64[>..]&,
    ta: i64[>..]&, tb: i64[>..]&, tp: i64[>..]&) -> i64 {
    let first = kind.len;
    var p = 0;
    while p < seg.len {
        let c = seg[p];
        if c == '*' {
            var run = 0;
            while p + run < seg.len && seg[p + run] == '*' { run += 1; }
            kind.push(TK_STAR);
            ta.push(0);
            tb.push(0);
            tp.push(base + p);
            p += run;
            continue;
        }
        if c == '?' {
            kind.push(TK_QM);
            ta.push(0);
            tb.push(0);
            tp.push(base + p);
            p += 1;
            continue;
        }
        if c == '[' {
            let e = class_end(seg, p);
            if e > 0 {
                kind.push(TK_CLASS);
                ta.push(p);
                tb.push(e);
                tp.push(base + p);
                    p = e;
                continue;
            }
            // A class that is not closed is a literal.
            kind.push(TK_LIT);
            ta.push(c);
            tb.push(0);
            tp.push(base + p);
            p += 1;
            continue;
        }
        if c == '\\' && p + 1 < seg.len {
            kind.push(TK_LIT);
            ta.push(seg[p + 1]);
            tb.push(0);
            tp.push(base + p);
            p += 2;
            continue;
        }
        kind.push(TK_LIT);
        ta.push(c);
        tb.push(0);
        tp.push(base + p);
        p += 1;
    }
    return kind.len - first;
}

// span_pair gives the text of each token of the pattern segment against
// the path segment. The bounds of the text go into from and to, in the
// order of the tokens.
//
// It gives false when the tokens do not match the text.
fn span_pair(kind: i64[:], ta: i64[:], tb: i64[:], t0: i64, n: i64,
    seg: u8[:], text: u8[:], ts: i64, te: i64, from: i64[>..]&,
    to: i64[>..]&) -> bool {
    let l = te - ts;
    let w = l + 1;
    let cells = (n + 1) * w;
    if cells > MAX_TABLE_C { return false; }
    var dp: bool[>..] = [];
    for c in 0..cells { dp.push(false); }
    // The end of the pattern matches only the end of the text.
    for j in 0..w { dp[n * w + j] = (j == l); }
    var i = n - 1;
    while i >= 0 {
        let k = kind[t0 + i];
        if k == TK_LIT {
            let c = ta[t0 + i];
            for j in 0..l {
                dp[i * w + j] = (text[ts + j] == c) && dp[(i + 1) * w + j + 1];
            }
            dp[i * w + l] = false;
        } else if k == TK_QM {
            for j in 0..l {
                dp[i * w + j] = dp[(i + 1) * w + j + 1];
            }
            dp[i * w + l] = false;
        } else if k == TK_CLASS {
            let p0 = ta[t0 + i];
            let p1 = tb[t0 + i];
            for j in 0..l {
                let hit = class_has(seg, p0, p1, text[ts + j]);
                dp[i * w + j] = hit && dp[(i + 1) * w + j + 1];
            }
            dp[i * w + l] = false;
        } else {
            // A star takes any bytes of the text.
            var f = dp[(i + 1) * w + l];
            dp[i * w + l] = f;
            var j = l - 1;
            while j >= 0 {
                f = dp[(i + 1) * w + j] || f;
                dp[i * w + j] = f;
                j -= 1;
            }
        }
        i -= 1;
    }
    if !dp[0] { return false; }
    // The walk that gives the text of each token. A star takes the
    // shortest text that still lets the rest match.
    var j = 0;
    var i = 0;
    while i < n {
        let k = kind[t0 + i];
        if k == TK_STAR {
            var e = j;
            while e <= l && !dp[(i + 1) * w + e] { e += 1; }
            from.push(ts + j);
            to.push(ts + e);
            j = e;
        } else {
            from.push(ts + j);
            to.push(ts + j + 1);
            j += 1;
        }
        i += 1;
    }
    return true;
}

// sort_parts puts the parts in the order of the pattern. A group comes
// before the parts inside it.
fn sort_parts(pk: i64[>..]&, pr: i64[>..]&, pid: i64[>..]&,
    pf: i64[>..]&, pt: i64[>..]&) {
    var x = 1;
    while x < pk.len {
        var y = x;
        while y > 0 && part_after(pk, pr, pid, y - 1, y) {
            var tmp = pk[y - 1];
            pk[y - 1] = pk[y];
            pk[y] = tmp;
            tmp = pr[y - 1];
            pr[y - 1] = pr[y];
            pr[y] = tmp;
            tmp = pid[y - 1];
            pid[y - 1] = pid[y];
            pid[y] = tmp;
            tmp = pf[y - 1];
            pf[y - 1] = pf[y];
            pf[y] = tmp;
            tmp = pt[y - 1];
            pt[y - 1] = pt[y];
            pt[y] = tmp;
            y -= 1;
        }
        x += 1;
    }
}

// part_after tells whether the part at b comes after the part at a in the
// order of the pattern.
fn part_after(pk: i64[:], pr: i64[:], pid: i64[:], a: i64, b: i64) -> bool {
    if pk[b] != pk[a] { return pk[b] < pk[a]; }
    if pr[b] != pr[a] { return pr[b] < pr[a]; }
    return pid[b] < pid[a];
}

// capture gives the parts of a match into out. The parts are separated by
// a newline byte.
//
// It gives the count of the parts when the text matches the pattern. It
// gives -1 when the text does not match. A count of 1 and an empty out
// mean one empty part. A count of 0 means no part.
//
// The rule of the match is the rule of matches. A part comes only for a
// text that matches also accepts.
fn capture(out: u8[>..]&, text: u8[:], pattern: u8[:]) -> i64 {
    out.clear();
    var vt: u8[>..] = [];
    var vm: i64[>..] = [];
    var gparent: i64[>..] = [];
    var vs: i64[>..] = [];
    var ve: i64[>..] = [];
    if !expand_marks(pattern, vt, vm, gparent, vs, ve) { return -1; }

    // The segments of the path.
    var xs: i64[>..] = [];
    var xe: i64[>..] = [];
    split_offsets(text, xs, xe);
    let sc = xs.len;

    // The cells of the tables of all the variants. The limit covers the
    // sum of them. A pattern with many variants and a long path must not
    // make the capture run for a long time.
    var cells_total = 0;

    for v in 0..vs.len {
        let vtext = vt[vs[v]..ve[v]];
        let vmark = vm[vs[v]..ve[v]];
        // The segments of the variant.
        var ps: i64[>..] = [];
        var pe: i64[>..] = [];
        split_offsets(vtext, ps, pe);
        let pc = ps.len;

        // The table of the segments. The entry f[g * w + s] is true when
        // the segments of the pattern from g match the segments of the
        // path from s.
        let w = sc + 1;
        let cells = (pc + 1) * w;
        cells_total += cells;
        if cells_total > MAX_TABLE_C { return -1; }
        var f: bool[>..] = [];
        for c in 0..cells { f.push(false); }
        for j in 0..w { f[pc * w + j] = (j == sc); }
        var g = pc - 1;
        while g >= 0 {
            if is_globstar(vtext[ps[g]..pe[g]]) {
                // A star of the segments takes any number of segments.
                f[g * w + sc] = f[(g + 1) * w + sc];
                var j = sc - 1;
                while j >= 0 {
                    f[g * w + j] = f[(g + 1) * w + j] || f[g * w + j + 1];
                    j -= 1;
                }
            } else {
                for j in 0..sc {
                    // The cell is false when the cell below it is false.
                    // The match of the segment runs only then.
                    if f[(g + 1) * w + j + 1] {
                        f[g * w + j] = match_segment(text[xs[j]..xe[j]],
                            vtext[ps[g]..pe[g]]);
                    }
                }
            }
            g -= 1;
        }
        if !f[0] { continue; }

        // The tokens of every segment of the variant. A segment of the
        // segments has no tokens.
        var kind: i64[>..] = [];
        var ta: i64[>..] = [];
        var tb: i64[>..] = [];
        var tp: i64[>..] = [];
        var tstart: i64[>..] = [];
        var tcount: i64[>..] = [];
        for g in 0..pc {
            if is_globstar(vtext[ps[g]..pe[g]]) {
                tstart.push(kind.len);
                tcount.push(0);
                continue;
            }
            let n = tokenize(vtext[ps[g]..pe[g]], ps[g], kind, ta, tb, tp);
            tstart.push(kind.len - n);
            tcount.push(n);
        }

        // The text of each token.
        var from: i64[>..] = [];
        var to: i64[>..] = [];
        // The bounds of the text of each group.
        var gf: i64[>..] = [];
        var gt: i64[>..] = [];
        var gfirst: i64[>..] = [];
        var gseen: i64[>..] = [];
        for c in 0..gparent.len {
            gf.push(0);
            gt.push(0);
            gfirst.push(0);
            gseen.push(0);
        }
        // The parts of the match.
        var pk: i64[>..] = [];
        var pr: i64[>..] = [];
        var pid: i64[>..] = [];
        var pf: i64[>..] = [];
        var pt: i64[>..] = [];

        var gi = 0;
        var si = 0;
        var ok = true;
        while gi < pc {
            if is_globstar(vtext[ps[gi]..pe[gi]]) {
                // The star takes the fewest segments that still let the
                // rest match.
                var k = 0;
                while si + k <= sc && !f[(gi + 1) * w + si + k] { k += 1; }
                pk.push(ps[gi]);
                pr.push(1);
                pid.push(-1);
                if k > 0 {
                    pf.push(xs[si]);
                    pt.push(xe[si + k - 1]);
                } else {
                    var at = 0;
                    if si < sc { at = xs[si]; }
                    else if sc > 0 { at = xe[sc - 1]; }
                    pf.push(at);
                    pt.push(at);
                }
                // The group of this segment takes the same text.
                mark_group(vmark, ps[gi], pf[pf.len - 1], pt[pt.len - 1],
                    gparent, gf, gt, gfirst, gseen);
                si += k;
                gi += 1;
                continue;
            }
            // The tokens of this segment against the segment of the path.
            if !span_pair(kind, ta, tb, tstart[gi], tcount[gi],
                vtext[ps[gi]..pe[gi]], text, xs[si], xe[si], from, to) {
                // The table of the segments says the segment matches. The
                // walk of the tokens says it does not. The alternative
                // does not match.
                ok = false;
                break;
            }
            // The parts of the wildcards of this segment.
            for q in 0..tcount[gi] {
                let t = tstart[gi] + q;
                if kind[t] == TK_STAR || kind[t] == TK_CLASS {
                    pk.push(tp[t]);
                    pr.push(1);
                    pid.push(-1);
                    pf.push(from[t]);
                    pt.push(to[t]);
                }
                // The text of the group of this token.
                mark_group(vmark, tp[t], from[t], to[t],
                    gparent, gf, gt, gfirst, gseen);
            }
            si += 1;
            gi += 1;
        }
        if !ok { continue; }

        // The parts of the groups.
        for gid in 0..gparent.len {
            if gseen[gid] == 1 {
                pk.push(gfirst[gid]);
                pr.push(0);
                pid.push(gid);
                pf.push(gf[gid]);
                pt.push(gt[gid]);
            }
        }

        // The parts come in the order of the pattern.
        sort_parts(pk, pr, pid, pf, pt);
        for q in 0..pf.len {
            if q > 0 { out.push('\n'); }
            out.append(text[pf[q]..pt[q]]);
        }
        return pf.len;
    }
    return -1;
}

// mark_group gives the text of the group of the byte at the position pos
// of the variant. The text goes into the bounds of the group. A group
// that the byte came from takes the text too.
fn mark_group(marks: i64[:], pos: i64, from: i64, to: i64,
    gparent: i64[:], gf: i64[>..]&, gt: i64[>..]&, gfirst: i64[>..]&,
    gseen: i64[>..]&) {
    var gid = marks[pos];
    while gid >= 0 {
        if gseen[gid] == 0 {
            gseen[gid] = 1;
            gf[gid] = from;
            gt[gid] = to;
            gfirst[gid] = pos;
        } else {
            if from < gf[gid] { gf[gid] = from; }
            if to > gt[gid] { gt[gid] = to; }
        }
        gid = gparent[gid];
    }
}
