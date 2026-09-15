"""Canvas geometry shared by FlowCanvas and the flow line page impl, in ONE
module so hit-testing and drawing cannot drift apart. Positions persist in
canvas px; everything drawn is in SCREEN px (position times zoom), so text and
strokes keep their size at every zoom and only the layout scales."""

import from ...models { StepView }

glob NODE_W: float = 176.0,
     # The footprint a step claims in canvas px. What is drawn inside it is
     # sized in screen px by the zoom's detail level, see nodeRects.
     NODE_H: float = 96.0,
     ZOOM_MIN: float = 0.3,
     ZOOM_MAX: float = 2.0,
     ZOOM_STOPS: list[float] = [0.3, 0.4, 0.5, 0.6, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
     # Below LOW a node shows its name; up to HIGH also count and kind;
     # above HIGH the first task titles as well.
     DETAIL_LOW: float = 0.6,
     DETAIL_HIGH: float = 1.4,
     # Node anatomy in screen px.
     NODE_PAD_Y: float = 8.0,
     NAME_LH: float = 20.0,
     META_LH: float = 18.0,
     ROW_LH: float = 17.0,
     RULE_H: float = 9.0,
     MIN_NODE_W: float = 88.0,
     MAX_NODE_W: float = 240.0,
     # How close to a drawn border counts as grabbing the port, screen px.
     PORT_ZONE: float = 10.0,
     CHIP_H: float = 20.0,
     CHIP_PAD_X: float = 6.0;

# The position a step is actually drawn at: its live override, else persisted.
def stepXY(s: StepView, live: dict[str, list[float]]) -> list[float] {
    if s.id in live {
        return live[s.id];
    }
    return [s.x, s.y];
}


def detailOf(z: float) -> str {
    if z < DETAIL_LOW {
        return "low";
    }
    if z > DETAIL_HIGH {
        return "high";
    }
    return "mid";
}


def nextStop(z: float, dirn: int) -> float {
    if dirn > 0 {
        for v in ZOOM_STOPS {
            if v > z + 0.01 {
                return v;
            }
        }
        return ZOOM_MAX;
    }
    below = ZOOM_MIN;
    for v in ZOOM_STOPS {
        if v < z - 0.01 {
            below = v;
        }
    }
    return below;
}


def clampZoom(v: float) -> float {
    if v < ZOOM_MIN {
        return ZOOM_MIN;
    }
    if v > ZOOM_MAX {
        return ZOOM_MAX;
    }
    return v;
}


# The first task titles a node shows at high detail, and whether "N more"
# follows. Shared so the page's hit test sizes nodes as the canvas draws them.
def nodeTitles(s: StepView, stepTitles: dict[str, list[str]]) -> list[str] {
    shown: list[str] = [];
    if s.id in stepTitles {
        for t in stepTitles[s.id] {
            if len(shown) < 2 {
                shown.append(t);
            }
        }
    }
    return shown;
}


def nodeHeight(detail: str, shown: int, more: bool) -> float {
    h = NODE_PAD_Y * 2.0 + NAME_LH;
    if detail == "low" {
        return h;
    }
    h = h + 2.0 + META_LH;
    if detail == "high" and (shown > 0 or more) {
        h = h + RULE_H + float(shown) * ROW_LH + (ROW_LH if more else 0.0);
    }
    return h;
}


# Screen rect [left, top, w, h] of every step, relative to the pan origin.
# `ox` shifts x (the lane view's fixed label gutter); `footH` is the canvas-px
# footprint height the box centres on. `need` is the width a node's text wants:
# a node grows to it while it stays clear of the nodes beside it.
def nodeRects(
    steps: list[StepView],
    positions: dict[str, list[float]],
    z: float,
    stepTitles: dict[str, list[str]],
    ox: float,
    footH: float,
    need: dict[str, float] = {}
) -> dict[str, list[float]] {
    detail = detailOf(z);
    out: dict[str, list[float]] = {};
    base = NODE_W * z;
    if base < MIN_NODE_W {
        base = MIN_NODE_W;
    }
    centres: list[list[float]] = [];
    for s in steps {
        pos = stepXY(s, positions);
        shown = len(nodeTitles(s, stepTitles)) if detail == "high" else 0;
        more = detail == "high" and s.task_count > shown and s.id in stepTitles;
        h = nodeHeight(detail, shown, more);
        cx = ox + (pos[0] + NODE_W / 2.0) * z;
        cy = (pos[1] + footH / 2.0) * z;
        centres.append([cx, cy, h]);
    }
    for (i, s) in enumerate(steps) {
        c = centres[i];
        w = base;
        if s.id in need and need[s.id] > base {
            w = need[s.id] if need[s.id] < MAX_NODE_W else MAX_NODE_W;
            # Split the gap to any node on the same band evenly, so two
            # growing neighbours can never meet.
            for (j, o) in enumerate(centres) {
                if j == i {
                    continue;
                }
                dy = o[1] - c[1];
                ady = dy if dy >= 0.0 else 0.0 - dy;
                if ady >= (o[2] + c[2]) / 2.0 + 6.0 {
                    continue;
                }
                dx = o[0] - c[0];
                room = (dx if dx >= 0.0 else 0.0 - dx) - 16.0;
                if room < w {
                    w = room;
                }
            }
            if w < base {
                w = base;
            }
        }
        out[s.id] = [c[0] - w / 2.0, c[1] - c[2] / 2.0, w, c[2]];
    }
    return out;
}


# Which drawn node is under a pan-origin screen point, and whether the point
# is on its border strip (the wire port). Last in `steps` order wins.
def hitRect(
    steps: list[StepView], rects: dict[str, list[float]], sx: float, sy: float
) -> dict[str, any] {
    found = "";
    onEdge = False;
    for s in steps {
        if s.id not in rects {
            continue;
        }
        r = rects[s.id];
        if sx >= r[0] and sx <= r[0] + r[2] and sy >= r[1] and sy <= r[1] + r[3] {
            found = s.id;
            onEdge = (
                sx - r[0] < PORT_ZONE
                or sy - r[1] < PORT_ZONE
                or r[0] + r[2] - sx < PORT_ZONE
                or r[1] + r[3] - sy < PORT_ZONE
            );
        }
    }
    if not found {
        return {};
    }
    return {"id": found, "onEdge": onEdge};
}


# The curve between two screen rects, leaving and entering through the borders
# that face each other along the dominant axis. `twoWay` parts an A to B / B to
# A pair by a fixed screen offset; `shift` reports the side it took (-1 or 1).
def link(a: list[float], b: list[float], twoWay: bool) -> dict[str, any] {
    c1x = a[0] + a[2] / 2.0;
    c1y = a[1] + a[3] / 2.0;
    c2x = b[0] + b[2] / 2.0;
    c2y = b[1] + b[3] / 2.0;
    dx = c2x - c1x;
    dy = c2y - c1y;
    adx = dx if dx >= 0.0 else 0.0 - dx;
    ady = dy if dy >= 0.0 else 0.0 - dy;
    horizontal = adx >= ady;
    # Everything the branches write starts here: a first assignment inside
    # an `if` is block-scoped in the compiled JS.
    sx = 0.0;
    sy = 0.0;
    ex = 0.0;
    ey = 0.0;
    h1x = 0.0;
    h1y = 0.0;
    h2x = 0.0;
    h2y = 0.0;
    b1x = 0.0;
    b1y = 0.0;
    b2x = 0.0;
    b2y = 0.0;
    dirn = 1.0;
    side = 0.0;
    if twoWay {
        if horizontal {
            side = -1.0 if dx >= 0.0 else 1.0;
        } else {
            side = -1.0 if dy >= 0.0 else 1.0;
        }
    }
    shift = side * 7.0;
    span = 0.0;
    if horizontal {
        dirn = 1.0 if dx >= 0.0 else -1.0;
        sx = a[0] + a[2] if dx >= 0.0 else a[0];
        sy = c1y + shift;
        ex = b[0] if dx >= 0.0 else b[0] + b[2];
        ey = c2y + shift;
        span = ex - sx if ex >= sx else sx - ex;
    } else {
        dirn = 1.0 if dy >= 0.0 else -1.0;
        sy = a[1] + a[3] if dy >= 0.0 else a[1];
        sx = c1x + shift;
        ey = b[1] if dy >= 0.0 else b[1] + b[3];
        ex = c2x + shift;
        span = ey - sy if ey >= sy else sy - ey;
    }
    bend = span * 0.45;
    if bend < 28.0 {
        bend = 28.0;
    }
    if bend > 140.0 {
        bend = 140.0;
    }
    if horizontal {
        h1x = sx + bend * dirn;
        h1y = sy;
        h2x = ex - bend * dirn;
        h2y = ey;
        b1x = ex - 10.0 * dirn;
        b1y = ey - 5.0;
        b2x = ex - 10.0 * dirn;
        b2y = ey + 5.0;
    } else {
        h1x = sx;
        h1y = sy + bend * dirn;
        h2x = ex;
        h2y = ey - bend * dirn;
        b1x = ex - 5.0;
        b1y = ey - 10.0 * dirn;
        b2x = ex + 5.0;
        b2y = ey - 10.0 * dirn;
    }
    # The stroke stops at the arrow's base so the round cap cannot poke out.
    tx = ex - 9.0 * dirn if horizontal else ex;
    ty = ey if horizontal else ey - 9.0 * dirn;
    d = (
        "M "
        + str(sx)
        + " "
        + str(sy)
        + " C "
        + str(h1x)
        + " "
        + str(h1y)
        + ", "
        + str(h2x)
        + " "
        + str(h2y)
        + ", "
        + str(tx)
        + " "
        + str(ty)
    );
    arrow = (
        "M "
        + str(ex)
        + " "
        + str(ey)
        + " L "
        + str(b1x)
        + " "
        + str(b1y)
        + " L "
        + str(b2x)
        + " "
        + str(b2y)
        + " Z"
    );
    return {
        "d": d,
        "arrow": arrow,
        "pts": [sx, sy, h1x, h1y, h2x, h2y, ex, ey],
        "horizontal": horizontal,
        "side": side
    };
}


# Point and unit normal on a cubic [x0 y0 x1 y1 x2 y2 x3 y3] at t.
def cubicAt(p: list[float], t: float) -> list[float] {
    u = 1.0 - t;
    x = u * u * u * p[0]
        + 3.0 * u * u * t * p[2]
        + 3.0 * u * t * t * p[4]
        + t * t * t * p[6];
    y = u * u * u * p[1]
        + 3.0 * u * u * t * p[3]
        + 3.0 * u * t * t * p[5]
        + t * t * t * p[7];
    tx = 3.0 * u * u * (p[2] - p[0])
        + 6.0 * u * t * (p[4] - p[2])
        + 3.0 * t * t * (p[6] - p[4]);
    ty = 3.0 * u * u * (p[3] - p[1])
        + 6.0 * u * t * (p[5] - p[3])
        + 3.0 * t * t * (p[7] - p[5]);
    ln = (tx * tx + ty * ty) ** 0.5;
    if ln < 0.001 {
        return [x, y, 0.0, -1.0];
    }
    return [x, y, 0.0 - ty / ln, tx / ln];
}


def overlapArea(a: list[float], b: list[float]) -> float {
    ox = (a[0] + a[2] if a[0] + a[2] < b[0] + b[2] else b[0] + b[2])
        - (a[0] if a[0] > b[0] else b[0]);
    oy = (a[1] + a[3] if a[1] + a[3] < b[1] + b[3] else b[1] + b[3])
        - (a[1] if a[1] > b[1] else b[1]);
    if ox <= 0.0 or oy <= 0.0 {
        return 0.0;
    }
    return ox * oy;
}


# Points every ~12px along a polyline [x0, y0, x1, y1, ...], so a chip can
# tell when it would sit on top of another wire.
def polySamples(pts: list[float]) -> list[list[float]] {
    out: list[list[float]] = [];
    i = 0;
    while i + 3 < len(pts) {
        x0 = pts[i];
        y0 = pts[i + 1];
        x1 = pts[i + 2];
        y1 = pts[i + 3];
        ln = ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) ** 0.5;
        n = int(ln / 12.0) + 1;
        k = 0;
        while k < n {
            t = float(k) / float(n);
            out.append([x0 + (x1 - x0) * t, y0 + (y1 - y0) * t]);
            k = k + 1;
        }
        i = i + 2;
    }
    return out;
}


