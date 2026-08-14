"""Computed swimlane layout for the workflow viewer.

Nothing here is persisted: the lane is the step's owner role and the column
is its depth in the flow, so the projection recomputes from live data and
can never drift from it the way stored positions could. Steps arrive
already sorted by sort_order (GetWorkflow sorts), and an edge counts as
forward only when it points at a LATER step in that order, the same
definition FlowCanvas uses for send-backs. Ignoring the send-backs is what
makes the layout terminate on loops.

Lanes appear in order of first appearance along the flow, which puts the
"anyone" lane first on the seeded template, with an Unowned lane last when
any step has no owner. A lane's sub-line carries who holds the role, so
the lane labels double as the who-does-what answer.
"""

import from ...models { StepView, RoleView, MemberView }
import from .geometry { NODE_W, NODE_H }

# Label gutter on the left, column pitch, and the vertical breathing room
# inside a lane. Canvas px, the same space the freeform designer draws in.
glob LANE_GUTTER: float = 210.0,
     LANE_COL_W: float = 244.0,
     LANE_PAD: float = 26.0,
     LANE_ROW_GAP: float = 18.0;


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

    # Lane order: first appearance along the flow; Unowned last.
    laneKeys: list[str] = [];
    hasUnowned = False;
    for s in steps {
        said = s.owner.strip() if s.owner else "";
        if said {
            if said not in laneKeys {
                laneKeys.append(said);
            }
        } else {
            hasUnowned = True;
        }
    }
    allKeys: list[str] = [];
    for k in laneKeys {
        allKeys.append(k);
    }
    if hasUnowned {
        allKeys.append("__unowned");
    }

    positions: dict[str, list[float]] = {};
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
        for s in mine {
            col = depth[s.id];
            slot = rowsUsed[col] if col in rowsUsed else 0;
            rowsUsed[col] = slot + 1;
            if slot + 1 > peakRows {
                peakRows = slot + 1;
            }
            positions[s.id] = [
                LANE_GUTTER + float(col) * LANE_COL_W,
                top + LANE_PAD + float(slot) * (NODE_H + LANE_ROW_GAP)
            ];
        }
        height = LANE_PAD * 2.0
            + float(peakRows) * NODE_H
            + float(peakRows - 1) * LANE_ROW_GAP;
        isRole = key in roleNames;
        sub = "";
        if key == "__unowned" {
            sub = "set an owner in the designer";
        } elif isRole {
            sub = holdersOf[key] if holdersOf[key] else "no one yet";
        }
        lanes.append(
            {
                "key": key,
                "label": "Unowned" if key == "__unowned" else key,
                "sub": sub,
                "color": colorOf[key] if isRole else "slate",
                "y": top,
                "h": height
            }
        );
        top = top + height;
    }
    return {"positions": positions, "lanes": lanes};
}
