"""Computed swimlane layout for the flow line viewer. Nothing is persisted: lane
= owner role, column = longest forward path (send-backs ignored, which makes
loops terminate), so it recomputes from live data and cannot drift. Wires are
elbows in the column gaps, drawn in screen px from the canvas's node rects."""

import from ...models { StepView, RoleView, MemberView }
import from .geometry {
    NODE_W,
    MIN_NODE_W,
    MAX_NODE_W,
    DETAIL_LOW,
    CHIP_H,
    detailOf,
    nodeTitles,
    nodeHeight,
    polySamples
}

# Label gutter on the left, column pitch, lane breathing room and the card
# footprint height, in canvas px. The viewer draws the gutter at a fixed
# screen width instead (LANE_LABEL_W), so lane labels never shrink.
glob LANE_GUTTER: float = 176.0,
     LANE_COL_W: float = 208.0,
     LANE_PAD: float = 16.0,
     LANE_ROW_GAP: float = 14.0,
     LANE_NODE_H: float = 72.0,
     LANE_LABEL_W: float = 184.0,
     LANE_LABEL_NARROW: float = 128.0,
     # Fan spacing for ports sharing a card side, the part of a gap kept off
     # the card borders, and the room each trunk in a gap claims. Screen px.
     PORT_STEP: float = 10.0,
     TRUNK_INSET: float = 6.0,
     TRUNK_STEP: float = 7.0,
     LANE_MIN_GAP: float = 24.0,
     # The zoom range of the lane view, shared by the viewer's fit and the
     # band growth below so the bands drawn are the bands fitted.
     LANE_ZOOM_CAP: float = 1.25,
     LANE_ZOOM_MIN: float = 0.45;


# First names, "Kasun, Nina, Priya +1", for a lane label that has to fit.
def shortHolders(names: list[str]) -> str {
    firsts: list[str] = [];
    for n in names {
        parts = n.strip().split(" ");
        if len(firsts) < 3 {
            firsts.append(parts[0] if len(parts) > 0 else n);
        }
    }
    extra = len(names) - len(firsts);
    return ", ".join(firsts) + (" +" + str(extra) if extra > 0 else "");
}


