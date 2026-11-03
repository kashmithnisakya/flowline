"""The Tasks section of a step's sheet: its count and scope, a loading frame, the
rows, or the plain word that nothing is there. The list grows a page on demand."""

import from ...models { TaskRow }
import from .StepTaskRow { StepTaskRow }
import from ..ui.skeleton { Skeleton }

def:pub StepTaskList(
    tasks: list[TaskRow],
    count: int,
    loading: bool,
    scope: str,
    today: str,
    hasMore: bool = False,
    loadingMore: bool = False,
    onMore: Callable[[], None] = None,
    onOpenTask: Callable[[str], None] = None
) -> JsxElement {
    moreText = "Show more (" + str(len(tasks)) + " of " + str(count) + ")";
    return
        <section aria-label="Tasks on this step" className="flex flex-col">
            <div className="mb-1.5 flex items-baseline gap-1.5">
                <h3 className="text-[13px] font-semibold">Tasks</h3>
                <span className="meta min-w-0 truncate">{scope}</span>
                <span className="num ml-auto text-xs text-text-tertiary">
                    {"" if loading else str(count)}
                </span>
            </div>
            {if loading {
                <div key="loading" className="flex flex-col">
                    {for w in ["w-3/5", "w-1/2", "w-2/3"] {
                        <div key={w} className="flex min-h-9 items-center">
                            <Skeleton className={"h-3.5 " + w}/>
                        </div>
                    }}
                </div>
            } elif len(tasks) == 0 {
                <p key="empty" className="py-2 text-[13px] text-text-secondary">
                    Nothing is sitting on this step.
                </p>
            } else {
                <ul key="rows" className="flex flex-col">
                    {for t in tasks {
                        <li key={t.id}>
                            <StepTaskRow task={t} today={today} onOpen={onOpenTask}/>
                        </li>
                    }}
                    {if hasMore or loadingMore {
                        <li key="more" className="pt-1.5">
                            <button
                                type="button"
                                disabled={loadingMore}
                                className="num w-full rounded-md py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary disabled:opacity-60"
                                onClick={lambda { if onMore { onMore(); }}}
                            >
                                {"Loading" if loadingMore else moreText}
                            </button>
                        </li>
                    }}
                </ul>
            }  }
        </section>;
}
