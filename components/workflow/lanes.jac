"""Computed swimlane layout for the workflow viewer. Nothing is persisted: lane
= owner role, column = longest forward path (send-backs ignored, which makes
loops terminate), so it recomputes from live data and cannot drift. Wires are
elbows in the column gaps; cards are shorter because the owner line is gone."""

import from ...models { StepView, RoleView, MemberView }
import from .geometry { NODE_W }

# Label gutter on the left, column pitch, lane breathing room and the
# compact card height. Canvas px, the same space the designer draws in.
glob LANE_GUTTER: float = 176.0,
     LANE_COL_W: float = 208.0,
     LANE_PAD: float = 16.0,
     LANE_ROW_GAP: float = 14.0,
     LANE_NODE_H: float = 64.0,
     # Fan spacing for ports sharing a card side, and the part of the gap
     # trunks may occupy (the rest keeps them off the card borders).
     PORT_STEP: float = 12.0,
     TRUNK_INSET: float = 6.0;


def:pub laneLayout(
    steps: list[StepView],
    roles: list[RoleView],
    members: list[MemberView]
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
    for s in steps {
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
    holdersOf: dict[str, str] = {};
    for r in roles {
        roleNames.append(r.name);
        colorOf[r.name] = r.color or "slate";
        held: list[str] = [];
        for m in members {
            if m.active and r.name in m.roles {
                held.append(m.name);
            }
        }
        holdersOf[r.name] = ", ".join(held);
    }

    # Lane order: role lanes follow the org's role order (the Roles tab's), so
    # the picture agrees with the list. Owners that are not managed roles
    # ("anyone", legacy free text) come first by first appearance, that being
    # where work enters before it belongs to any role. Unowned last.
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
    lanes: list[dict[str, any]] = [];
    top = 0.0;
    for key in allKeys {
        mine: list[StepView] = [];
        for s in steps {
            said = s.owner.strip() if s.owner else "";
            owner_key = said if said else "__unowned";
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
            positions[s.id] = [
                LANE_GUTTER + float(col) * LANE_COL_W,
                top + LANE_PAD + float(slot) * (LANE_NODE_H + LANE_ROW_GAP)
            ];
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
        warn = False;
        if key == "__unowned" {
            sub = "set an owner in the designer";
        } elif isRole {
            if holdersOf[key] {
                sub = holdersOf[key];
            } else {
                sub = "no one yet";
                warn = True;
            }
        } elif key == "anyone" {
            sub = "any role";
        }
        stepNoun = " step" if len(mine) == 1 else " steps";
        taskNoun = " task" if taskTotal == 1 else " tasks";
        lanes.append(
            {
                "key": key,
                "label": "Unowned" if key == "__unowned" else key,
                "sub": sub,
                "warn": warn,
                "totals": str(len(mine)) + stepNoun + " · " + str(taskTotal) + taskNoun,
                "manage": isRole,
                "color": colorOf[key] if isRole else "slate",
                "y": top,
                "h": height
            }
        );
        top = top + height;
    }
    return {"positions": positions, "lanes": lanes, "laneOf": laneOf};
}


# One elbow per transition, in canvas px. Each entry carries the same keys
# FlowCanvas reads off wire() (d, arrow, mx/my, lx/ly, back, label) plus
# `side`: -1 puts the label chip to the left of its anchor, 1 to the right,
# 0 centers it above.
def:pub laneWires(
    steps: list[StepView], positions: dict[str, list[float]]
) -> list[dict[str, any]] {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    half = LANE_NODE_H / 2.0;
    gap = LANE_COL_W - NODE_W;

    # Every edge once, with the geometry it needs decided up front: which
    # side it leaves and enters, and which gap its trunk lives in.
    edges: list[dict[str, any]] = [];
    for s in steps {
        if s.id not in positions {
            continue;
        }
        sp = positions[s.id];
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId or nid not in positions {
                continue;
            }
            tp = positions[nid];
            target = byId[nid];
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            twoWay = s.id in target.next_ids;
            isReturn = target.sort_order < s.sort_order;
            # Travel direction decides the sides, not send-back-ness: a
            # back edge can point at a deeper column when the flow forks.
            rightward = tp[0] > sp[0] + 1.0;
            leftward = tp[0] < sp[0] - 1.0;
            # The gap index the trunk lives in, keyed by the x of its
            # left edge, so trunks in one gap can be spread together.
            gapX = 0.0;
            if rightward {
                gapX = sp[0] + NODE_W;
            } elif leftward {
                gapX = sp[0] - gap;
            }
            edges.append(
                {
                    "from": s.id,
                    "to": nid,
                    "sx": sp[0],
                    "sy": sp[1],
                    "tx": tp[0],
                    "ty": tp[1],
                    "rightward": rightward,
                    "leftward": leftward,
                    "gapX": gapX,
                    "twoWay": twoWay,
                    "back": isReturn,
                    "label": said,
                    "outOff": 0.0,
                    "inOff": 0.0,
                    "trunkX": 0.0
                }
            );
        }
    }

    # Fan the ports: every use of one card side, ordered by where the other
    # end is (then outgoing before incoming on a tie), spaced PORT_STEP
    # apart around the side's centre. Keeps two-way pairs parted and
    # keeps a card's fan-out from leaving as one line.
    sideKeys: dict[str, list[int]] = {};
    for (idx, e) in enumerate(edges) {
        outSide = "";
        inSide = "";
        if e["rightward"] {
            outSide = "R";
            inSide = "L";
        } elif e["leftward"] {
            outSide = "L";
            inSide = "R";
        } else {
            goesDown = float(e["ty"]) > float(e["sy"]);
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
        # Encode direction in the sign: positive = outgoing use, negative =
        # incoming, index+1 so zero never collides.
        sideKeys[ko].append(idx + 1);
        sideKeys[ki].append(0 - (idx + 1));
    }
    for k in list(sideKeys.keys()) {
        uses = sideKeys[k];
        # Sort key: the y of the far end, ties broken outgoing-first.
        keyed: list[list[float]] = [];
        for u in uses {
            idx = (u if u > 0 else 0 - u) - 1;
            e = edges[idx];
            farY = float(e["ty"]) if u > 0 else float(e["sy"]);
            keyed.append([farY, 0.0 if u > 0 else 1.0, float(u)]);
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
    # travellers first then leftward, each by source y, so a two-way pair
    # never stacks on one x.
    gapUsers: dict[str, list[int]] = {};
    for (idx, e) in enumerate(edges) {
        if not (e["rightward"] or e["leftward"]) {
            continue;
        }
        gk = str(int(e["gapX"]));
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
            primary = 0.0 if e["rightward"] else 1.0;
            ranked.append([primary * 100000.0 + float(e["sy"]), float(idx)]);
        }
        ranked.sort(key=lambda (row: list[float]) { row[0]; });
        n = len(ranked);
        inner = gap - TRUNK_INSET * 2.0;
        for (rank, row) in enumerate(ranked) {
            idx = int(row[1]);
            e = edges[idx];
            x = float(e["gapX"]) + TRUNK_INSET + inner * (float(rank) + 1.0) / (float(n) + 1.0);
            edges[idx]["trunkX"] = x;
        }
    }

    out: list[dict[str, any]] = [];
    for e in edges {
        sx = float(e["sx"]);
        sy = float(e["sy"]);
        tx = float(e["tx"]);
        ty = float(e["ty"]);
        outOff = float(e["outOff"]);
        inOff = float(e["inOff"]);
        # Seeded outside the branches: a name first assigned inside an
        # `if` is block-scoped in the compiled JS.
        d = "";
        arrow = "";
        lx = 0.0;
        ly = 0.0;
        side = 0;
        if e["rightward"] or e["leftward"] {
            trunk = float(e["trunkX"]);
            ey = sy + half + outOff;
            iy = ty + half + inOff;
            # A rightward wire leaves the right edge and enters the left;
            # a leftward one the reverse.
            ex = sx + NODE_W if e["rightward"] else sx;
            ix = tx if e["rightward"] else tx + NODE_W;
            sameRow = (iy - ey) < 1.0 and (ey - iy) < 1.0;
            if sameRow {
                d = "M " + str(ex) + " " + str(ey) + " L " + str(ix) + " " + str(iy);
            } else {
                d = (
                    "M " + str(ex) + " " + str(ey)
                    + " L " + str(trunk) + " " + str(ey)
                    + " L " + str(trunk) + " " + str(iy)
                    + " L " + str(ix) + " " + str(iy)
                );
            }
            dirn = 1.0 if e["rightward"] else -1.0;
            arrow = (
                "M " + str(ix) + " " + str(iy)
                + " L " + str(ix - 8.0 * dirn) + " " + str(iy - 4.5)
                + " L " + str(ix - 8.0 * dirn) + " " + str(iy + 4.5)
                + " Z"
            );
            span = iy - ey;
            if span < 0.0 {
                span = 0.0 - span;
            }
            if sameRow or span < 40.0 {
                # Short trunk: the chip goes above the longer horizontal run.
                lx = (ex + ix) / 2.0;
                ly = (ey + iy) / 2.0 - 13.0;
                side = 0;
            } else {
                # Beside the trunk at its midpoint: rightward wires keep the
                # chip on the source side, leftward on the other, so a
                # two-way pair reads on opposite sides of the gap.
                lx = trunk;
                ly = (ey + iy) / 2.0;
                side = -1 if e["rightward"] else 1;
            }
        } else {
            # Same column: straight vertical between the facing edges.
            downward = ty > sy;
            ex = sx + NODE_W / 2.0 + outOff;
            ey = sy + LANE_NODE_H if downward else sy;
            ix = tx + NODE_W / 2.0 + inOff;
            iy = ty if downward else ty + LANE_NODE_H;
            d = (
                "M " + str(ex) + " " + str(ey)
                + " L " + str(ex) + " " + str((ey + iy) / 2.0)
                + " L " + str(ix) + " " + str((ey + iy) / 2.0)
                + " L " + str(ix) + " " + str(iy)
            );
            dirn = 1.0 if downward else -1.0;
            arrow = (
                "M " + str(ix) + " " + str(iy)
                + " L " + str(ix - 4.5) + " " + str(iy - 8.0 * dirn)
                + " L " + str(ix + 4.5) + " " + str(iy - 8.0 * dirn)
                + " Z"
            );
            lx = ix;
            ly = (ey + iy) / 2.0;
            side = 1;
        }
        out.append(
            {
                "key": str(e["from"]) + ">" + str(e["to"]),
                "from": e["from"],
                "to": e["to"],
                "d": d,
                "arrow": arrow,
                "mx": lx,
                "my": ly,
                "lx": lx,
                "ly": ly,
                "side": side,
                "back": e["back"],
                "label": e["label"]
            }
        );
    }
    return out;
}
