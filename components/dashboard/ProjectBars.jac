"""Projects on the Overview: one ProjectRow per active project, then the
legend. `placeholder` draws `placeholderRows` skeleton rows, the count the
last visit had."""

import from .Panel { Panel, EmptyLine }
import from .ProjectRow { ProjectRow, ProjectLegend }
import from ..ui.skeleton { Skeleton }

def:pub ProjectBars(
    rows: list[dict[str, any]], placeholder: bool = False, placeholderRows: int = 3
) -> JsxElement {
    return
        <Panel id="projects-h" title="Projects" busy={placeholder}>
            {if len(rows) == 0 and not placeholder {
                <EmptyLine
                    key="empty"
                    text="No active projects."
                    action="Add a project"
                    to="/workspace?tab=projects"
                />
            } else {
                <div key="list">
                    <ul
                        className="grid grid-cols-[minmax(0,7.5rem)_minmax(0,1fr)_auto] gap-x-3 gap-y-3"
                    >
                        {for i in range(placeholderRows if placeholder else 0) {
                            <li
                                key={"ph" + str(i)}
                                className="col-span-3 grid grid-cols-subgrid items-center"
                            >
                                <Skeleton className="h-3.5 w-20"/>
                                <Skeleton className="h-2 w-full rounded-md"/>
                                <Skeleton className="h-3 w-12"/>
                            </li>
                        }}
                        {for r in rows {
                            <ProjectRow key={r["id"]} row={r}/>
                        }}
                    </ul>
                    <ProjectLegend/>
                </div>
            } }
        </Panel>;
}
