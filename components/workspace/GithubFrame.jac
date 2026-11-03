"""The GitHub section's first-load frame: the repository table for a browser that
last saw this workspace connected, the connect card otherwise, so the frame is
the view the section will most likely land on.
"""

import from ...lib.session { GITHUB_KEY }
import from ..ui.skeleton { Skeleton }
import from .SectionPanel { FLUSH }

def wasConnected -> bool {
    try {
        return localStorage.getItem(GITHUB_KEY) == "1";
    } except Exception as e {
        return False;
    }
}

def:pub GithubFrame -> JsxElement {
    if wasConnected() {
        return
            <div aria-busy="true">
                {for i in [0, 1] {
                    <div
                        key={"row" + str(i)}
                        className="flex min-h-11 items-center gap-4 border-b px-4 py-2"
                    >
                        <Skeleton className={"h-3.5 " + ("w-28" if i else "w-36")}/>
                        <Skeleton className="h-3 w-24"/>
                        <Skeleton className="ml-auto h-[18px] w-8 rounded-full"/>
                        <Skeleton className="h-[18px] w-8 rounded-full"/>
                        <Skeleton className="h-[18px] w-8 rounded-full"/>
                    </div>
                }}
                <div className="flex items-center px-4 py-2.5">
                    <Skeleton className="h-8 w-32 rounded-md"/>
                </div>
            </div>;
    }
    return
        <div aria-busy="true" className={FLUSH}>
            <div
                className="surface grid gap-8 p-6 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] md:gap-0 md:p-0"
            >
                <div className="flex flex-col items-start gap-4 md:p-7">
                    <Skeleton className="size-7 rounded-full"/>
                    <div className="flex h-[30px] items-center">
                        <Skeleton className="h-5 w-72 max-w-full"/>
                    </div>
                    <div className="flex w-full flex-col gap-2.5 pl-5">
                        <Skeleton className="h-3.5 w-64 max-w-full"/>
                        <Skeleton className="h-3.5 w-56 max-w-full"/>
                        <Skeleton className="h-3.5 w-72 max-w-full"/>
                    </div>
                    <Skeleton className="h-9 w-36 rounded-md"/>
                </div>
                <div className="border-t pt-6 md:border-t-0 md:border-l md:p-7">
                    <Skeleton className="h-3.5 w-44"/>
                    <div className="mt-2 flex flex-col">
                        {for i in [0, 1, 2] {
                            <div
                                key={"perm" + str(i)}
                                className="flex items-center border-b py-2.5 last:border-b-0"
                            >
                                <Skeleton
                                    className={"h-3.5 " + ("w-3/4" if i else "w-2/3")}
                                />
                            </div>
                        }}
                    </div>
                    <Skeleton className="mt-3 h-3 w-56"/>
                    <Skeleton className="mt-2 h-3 w-48"/>
                </div>
            </div>
        </div>;
}
