"""Canvas geometry shared by FlowCanvas and the flow line page impl, in ONE
module so hit-testing and drawing cannot drift apart. Positions are free-form
px, so an edge can travel any direction; control handles are axis-aligned along
the dominant axis, keeping tangents exact and the arrowhead a fixed triangle."""

import from ...models { StepView }

glob NODE_W: float = 176.0,
     # Four lines: name, the blurb, kind, and who holds work here. Uniform
     # whether or not a step has a blurb - the geometry is one constant.
     NODE_H: float = 96.0,
     EDGE_ZONE: float = 12.0,
     # Working room kept beyond the furthest step, so there is always
     # somewhere to drag to without the canvas jumping.
     MARGIN: float = 120.0;

# Does this transition travel backwards? One definition, shared by the canvas
# and the inspector, so the two renderings of the same edge cannot disagree.
# Node size is constant, so top-left deltas equal centre deltas.
def isBackEdge(fx: float, fy: float, tx: float, ty: float) -> bool {
    dx = tx - fx;
    dy = ty - fy;
    ax = dx if dx >= 0.0 else 0.0 - dx;
    ay = dy if dy >= 0.0 else 0.0 - dy;
    if ax >= ay {
        return dx < 0.0;
    }
    return dy < 0.0;
}


# How close to a node's edge counts as grabbing its border (the wire port)
# rather than its body (a move).
# The position a step is actually drawn at: its live drag override, else the
# persisted one.
def stepXY(s: StepView, live: dict[str, list[float]]) -> list[float] {
    if s.id in live {
        return live[s.id];
    }
    return [s.x, s.y];
}


# Canvas big enough for every node plus working room to drag into.
def canvasSize(steps: list[StepView], live: dict[str, list[float]]) -> list[float] {
    # Content plus a margin to drag into, NOT padded to a minimum: CSS
    # min-width/height stretches the surface to the viewport, so a fitting
    # flow line shows no scrollbars and scrolling starts only past the edge.
    # A blank canvas keeps a surface for the empty state the same way.
    w = 320.0;
    h = 240.0;
    for s in steps {
        pos = stepXY(s, live);
        if pos[0] + NODE_W + MARGIN > w {
            w = pos[0] + NODE_W + MARGIN;
        }
        if pos[1] + NODE_H + MARGIN > h {
            h = pos[1] + NODE_H + MARGIN;
        }
    }
    return [w, h];
}


# Which step is under the canvas-relative pointer, and whether the pointer
# is in its border strip. Later steps render on top, so the LAST hit wins.
def hitStep(
    steps: list[StepView], live: dict[str, list[float]], px: float, py: float
) -> dict[str, any] {
    miss: dict[str, any] = {};
    if px < 0.0 or py < 0.0 {
        return miss;
    }
    found: list[StepView] = [];
    onEdge = False;
    for s in steps {
        pos = stepXY(s, live);
        inside = (
            px >= pos[0]
            and px <= pos[0] + NODE_W
            and py >= pos[1]
            and py <= pos[1] + NODE_H
        );
        if inside {
            found = [s];
            dxl = px - pos[0];
            dyt = py - pos[1];
            onEdge = (
                dxl < EDGE_ZONE
                or dyt < EDGE_ZONE
                or (NODE_W - dxl) < EDGE_ZONE
                or (NODE_H - dyt) < EDGE_ZONE
            );
        }
    }
    if not found {
        return miss;
    }
    return {"step": found[0], "onEdge": onEdge};
}


# The curve between two node rects, leaving and entering through the borders
# that face each other along the dominant axis. `twoWay` shifts it sideways so
# an A→B / B→A pair reads as two arcs. Returns the path, arrowhead, true
# midpoint (for the chip) and `back` (right-to-left or bottom-to-top travel).
def wire(x1: float, y1: float, x2: float, y2: float, twoWay: bool) -> dict[str, any] {
    c1x = x1 + NODE_W / 2.0;
    c1y = y1 + NODE_H / 2.0;
    c2x = x2 + NODE_W / 2.0;
    c2y = y2 + NODE_H / 2.0;
    dx = c2x - c1x;
    dy = c2y - c1y;
    horizontal = abs(dx) >= abs(dy);
    # A name first assigned inside a branch is block-scoped in the compiled
    # JS, so everything the branches write is initialised here first.
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
    bend = 0.0;
    back = False;
    shift = 0.0;
    if twoWay {
        if horizontal {
            shift = -10.0 if dx >= 0.0 else 10.0;
        } else {
            shift = -10.0 if dy >= 0.0 else 10.0;
        }
    }
    if horizontal {
        dirn = 1.0 if dx >= 0.0 else -1.0;
        sx = x1 + NODE_W if dx >= 0.0 else x1;
        sy = c1y + shift;
        ex = x2 if dx >= 0.0 else x2 + NODE_W;
        ey = c2y + shift;
        # Manual abs: the checker types abs() generically and refuses the
        # multiply below.
        span = ex - sx;
        if span < 0.0 {
            span = 0.0 - span;
        }
        bend = span * 0.45;
        if bend < 36.0 {
            bend = 36.0;
        }
        if bend > 120.0 {
            bend = 120.0;
        }
        h1x = sx + bend * dirn;
        h1y = sy;
        h2x = ex - bend * dirn;
        h2y = ey;
        b1x = ex - 9.0 * dirn;
        b1y = ey - 5.0;
        b2x = ex - 9.0 * dirn;
        b2y = ey + 5.0;
        back = dx < 0.0;
    } else {
        dirn = 1.0 if dy >= 0.0 else -1.0;
        sy = y1 + NODE_H if dy >= 0.0 else y1;
        sx = c1x + shift;
        ey = y2 if dy >= 0.0 else y2 + NODE_H;
        ex = c2x + shift;
        span = ey - sy;
        if span < 0.0 {
            span = 0.0 - span;
        }
        bend = span * 0.45;
        if bend < 36.0 {
            bend = 36.0;
        }
        if bend > 120.0 {
            bend = 120.0;
        }
        h1x = sx;
        h1y = sy + bend * dirn;
        h2x = ex;
        h2y = ey - bend * dirn;
        b1x = ex - 5.0;
        b1y = ey - 9.0 * dirn;
        b2x = ex + 5.0;
        b2y = ey - 9.0 * dirn;
        back = dy < 0.0;
    }
    d = (
        "M " + str(sx) + " " + str(sy) + " C " + str(h1x) + " " + str(h1y) + ", " + str(
            h2x
        ) + " " + str(h2y) + ", " + str(ex) + " " + str(ey)
    );
    arrow = (
        "M " + str(ex) + " " + str(ey) + " L " + str(b1x) + " " + str(b1y) + " L " + str(
            b2x
        ) + " " + str(b2y) + " Z"
    );
    return {
        "d": d,
        "arrow": arrow,
        # Cubic midpoint: (p1 + 3c1 + 3c2 + p2) / 8, exact because the
        # handles are known, no curve sampling.
        "mx": (sx + 3.0 * h1x + 3.0 * h2x + ex) / 8.0,
        "my": (sy + 3.0 * h1y + 3.0 * h2y + ey) / 8.0,
        "back": back
    };
}
