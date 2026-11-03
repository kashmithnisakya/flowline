"""The new-task dialog's rarer fields, behind More: start date, estimate, category
and tags."""

import from ...ui.input { Input }
import from ...common.DatePicker { DatePicker }
import from .PropRow { PropRow, GHOST_INPUT, GHOST_DATE }

def:pub NewTaskMore(
    form: dict[str, str], categories: list[str], onField: Callable[[str, str], None]
) -> JsxElement {
    return
        <dl className="grid gap-y-px border-t pt-2">
            <PropRow label="Start date">
                <DatePicker
                    value={form["start_date"]}
                    clearable={True}
                    className={GHOST_DATE
                        + (" text-subtle!" if not form["start_date"] else "")}
                    onChange={lambda (d: str) { onField("start_date", d); }}
                />
            </PropRow>
            <PropRow label="Estimate">
                <Input
                    id="task-estimate"
                    type="number"
                    min="0"
                    step="0.5"
                    aria-label="Estimate"
                    className={GHOST_INPUT + " num"}
                    placeholder="Points or hours"
                    value={form["estimate"]}
                    onChange={lambda (e: any) { onField("estimate", e.target.value); }}
                />
            </PropRow>
            <PropRow label="Category">
                <Input
                    id="task-category"
                    list="flowline-categories"
                    aria-label="Category"
                    className={GHOST_INPUT}
                    placeholder="Type or pick"
                    value={form["category"]}
                    onChange={lambda (e: any) { onField("category", e.target.value); }}
                />
                <datalist id="flowline-categories">
                    {for c in categories {
                        <option key={c} value={c}/>
                    }}
                </datalist>
            </PropRow>
            <PropRow label="Tags">
                <Input
                    id="task-tags"
                    aria-label="Tags"
                    className={GHOST_INPUT}
                    placeholder="Comma-separated, e.g. bug, payments"
                    value={form["tags"]}
                    onChange={lambda (e: any) { onField("tags", e.target.value); }}
                />
            </PropRow>
        </dl>;
}
