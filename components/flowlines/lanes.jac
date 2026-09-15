"""Computed swimlane layout for the flow line viewer. Nothing is persisted: lane
= owner role, column = longest forward path (send-backs ignored, which makes
loops terminate), so it recomputes from live data and cannot drift. Wires are
elbows in the column gaps, drawn in screen px from the canvas's node rects."""

import from ...models { StepView, RoleView, MemberView }
import from .geometry { NODE_W, polySamples }

# Label gutter on the left, column pitch, lane breathing room and the card
# footprint height, in canvas px. The viewer draws the gutter at a fixed
# screen width instead (LANE_LABEL_W), so lane labels never shrink.
glob LANE_GUTTER: float = 176.0,
     LANE_COL_W: float = 208.0,
     LANE_PAD: float = 16.0,
     LANE_ROW_GAP: float = 14.0,
     LANE_NODE_H: float = 72.0,
     LANE_LABEL_W: float = 184.0,
     # Fan spacing for ports sharing a card side, and the part of the gap
     # trunks may occupy (the rest keeps them off the card borders). Screen px.
     PORT_STEP: float = 10.0,
     TRUNK_INSET: float = 6.0,
     # How far the viewer's fit may scale the lane view up, shared with the
     # growth target below so the bands and the fit agree.
     LANE_ZOOM_CAP: float = 1.25;


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
# measured yet. The lane view is width-bound on any normal screen, so the bands
# grow into the spare height. With `gutterPx` >= 0 the viewer draws the label
# gutter at that fixed screen width, and the growth target accounts for it.
def:pub laneLayout(
    steps: list[StepView],
    roles: list[RoleView],
    members: list[MemberView],
    boxW: float = 0.0,
    boxH: float = 0.0,
    gutterPx: float = -1.0
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
        # The zoom the fit will land on, so the bands grow to exactly the
        # height that zoom draws into the box.
        z = boxW / contentW;
        if gutterPx >= 0.0 {
            z = (boxW - gutterPx) / (contentW - LANE_GUTTER);
        }
        if z > LANE_ZOOM_CAP {
            z = LANE_ZOOM_CAP;
        }
        target = boxH / z;
        if z > 0.0 and target > naturalH {
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
        "cols": maxCol + 1
    };
}


# One elbow per transition in SCREEN px, from the node rects the canvas draws
# ([left, top, w, h]). `colGap` is the screen gap between two columns. Each
# entry carries d, arrow, and label `anchors` for geometry.placeChips.
def:pub laneWires(
    steps: list[StepView], rects: dict[str, list[float]], colGap: float
) -> list[dict[str, any]] {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    gap = colGap if colGap > 8.0 else 8.0;

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
            gapX = 0.0;
            if rightward {
                gapX = sr[0] + sr[2];
            } elif leftward {
                gapX = sr[0] - gap;
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
    gapUsers: dict[str, list[int]] = {};
    for (idx, e) in enumerate(edges) {
        if not (e["rightward"] or e["leftward"]) {
            continue;
        }
        gk = str(int(float(e["gapX"])));
        if gk not in gapUsers {
            gapUsers[gk] = [];
        }
        gapUsers[gk].append(idx);
    }
    for gk in list(gapUsers.keys()) {
        users = gapUsers[gk];
        ranked: list[list[float]] = [];
        for idx in users {
            e = edges[idx];
            sr: list[float] = e["sr"];
            primary = 0.0 if e["rightward"] else 1.0;
            ranked.append([primary * 100000.0 + sr[1], float(idx)]);
        }
        ranked.sort(key=lambda (row: list[float]) { row[0]; });
        n = len(ranked);
        inner = gap - TRUNK_INSET * 2.0;
        if inner < 0.0 {
            inner = 0.0;
        }
        for (rank, row) in enumerate(ranked) {
            idx = int(row[1]);
            e = edges[idx];
            x = float(e["gapX"])
                + TRUNK_INSET
                + inner * (float(rank) + 1.0) / (float(n) + 1.0);
            edges[idx]["trunkX"] = x;
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
            if sameRow {
                d = "M " + str(ex) + " " + str(ey) + " L " + str(stop) + " " + str(iy);
                poly = [ex, ey, stop, iy];
                anchors.append([(ex + ix) / 2.0, ey, 0.0, 1.0, 1.0]);
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
                # two horizontal runs.
                anchors.append(
                    [trunk, (ey + iy) / 2.0, 1.0, 0.0, -1.0 if e["rightward"] else 1.0]
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
