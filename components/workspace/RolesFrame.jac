"""The Roles section's first-load frame: the real header over skeleton rows at the
real row height."""

import from ..ui.skeleton { Skeleton }
import from .RoleRow { ROLE_GRID }

def:pub RolesHeads(className: str = "") -> JsxElement {
    return
        <div
            className={"hidden grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_40px] items-center gap-x-4 border-b px-3 py-2 text-[12.5px] text-muted-foreground "
                + className}
        >
            <span>Role</span>
            <span>Held by</span>
            <span>Flow line</span>
            <span>AI</span>
            <span/>
        </div>;
}

def:pub RolesFrame -> JsxElement {
    return
        <div key="sk" aria-busy="true">
            <RolesHeads className="md:grid"/>
            <ul className="divide-y">
                {for i in [0, 1, 2] {
                    <li key={"r" + str(i)} className="px-3 py-2.5 md:py-2">
                        <div className={ROLE_GRID}>
                            <div className="col-start-1 row-start-1 min-w-0">
                                <div className="flex h-5 items-center">
                                    <Skeleton
                                        className={"h-3.5 "
                                            + ("w-24" if i % 2 else "w-32")}
                                    />
                                </div>
                                <div className="flex h-4 items-center">
                                    <Skeleton className="h-3 w-40"/>
                                </div>
                            </div>
                            <div
                                className="col-start-1 row-start-2 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 md:contents"
                            >
                                <div className="min-w-0 md:col-start-2">
                                    <Skeleton className="h-3.5 w-36"/>
                                </div>
                                <div className="min-w-0 md:col-start-3">
                                    <Skeleton className="h-3 w-28"/>
                                </div>
                                <div className="min-w-0 md:col-start-4">
                                    <Skeleton className="h-[22px] w-20 rounded-md"/>
                                </div>
                            </div>
                            <div
                                className="col-start-2 row-span-2 row-start-1 justify-self-end md:col-start-5 md:row-span-1"
                            />
                        </div>
                    </li>
                }}
            </ul>
        </div>;
}
