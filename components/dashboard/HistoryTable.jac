"""The charts' numbers as a table, folded behind "View as table": per week
added, moved to Done, and the running scope and done totals."""

def:pub HistoryTable(
    labels: list[str],
    added: list[int],
    finished: list[int],
    scope: list[int],
    done: list[int]
) -> JsxElement {
    return
        <details className="text-sm">
            <summary
                className="cursor-pointer select-none text-muted-foreground hover:text-foreground"
            >
                View as table
            </summary>
            <div className="mt-2 overflow-x-auto rounded-xl border">
                <table className="data-table w-full">
                    <thead>
                        <tr>
                            <th className="text-left">Week of</th>
                            <th className="text-right!">Added</th>
                            <th className="text-right!">Done</th>
                            <th className="text-right!">Scope</th>
                            <th className="text-right!">Done total</th>
                        </tr>
                    </thead>
                    <tbody>
                        {for (i, lab) in enumerate(labels) {
                            <tr key={lab + str(i)}>
                                <td className="num">{lab}</td>
                                <td className="num text-right">{str(added[i])}</td>
                                <td className="num text-right">{str(finished[i])}</td>
                                <td className="num text-right">{str(scope[i])}</td>
                                <td className="num text-right">{str(done[i])}</td>
                            </tr>
                        }}
                    </tbody>
                </table>
            </div>
        </details>;
}
