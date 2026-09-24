"""The flow line as an ordered list, the phone's default view. Order is flow
depth, then sort order, so the list reads the way the diagram runs."""

import from ...models { StepView }
import from .kinds { CARRY_LABEL }
import from .StepListRow { StepListRow }

def:pub StepList(
    steps: list[StepView],
    colOf: dict[str, int],
    selectedId: str = "",
    onOpen: Callable[[str], None] = None
) -> JsxElement {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    ordered = [s for s in steps];
    ordered.sort(key=lambda (st: StepView) { st.sort_order; });
    ordered.sort(key=lambda (st: StepView) { colOf[st.id] if st.id in colOf else 0; });

    outsOf: dict[str, list[dict[str, str]]] = {};
    for s in ordered {
        outs: list[dict[str, str]] = [];
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId {
                continue;
            }
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            carried = s.next_carries[i] if i < len(s.next_carries) else "";
            tag = CARRY_LABEL[carried] if carried in CARRY_LABEL else "";
            note = tag + (", " if tag and said else "") + said;
            outs.append(
                {
                    "key": s.id + ">" + nid,
                    "to": byId[nid].name,
                    "note": "(" + note + ")" if note else "",
                    "back": "1" if byId[nid].sort_order < s.sort_order else ""
                }
            );
        }
        outsOf[s.id] = outs;
    }

    return
        <ol aria-label="Steps in order" className="flex flex-col gap-1 p-2">
            {for s in ordered {
                <StepListRow
                    key={s.id}
                    step={s}
                    outs={outsOf[s.id]}
                    selected={s.id == selectedId}
                    onOpen={onOpen}
                />
            }}
        </ol>;
}