# `boxW`/`boxH` are the fit's inner box in screen px, 0 when nothing has been
# measured yet; the bands grow into the height the fitted zoom leaves spare.
# `zoomHint` is that zoom when the viewer has fitted, else it is estimated from
# boxW and `gutterPx` (the fixed label gutter). Both clamp to the zoom range.
def:pub laneLayout(
    steps: list[StepView],
    roles: list[RoleView],
    members: list[MemberView],
    boxW: float = 0.0,
    boxH: float = 0.0,
    gutterPx: float = -1.0,
    zoomHint: float = 0.0
) -> dict[str, any] {
    # Column = longest forward path. sort_order is a topological order for
    # forward edges by construction, so one relaxation pass in that order
    # is exact.
    sortOf: dict[str, float] = {};
    for s in steps {
        sortOf[s.id] = s.sort_order;
    }
    depth: dict[str, int] = {};
    for s in steps {
        depth[s.id] = 0;
    }
    ordered = [s for s in steps];
    ordered.sort(key=lambda (st: StepView) { st.sort_order; });
    for s in ordered {
        for nid in s.next_ids {
            if nid in sortOf and sortOf[nid] > s.sort_order {
                deeper = depth[s.id] + 1;
                if deeper > depth[nid] {
                    depth[nid] = deeper;
                }
            }
        }
    }

    # Role lookups: color and holders, for the lane labels.
    roleNames: list[str] = [];
    colorOf: dict[str, str] = {};
    holdersOf: dict[str, list[str]] = {};
    for r in roles {
        roleNames.append(r.name);
        colorOf[r.name] = r.color or "slate";
        held: list[str] = [];
        for m in members {
            if m.active and r.name in m.roles {
                held.append(m.name);
            }
        }
        holdersOf[r.name] = held;
    }

    # Lane order: owners that are not managed roles ("anyone", legacy free
    # text) first, where work enters; then the org's roles in the Roles
    # tab's order; unowned last.
    seenOwners: list[str] = [];
    hasUnowned = False;
    for s in steps {
        said = s.owner.strip() if s.owner else "";
        if said {
            if said not in seenOwners {
                seenOwners.append(said);
            }
        } else {
            hasUnowned = True;
        }
    }
    allKeys: list[str] = [];
    for k in seenOwners {
        if k not in roleNames {
            allKeys.append(k);
        }
    }
    for rn in roleNames {
        if rn in seenOwners {
            allKeys.append(rn);
        }
    }
    if hasUnowned {
        allKeys.append("__unowned");
    }

    positions: dict[str, list[float]] = {};
    laneOf: dict[str, str] = {};
    # The grid behind the px: column and row slot per step, reported so a
    # smaller rendering (the task dialog's) can lay the same grid out.
    slotOf: dict[str, int] = {};
    lanes: list[dict[str, any]] = [];
    maxCol = 0;
    naturalH = 0.0;
    for key in allKeys {
        mine: list[StepView] = [];
        for s in steps {
            said = s.owner.strip() if s.owner else "";
            owner_key = said or "__unowned";
            if owner_key == key {
                mine.append(s);
            }
        }
        # Two steps in the same lane and column stack; the lane grows.
        rowsUsed: dict[int, int] = {};
        peakRows = 1;
        taskTotal = 0;
        for s in mine {
            col = depth[s.id];
            slot = rowsUsed[col] if col in rowsUsed else 0;
            rowsUsed[col] = slot + 1;
            if slot + 1 > peakRows {
                peakRows = slot + 1;
            }
            if col > maxCol {
                maxCol = col;
            }
            slotOf[s.id] = slot;
            laneOf[s.id] = key;
            taskTotal = taskTotal + s.task_count;
        }
        height = LANE_PAD * 2.0
            + float(peakRows) * LANE_NODE_H
            + float(peakRows - 1) * LANE_ROW_GAP;
        isRole = key in roleNames;
        # The sub-line: holders for a role (warning tone when nobody), a
        # hint for the two synthetic lanes.
        sub = "";
        short = "";
        warn = False;
        if key == "__unowned" {
            sub = "Set an owner in the designer";
            short = sub;
        } elif isRole {
            if len(holdersOf[key]) > 0 {
                sub = ", ".join(holdersOf[key]);
                short = shortHolders(holdersOf[key]);
            } else {
                sub = "No one yet";
                short = sub;
                warn = True;
            }
        } elif key == "anyone" {
            sub = "Any role";
            short = sub;
        }
        label = key;
        if key == "__unowned" {
            label = "Unowned";
        } elif key == "anyone" {
            label = "Anyone";
        }
        stepNoun = " step" if len(mine) == 1 else " steps";
        taskNoun = " task" if taskTotal == 1 else " tasks";
        lanes.append(
            {
                "key": key,
                "label": label,
                "sub": sub,
                "short": short,
                "warn": warn,
                "totals": str(len(mine)) + stepNoun + " · " + str(taskTotal) + taskNoun,
                "manage": isRole,
                "color": colorOf[key] if isRole else "slate",
                "y": 0.0,
                "h": height
            }
        );
        naturalH = naturalH + height;
    }

    # Pass two places the cards, because a band's height is only known once
    # the whole stack has been measured against the box.
    contentW = LANE_GUTTER + float(maxCol) * LANE_COL_W + NODE_W;
    scale = 1.0;
    if boxW > 0.0 and boxH > 0.0 and naturalH > 0.0 {
        # The zoom the fit lands on, so the bands grow to exactly the height
        # that zoom draws into the box.
        z = zoomHint;
        if z <= 0.0 {
            z = boxW / contentW;
            if gutterPx >= 0.0 {
                z = (boxW - gutterPx) / (contentW - LANE_GUTTER);
            }
        }
        if z > LANE_ZOOM_CAP {
            z = LANE_ZOOM_CAP;
        }
        if z < LANE_ZOOM_MIN {
            z = LANE_ZOOM_MIN;
        }
        target = boxH / z;
        if target > naturalH {
            scale = target / naturalH;
        }
    }
    top = 0.0;
    for ln in lanes {
        natural = float(ln["h"]);
        grown = natural * scale;
        ln["y"] = top;
        ln["h"] = grown;
        # The card block keeps its own height and sits in the middle of
        # whatever the band grew to.
        lead = (grown - (natural - LANE_PAD * 2.0)) / 2.0;
        for s in steps {
            if s.id in slotOf and laneOf[s.id] == str(ln["key"]) {
                positions[s.id] = [
                    LANE_GUTTER + float(depth[s.id]) * LANE_COL_W,
                    top + lead + float(slotOf[s.id]) * (LANE_NODE_H + LANE_ROW_GAP)
                ];
            }
        }
        top = top + grown;
    }
    return {
        "positions": positions,
        "lanes": lanes,
        "laneOf": laneOf,
        "colOf": depth,
        "slotOf": slotOf,
        "cols": maxCol + 1,
        "naturalH": naturalH
    };
}


