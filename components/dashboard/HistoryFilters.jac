"""The charts' own filter row: which project (or all) and how many weeks.
`projects` are the active ones as (id, name) pairs."""

import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}

glob HISTORY_RANGES: list[list[str]] = [
         ["8", "Last 8 weeks"],
         ["12", "Last 12 weeks"],
         ["26", "Last 26 weeks"]
     ];

def:pub HistoryFilters(
    projects: list[list[str]], project: str, weeks: str, onProject: any, onWeeks: any
) -> JsxElement {
    return
        <div className="flex gap-2 max-sm:w-full">
            <Select value={project} onValueChange={lambda (v: str) { onProject(v); }}>
                <SelectTrigger
                    className="h-8 w-44 max-sm:w-auto max-sm:flex-1"
                    size="sm"
                    aria-label="Chart project"
                >
                    <SelectValue/>
                </SelectTrigger>
                <SelectContent>
                    <SelectItem value="all">All projects</SelectItem>
                    {for p in projects {
                        <SelectItem key={p[0]} value={p[0]}>{p[1]}</SelectItem>
                    }}
                </SelectContent>
            </Select>
            <Select value={weeks} onValueChange={lambda (v: str) { onWeeks(v); }}>
                <SelectTrigger
                    className="h-8 w-40 max-sm:w-auto max-sm:flex-1"
                    size="sm"
                    aria-label="Chart range"
                >
                    <SelectValue/>
                </SelectTrigger>
                <SelectContent>
                    {for r in HISTORY_RANGES {
                        <SelectItem key={r[0]} value={r[0]}>{r[1]}</SelectItem>
                    }}
                </SelectContent>
            </Select>
        </div>;
}
