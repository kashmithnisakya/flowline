"""The Condition and Approval nodes' settings: an expression to branch on, or
the role whose person must apply before anything after it runs."""

import from ....models { RoleView }
import from ...ui.input { Input }
import from ...ui.label { Label }

def:pub InspectOther(
    kind: str,
    expr: str,
    who: str,
    roles: list[RoleView],
    onCfg: Callable[[str, str], None]
) -> JsxElement {
    if kind == "condition" {
        return
            <div className="grid gap-2">
                <Label htmlFor="insp-expr">Expression</Label>
                <Input
                    id="insp-expr"
                    value={expr}
                    onChange={lambda (e: ChangeEvent) { onCfg(
                        "expr", e.target.value
                    ); }}
                />
                <p className="meta">For example: findings.blocking &gt; 0</p>
            </div>;
    }
    return
        <div className="grid gap-2">
            <Label htmlFor="insp-who">Who approves</Label>
            <select
                id="insp-who"
                className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                value={who}
                onChange={lambda (e: ChangeEvent) { onCfg("who", e.target.value); }}
            >
                {for r in roles {
                    <option key={r.id} value={r.id}>{r.name}</option>
                }}
            </select>
            <p className="meta">
                Nothing after this node runs until a person with this role applies it.
            </p>
        </div>;
}