# The highest zoom a lane fit may pick for a box `boxH` tall. Fitted bands
# fill the box, so a one-row band is a fixed share of it; when that share
# cannot hold a label chip beside a mid-detail card, the fit stays at low detail.
def:pub laneFitCap(boxH: float, naturalH: float) -> float {
    if naturalH <= 0.0 {
        return LANE_ZOOM_CAP;
    }
    rowPx = (LANE_PAD * 2.0 + LANE_NODE_H) * boxH / naturalH;
    room = (rowPx - nodeHeight("mid", 0, False)) / 2.0;
    if room < CHIP_H + 15.0 {
        return DETAIL_LOW - 0.005;
    }
    return LANE_ZOOM_CAP;
}


# Screen px between column c and c + 1: the zoomed pitch, but never less than
# the trunks routed through that gap need, so a wire never runs behind a card.
def:pub laneGaps(
    steps: list[StepView], colOf: dict[str, int], cols: int, z: float
) -> list[float] {
    uses: list[int] = [];
    k = 0;
    while k < cols {
        uses.append(0);
        k = k + 1;
    }
    for s in steps {
        if s.id not in colOf {
            continue;
        }
        cs = colOf[s.id];
        for nid in s.next_ids {
            if nid not in colOf or colOf[nid] == cs {
                continue;
            }
            gi = cs if colOf[nid] > cs else cs - 1;
            if gi >= 0 and gi < cols {
                uses[gi] = uses[gi] + 1;
            }
        }
    }
    gaps: list[float] = [];
    for n in uses {
        g = (LANE_COL_W - NODE_W) * z;
        want = TRUNK_INSET * 2.0 + float(n + 1) * TRUNK_STEP;
        if want > g {
            g = want;
        }
        if LANE_MIN_GAP > g {
            g = LANE_MIN_GAP;
        }
        gaps.append(g);
    }
    return gaps;
}


# Node rects in the lane view, screen px from the pan origin. Columns are as
# wide as their widest name needs (up to MAX_NODE_W), so nothing truncates and
# nothing spills into a gap; `total` is the columns' width for the fit.
def:pub laneRects(
    steps: list[StepView],
    positions: dict[str, list[float]],
    colOf: dict[str, int],
    z: float,
    stepTitles: dict[str, list[str]],
    need: dict[str, float],
    originX: float
) -> dict[str, any] {
    detail = detailOf(z);
    base = NODE_W * z;
    if base < MIN_NODE_W {
        base = MIN_NODE_W;
    }
    cols = 1;
    for s in steps {
        if s.id in colOf and colOf[s.id] + 1 > cols {
            cols = colOf[s.id] + 1;
        }
    }
    widths: list[float] = [];
    k = 0;
    while k < cols {
        widths.append(base);
        k = k + 1;
    }
    for s in steps {
        c = colOf[s.id] if s.id in colOf else 0;
        want = need[s.id] if s.id in need else 0.0;
        if want > MAX_NODE_W {
            want = MAX_NODE_W;
        }
        if want > widths[c] {
            widths[c] = want;
        }
    }
    gaps = laneGaps(steps, colOf, cols, z);
    lefts: list[float] = [];
    x = originX;
    for (c, cw) in enumerate(widths) {
        lefts.append(x);
        x = x + cw + (gaps[c] if c < cols - 1 else 0.0);
    }
    rects: dict[str, list[float]] = {};
    for s in steps {
        c = colOf[s.id] if s.id in colOf else 0;
        pos: list[float] = positions[s.id] if s.id in positions else [0.0, 0.0];
        shown = len(nodeTitles(s, stepTitles)) if detail == "high" else 0;
        more = detail == "high" and s.task_count > shown and s.id in stepTitles;
        h = nodeHeight(detail, shown, more);
        cy = (pos[1] + LANE_NODE_H / 2.0) * z;
        rects[s.id] = [lefts[c], cy - h / 2.0, widths[c], h];
    }
    return {"rects": rects, "total": x - originX};
}