def cubicSamples(p: list[float]) -> list[list[float]] {
    out: list[list[float]] = [];
    ln = ((p[6] - p[0]) * (p[6] - p[0]) + (p[7] - p[1]) * (p[7] - p[1])) ** 0.5;
    n = int(ln / 10.0) + 8;
    k = 0;
    while k <= n {
        at = cubicAt(p, float(k) / float(n));
        out.append([at[0], at[1]]);
        k = k + 1;
    }
    return out;
}


# Put each label chip beside its own wire, clear of nodes, chips and wires.
# Anchors are [x, y, |nx|, |ny|, pref] (the wire's normal there); a chip steps
# up (+) or down, right (+) or left, far enough to clear that slope. The
# cheapest candidate wins; on the wire itself is the last resort. Sets cx/cy.
def placeChips(links: list[dict[str, any]], nodes: list[list[float]]) {
    placed: list[list[float]] = [];
    # A two-way pair has the least room (its partner wire runs alongside),
    # so pairs choose first and everything else fits around them.
    pairKeys: dict[str, bool] = {};
    for l in links {
        pairKeys[str(l["from"]) + ">" + str(l["to"])] = True;
    }
    ordered: list[dict[str, any]] = [];
    for l in links {
        if str(l["to"]) + ">" + str(l["from"]) in pairKeys {
            ordered.append(l);
        }
    }
    for l in links {
        if str(l["to"]) + ">" + str(l["from"]) not in pairKeys {
            ordered.append(l);
        }
    }
    for l in ordered {
        if not l["text"] {
            continue;
        }
        cw = float(l["cw"]);
        anchors: list[list[float]] = l["anchors"];
        band: list[float] = l["band"] if "band" in l else [];
        tries: list[list[float]] = [];
        for level in [0.0, 1.0, 2.0, 3.0] {
            for an in anchors {
                pref = an[4] if an[4] != 0.0 else 1.0;
                flat = an[3] >= an[2];
                for axis in ([0.0, 1.0] if flat else [1.0, 0.0]) {
                    # Rise over run of the wire as seen from this axis, and
                    # the extra offset that slope forces on a chip this size.
                    slope = 9.0;
                    if axis == 0.0 and an[3] > 0.01 {
                        slope = an[2] / an[3];
                    } elif axis == 1.0 and an[2] > 0.01 {
                        slope = an[3] / an[2];
                    }
                    lean = slope * (cw if axis == 0.0 else CHIP_H) / 2.0;
                    # Distance from the wire is what makes a label read as
                    # someone else's, so every extra px costs, and a steep
                    # lean is not worth trying at all.
                    if lean > 60.0 {
                        continue;
                    }
                    cost = level * 18.0 + lean * 0.5;
                    for sd in [pref, 0.0 - pref] {
                        if axis == 0.0 {
                            gap = CHIP_H / 2.0 + lean + 5.0 + level * 12.0;
                            tries.append([an[0], an[1] - sd * gap, cost]);
                        } else {
                            gap = cw / 2.0 + lean + 6.0 + level * 12.0;
                            tries.append([an[0] + sd * gap, an[1], cost]);
                        }
                    }
                }
            }
        }
        for an in anchors {
            tries.append([an[0], an[1], 50.0]);
        }
        # Cheapest first (a stable sort keeps the preference order on ties),
        # so the first spot that pays nothing beyond its own cost is the best.
        tries.sort(key=lambda (tr: list[float]) { tr[2]; });
        best: list[float] = [];
        bestScore = -1.0;
        for tr in tries {
            cx = tr[0];
            cy = tr[1];
            rect = [
                cx - cw / 2.0 - 3.0,
                cy - CHIP_H / 2.0 - 3.0,
                cw + 6.0,
                CHIP_H + 6.0
            ];
            score = tr[2];
            core = [cx - cw / 2.0, cy - CHIP_H / 2.0, cw, CHIP_H];
            # Crowding a node's or chip's margin costs by area. Covering its
            # words outright outranks everything; leaving the source lane
            # costs about as much as sitting 5px deep in a margin.
            for n in nodes {
                score = score + overlapArea(rect, n) * 40.0;
                if overlapArea(core, [n[0] + 6.0, n[1] + 6.0, n[2] - 12.0, n[3] - 12.0])
                    > 0.0 {
                    score = score + 100000.0;
                }
            }
            for q in placed {
                score = score + overlapArea(rect, q) * 40.0;
                if overlapArea(core, [q[0] + 2.0, q[1] + 2.0, q[2] - 4.0, q[3] - 4.0])
                    > 0.0 {
                    score = score + 100000.0;
                }
            }
            if len(band) > 0
                and (cy - CHIP_H / 2.0 < band[0] or cy + CHIP_H / 2.0 > band[1]) {
                score = score + 30000.0;
            }
            for o in links {
                if "samples" not in o {
                    continue;
                }
                # Across the partner wire a label reads as the partner's, and
                # over any other wire it hides it, so both beat a step outwards.
                weight = 20.0;
                if o["from"] == l["to"] and o["to"] == l["from"] {
                    weight = 40.0;
                } elif o["from"] == l["from"] and o["to"] == l["to"] {
                    weight = 3.0;
                }
                pts: list[list[float]] = o["samples"];
                for pt in pts {
                    if pt[0] > rect[0]
                        and pt[0] < rect[0] + rect[2]
                        and pt[1] > rect[1]
                        and pt[1] < rect[1] + rect[3] {
                        score = score + weight;
                    }
                }
            }
            if bestScore < 0.0 or score < bestScore {
                bestScore = score;
                best = [cx, cy];
            }
            if score == tr[2] {
                break;
            }
        }
        if len(best) == 0 {
            continue;
        }
        l["cx"] = best[0];
        l["cy"] = best[1];
        placed.append(
            [
                best[0] - cw / 2.0 - 2.0,
                best[1] - CHIP_H / 2.0 - 2.0,
                cw + 4.0,
                CHIP_H + 4.0
            ]
        );
    }
}
