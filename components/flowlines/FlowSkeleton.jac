"""The flow line's first-load frame: three step cards on a wire and a skeleton
key row, in the frame the loaded diagram will take. `canvasH` is the page's
canvas height; `showKey` is off for the phone's step list."""

import from ..ui.skeleton { Skeleton }

def:pub FlowSkeleton(canvasH: str, showKey: bool = True) -> JsxElement {
    return
        <div className="surface flex min-w-0 flex-col overflow-hidden rounded-xl">
            <div className="relative min-w-0" style={{"height": canvasH}}>
                <div className="absolute inset-0 flex items-center justify-center px-6">
                    {for i in range(3) {
                        <div key={"n" + str(i)} className="flex items-center">
                            {if i > 0 {
                                <span
                                    key="w"
                                    aria-hidden="true"
                                    className="h-0.5 w-8 shrink-0 bg-wire sm:w-16"
                                />
                            }}
                            <div
                                className="flex h-[74px] w-[150px] shrink-0 flex-col justify-center gap-2 rounded-xl border border-border-strong bg-card px-3"
                            >
                                <Skeleton className="h-3.5 w-20"/>
                                <Skeleton className="h-3 w-24"/>
                                <Skeleton className="h-3 w-12"/>
                            </div>
                        </div>
                    }}
                </div>
            </div>
            {if showKey {
                <div
                    key="legend"
                    aria-label="Key"
                    className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1.5 border-t bg-card px-4 py-2"
                >
                    {for i in range(4) {
                        <span
                            key={"k" + str(i)}
                            className="inline-flex h-[18px] items-center gap-1.5"
                        >
                            <Skeleton className="size-3.5 rounded-full"/>
                            <Skeleton className="h-3 w-12"/>
                        </span>
                    }}
                    <span className="ml-auto inline-flex h-6 items-center">
                        <Skeleton className="h-3 w-44"/>
                    </span>
                </div>
            }}
        </div>;
}