# True when a level run at `y` between x0 and x1 would cross a drawn card other
# than the two it connects.
def runBlocked(
    steps: list[StepView],
    rects: dict[str, list[float]],
    x0: float,
    x1: float,
    y: float,
    a: str,
    b: str
) -> bool {
    lo = x0 if x0 < x1 else x1;
    hi = x1 if x0 < x1 else x0;
    for o in steps {
        if o.id == a or o.id == b or o.id not in rects {
            continue;
        }
        r = rects[o.id];
        if r[0] < hi
            and r[0] + r[2] > lo
            and r[1] - 4.0 < y
            and r[1] + r[3] + 4.0 > y {
            return True;
        }
    }
    return False;
}


# A clear level for a detour between x0 and x1: just above or below the
# target's row first (the side facing the source), then the source's. 0 when
# every candidate crosses a card.
def laneChannel(
    steps: list[StepView],
    rects: dict[str, list[float]],
    x0: float,
    x1: float,
    sr: list[float],
    tr: list[float],
    a: str,
    b: str
) -> float {
    above = sr[1] < tr[1];
    tUp = tr[1] - 14.0;
    tDown = tr[1] + tr[3] + 14.0;
    sUp = sr[1] - 14.0;
    sDown = sr[1] + sr[3] + 14.0;
    tries = [tUp, tDown, sDown, sUp] if above else [tDown, tUp, sUp, sDown];
    for y in tries {
        if y > 0.0 and not runBlocked(steps, rects, x0, x1, y, a, b) {
            return y;
        }
    }
    return 0.0;
}


# One elbow per transition in SCREEN px, from the node rects the canvas draws
# ([left, top, w, h]). With `colOf` each trunk runs in the drawn gap between two
# columns; without it `colGap` is assumed. Each entry carries d, arrow, and
# label `anchors` for geometry.placeChips.
def:pub laneWires(
    steps: list[StepView],
    rects: dict[str, list[float]],
    colGap: float,
    colOf: dict[str, int]
) -> list[dict[str, any]] {
    byId: dict[str, StepView] = {};
    useCols = False;
    cols = 0;
    for s in steps {
        byId[s.id] = s;
        if s.id in colOf and s.id in rects {
            useCols = True;
            if colOf[s.id] + 1 > cols {
                cols = colOf[s.id] + 1;
            }
        }
    }
    gap = colGap if colGap > 8.0 else 8.0;
    # The drawn left and right edge of every column.
    colL: list[float] = [];
    colR: list[float] = [];
    k = 0;
    while k < cols {
        colL.append(1000000000.0);
        colR.append(-1000000000.0);
        k = k + 1;
    }
    for s in steps {
        if useCols and s.id in colOf and s.id in rects {
            c = colOf[s.id];
            r = rects[s.id];
            if r[0] < colL[c] {
                colL[c] = r[0];
            }
            if r[0] + r[2] > colR[c] {
                colR[c] = r[0] + r[2];
            }
        }
    }

    # Every edge once, with the geometry it needs decided up front: which
    # side it leaves and enters, and which gap its trunk lives in.
    edges: list[dict[str, any]] = [];
    for s in steps {
        if s.id not in rects {
            continue;
        }
        sr = rects[s.id];
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId or nid not in rects {
                continue;
            }
            tr = rects[nid];
            target = byId[nid];
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            carried = s.next_carries[i] if i < len(s.next_carries) else "";
            isReturn = target.sort_order < s.sort_order;
            # Travel direction decides the sides, not send-back-ness: a back
            # edge can point at a deeper column when the flow forks.
            rightward = tr[0] > sr[0] + sr[2] / 2.0;
            leftward = tr[0] + tr[2] < sr[0] + sr[2] / 2.0;
            gapX = sr[0] + sr[2] if rightward else sr[0] - gap;
            gapW = gap;
            gk = str(int(gapX));
            # A detour for when both rows are blocked: along `chanY`, with a
            # second trunk in the gap beside the target.
            chanY = 0.0;
            gapX2 = 0.0;
            gapW2 = 0.0;
            gk2 = "";
            if useCols and s.id in colOf and nid in colOf {
                cs = colOf[s.id];
                ct = colOf[nid];
                rightward = ct > cs;
                leftward = ct < cs;
                sy = sr[1] + sr[3] / 2.0;
                ty = tr[1] + tr[3] / 2.0;
                gi = -1;
                # By default the trunk sits beside the source and the run
                # follows the target's row; when that row has cards in the
                # way and the source's row does not, the trunk moves across.
                gi2 = -1;
                if rightward {
                    gi = cs;
                    if ct > cs + 1
                        and runBlocked(steps, rects, colR[cs], tr[0], ty, s.id, nid) {
                        if not runBlocked(
                            steps, rects, sr[0] + sr[2], colL[ct], sy, s.id, nid
                        ) {
                            gi = ct - 1;
                        } else {
                            chanY = laneChannel(
                                steps, rects, colR[cs], colL[ct], sr, tr, s.id, nid
                            );
                            gi2 = ct - 1 if chanY > 0.0 else -1;
                        }
                    }
                } elif leftward {
                    gi = cs - 1;
                    if cs > ct + 1
                        and runBlocked(
                            steps, rects, tr[0] + tr[2], colL[cs], ty, s.id, nid
                        ) {
                        if not runBlocked(
                            steps, rects, colR[ct], sr[0], sy, s.id, nid
                        ) {
                            gi = ct;
                        } else {
                            chanY = laneChannel(
                                steps, rects, colR[ct], colL[cs], sr, tr, s.id, nid
                            );
                            gi2 = ct if chanY > 0.0 else -1;
                        }
                    }
                }
                if gi >= 0 and gi + 1 < cols {
                    gapX = colR[gi];
                    gapW = colL[gi + 1] - colR[gi];
                    gk = "c" + str(gi);
                }
                if gi2 >= 0 and gi2 + 1 < cols {
                    gapX2 = colR[gi2];
                    gapW2 = colL[gi2 + 1] - colR[gi2];
                    gk2 = "c" + str(gi2);
                } else {
                    chanY = 0.0;
                }
            }
            edges.append(
                {
                    "from": s.id,
                    "to": nid,
                    "sr": sr,
                    "tr": tr,
                    "rightward": rightward,
                    "leftward": leftward,
                    "gapX": gapX,
                    "gapW": gapW,
                    "gk": gk,
                    "chanY": chanY,
                    "gapX2": gapX2,
                    "gapW2": gapW2,
                    "gk2": gk2,
                    "trunkX2": 0.0,
                    "back": isReturn,
                    "label": said,
                    "carries": carried,
                    "outOff": 0.0,
                    "inOff": 0.0,
                    "trunkX": 0.0
                }
            );
        }
    }

    # Fan the ports: every use of one card side, ordered by where the other
    # end is (outgoing before incoming on a tie), spaced PORT_STEP apart.
    sideKeys: dict[str, list[int]] = {};
    for (idx, e) in enumerate(edges) {
        sr: list[float] = e["sr"];
        tr: list[float] = e["tr"];
        outSide = "";
        inSide = "";
        if e["rightward"] {
            outSide = "R";
            inSide = "L";
        } elif e["leftward"] {
            outSide = "L";
            inSide = "R";
        } else {
            goesDown = tr[1] > sr[1];
            outSide = "B" if goesDown else "T";
            inSide = "T" if goesDown else "B";
        }
        ko = str(e["from"]) + ":" + outSide;
        ki = str(e["to"]) + ":" + inSide;
        if ko not in sideKeys {
            sideKeys[ko] = [];
        }
        if ki not in sideKeys {
            sideKeys[ki] = [];
        }
        # Direction in the sign: positive outgoing, negative incoming.
        sideKeys[ko].append(idx + 1);
        sideKeys[ki].append(0 - (idx + 1));
    }
    for k in list(sideKeys.keys()) {
        uses = sideKeys[k];
        keyed: list[list[float]] = [];
        for u in uses {
            idx = (u if u > 0 else 0 - u) - 1;
            e = edges[idx];
            far: list[float] = e["tr"] if u > 0 else e["sr"];
            keyed.append([far[1], 0.0 if u > 0 else 1.0, float(u)]);
        }
        keyed.sort(key=lambda (row: list[float]) { row[0] * 10.0 + row[1]; });
        n = len(keyed);
        for (rank, row) in enumerate(keyed) {
            u = int(row[2]);
            idx = (u if u > 0 else 0 - u) - 1;
            off = (float(rank) - float(n - 1) / 2.0) * PORT_STEP;
            if u > 0 {
                edges[idx]["outOff"] = off;
            } else {
                edges[idx]["inOff"] = off;
            }
        }
    }

    # Spread the trunks that share a gap across its inner width, rightward
    # travellers first then leftward, each by source y.
    # A use is edge index * 2, plus 1 for a detour's second trunk.
    gapUsers: dict[str, list[int]] = {};
    for (idx, e) in enumerate(edges) {
        if not (e["rightward"] or e["leftward"]) {
            continue;
        }
        for (which, key) in enumerate([str(e["gk"]), str(e["gk2"])]) {
            if key {
                if key not in gapUsers {
                    gapUsers[key] = [];
                }
                gapUsers[key].append(idx * 2 + which);
            }
        }
    }
    for gk in list(gapUsers.keys()) {
        users = gapUsers[gk];
        ranked: list[list[float]] = [];
        for use in users {
            e = edges[use // 2];
            sr: list[float] = e["sr"];
            primary = 0.0 if e["rightward"] else 1.0;
            ranked.append([primary * 100000.0 + sr[1], float(use)]);
        }
        ranked.sort(key=lambda (row: list[float]) { row[0]; });
        n = len(ranked);
        for (rank, row) in enumerate(ranked) {
            use = int(row[1]);
            idx = use // 2;
            second = use % 2 == 1;
            e = edges[idx];
            inner = float(e["gapW2" if second else "gapW"]) - TRUNK_INSET * 2.0;
            if inner < 0.0 {
                inner = 0.0;
            }
            x = float(e["gapX2" if second else "gapX"])
                + TRUNK_INSET
                + inner * (float(rank) + 1.0) / (float(n) + 1.0);
            edges[idx]["trunkX2" if second else "trunkX"] = x;
        }
    }

    out: list[dict[str, any]] = [];
    for e in edges {
        sr: list[float] = e["sr"];
        tr: list[float] = e["tr"];
        outOff = float(e["outOff"]);
        inOff = float(e["inOff"]);
        # Seeded outside the branches: a name first assigned inside an `if`
        # is block-scoped in the compiled JS.
        d = "";
        arrow = "";
        poly: list[float] = [];
        anchors: list[list[float]] = [];
        if e["rightward"] or e["leftward"] {
            trunk = float(e["trunkX"]);
            ey = sr[1] + sr[3] / 2.0 + outOff;
            iy = tr[1] + tr[3] / 2.0 + inOff;
            ex = sr[0] + sr[2] if e["rightward"] else sr[0];
            ix = tr[0] if e["rightward"] else tr[0] + tr[2];
            dirn = 1.0 if e["rightward"] else -1.0;
            stop = ix - 9.0 * dirn;
            sameRow = (iy - ey) < 1.0 and (ey - iy) < 1.0;
            chanY = float(e["chanY"]);
            if chanY > 0.0 {
                t2 = float(e["trunkX2"]);
                d = (
                    "M "
                    + str(ex)
                    + " "
                    + str(ey)
                    + " L "
                    + str(trunk)
                    + " "
                    + str(ey)
                    + " L "
                    + str(trunk)
                    + " "
                    + str(chanY)
                    + " L "
                    + str(t2)
                    + " "
                    + str(chanY)
                    + " L "
                    + str(t2)
                    + " "
                    + str(iy)
                    + " L "
                    + str(stop)
                    + " "
                    + str(iy)
                );
                poly = [ex, ey, trunk, ey, trunk, chanY, t2, chanY, t2, iy, stop, iy];
                anchors.append(
                    [
                        trunk,
                        (ey + chanY) / 2.0,
                        1.0,
                        0.0,
                        -1.0 if e["rightward"] else 1.0,
                        ey if ey < chanY else chanY,
                        chanY if ey < chanY else ey,
                        ey
                    ]
                );
                for t in [0.5, 0.25, 0.75] {
                    anchors.append([trunk + (t2 - trunk) * t, chanY, 0.0, 1.0, 1.0]);
                }
            } elif sameRow {
                d = "M " + str(ex) + " " + str(ey) + " L " + str(stop) + " " + str(iy);
                poly = [ex, ey, stop, iy];
                anchors.append([(ex + ix) / 2.0, ey, 0.0, 1.0, 1.0]);
                # The run is only a gap long, so between two tall cards the
                # chip has to clear their top or bottom edge instead.
                topY = sr[1] if sr[1] < tr[1] else tr[1];
                botY = sr[1] + sr[3]
                    if sr[1] + sr[3] > tr[1] + tr[3]
                    else tr[1] + tr[3];
                anchors.append([(ex + ix) / 2.0, topY - 16.0, 0.0, 1.0, 1.0]);
                anchors.append([(ex + ix) / 2.0, botY + 16.0, 0.0, 1.0, -1.0]);
            } else {
                d = (
                    "M "
                    + str(ex)
                    + " "
                    + str(ey)
                    + " L "
                    + str(trunk)
                    + " "
                    + str(ey)
                    + " L "
                    + str(trunk)
                    + " "
                    + str(iy)
                    + " L "
                    + str(stop)
                    + " "
                    + str(iy)
                );
                poly = [ex, ey, trunk, ey, trunk, iy, stop, iy];
                # Beside the trunk first (rightward on the source side,
                # leftward on the other, so a two-way pair parts), then the
                # two horizontal runs. The trunk anchor also carries its span
                # and start, so the canvas can slide it along the source band.
                anchors.append(
                    [
                        trunk,
                        (ey + iy) / 2.0,
                        1.0,
                        0.0,
                        -1.0 if e["rightward"] else 1.0,
                        ey if ey < iy else iy,
                        iy if ey < iy else ey,
                        ey
                    ]
                );
                anchors.append([(ex + trunk) / 2.0, ey, 0.0, 1.0, 1.0]);
                anchors.append([(trunk + ix) / 2.0, iy, 0.0, 1.0, 1.0]);
            }
            arrow = (
                "M "
                + str(ix)
                + " "
                + str(iy)
                + " L "
                + str(ix - 10.0 * dirn)
                + " "
                + str(iy - 5.0)
                + " L "
                + str(ix - 10.0 * dirn)
                + " "
                + str(iy + 5.0)
                + " Z"
            );
        } else {
            # Same column: straight vertical between the facing edges.
            downward = tr[1] > sr[1];
            ex = sr[0] + sr[2] / 2.0 + outOff;
            ey = sr[1] + sr[3] if downward else sr[1];
            ix = tr[0] + tr[2] / 2.0 + inOff;
            iy = tr[1] if downward else tr[1] + tr[3];
            dirn = 1.0 if downward else -1.0;
            mid = (ey + iy) / 2.0;
            poly = [ex, ey, ex, mid, ix, mid, ix, iy];
            d = (
                "M "
                + str(ex)
                + " "
                + str(ey)
                + " L "
                + str(ex)
                + " "
                + str(mid)
                + " L "
                + str(ix)
                + " "
                + str(mid)
                + " L "
                + str(ix)
                + " "
                + str(iy - 9.0 * dirn)
            );
            arrow = (
                "M "
                + str(ix)
                + " "
                + str(iy)
                + " L "
                + str(ix - 5.0)
                + " "
                + str(iy - 10.0 * dirn)
                + " L "
                + str(ix + 5.0)
                + " "
                + str(iy - 10.0 * dirn)
                + " Z"
            );
            anchors.append([ix, (mid + iy) / 2.0, 1.0, 0.0, 1.0]);
        }
        out.append(
            {
                "key": str(e["from"]) + ">" + str(e["to"]),
                "from": e["from"],
                "to": e["to"],
                "d": d,
                "arrow": arrow,
                "anchors": anchors,
                "samples": polySamples(poly),
                "back": e["back"],
                "label": e["label"],
                "carries": e["carries"]
            }
        );
    }
    return out;
}
