"""The task dialog's checklist: add, check, rename and remove, each written at
once through its own walker rather than on Save, so a dialog save can never
clobber it. Mount it keyed by task id; `onChange` gets the task view each
write reports, so the page can refresh its card."""

import from "sonner" { toast }
import from ...models { TaskView }
import from ...services.tasks.tasks {
    AddChecklistItem,
    SetChecklistItem,
    RemoveChecklistItem
}
import from ..ui.checkbox { Checkbox }
import from ..ui.input { Input }

def:pub ChecklistEditor(
    taskId: str,
    items: list[dict[str, any]],
    onChange: Callable[[TaskView], None] = None
) -> JsxElement {
    has rows: list[dict[str, any]] = items,
        draft: str = "",
        editId: str = "",
        editText: str = "",
        busy: bool = False;

    # Every write reports the task view; take its checklist and pass it up.
    def absorb(result: any) {
        view: TaskView | None = result.reports[0] if result.reports else None;
        if view {
            rows = view.checklist;
            if onChange {
                onChange(view);
            }
        }
    }

    async def add -> None {
        text = draft.strip();
        if not text or busy {
            return;
        }
        draft = "";
        busy = True;
        try {
            absorb(root spawn AddChecklistItem(task_id=taskId, text=text));
        } except Exception as e {
            toast.error("Could not update the checklist");
        }
        busy = False;
    }

    async def setItem(itemId: str, done: str, text: str) {
        busy = True;
        try {
            absorb(
                root spawn SetChecklistItem(
                    task_id=taskId, item_id=itemId, done=done, text=text
                )
            );
        } except Exception as e {
            toast.error("Could not update the checklist");
        }
        busy = False;
    }

    async def removeItem(itemId: str) {
        busy = True;
        try {
            absorb(root spawn RemoveChecklistItem(task_id=taskId, item_id=itemId));
        } except Exception as e {
            toast.error("Could not update the checklist");
        }
        busy = False;
    }

    # Enter and the blur that follows both land here; only the first renames.
    def rename(itemId: str) {
        if editId != itemId {
            return;
        }
        text = editText.strip();
        editId = "";
        if text {
            setItem(itemId, "", text);
        }
    }

    total = len(rows);
    ticked = 0;
    for item in rows {
        if item["done"] {
            ticked = ticked + 1;
        }
    }
    return
        <section className="grid gap-2" aria-label="Checklist">
            <div className="flex items-baseline justify-between gap-3">
                <h3 className="text-[13px] font-semibold">Checklist</h3>
                {if total > 0 {
                    <span key="count" className="num text-xs text-muted-foreground">
                        {str(ticked) + " of " + str(total) + " done"}
                    </span>
                }}
            </div>
            {if total > 0 {
                <div key="bar" className="h-1.5 overflow-hidden rounded-full bg-muted">
                    <div
                        className="h-full rounded-full bg-success transition-[width]"
                        style={{"width": str(ticked * 100.0 / total) + "%"}}
                    />
                </div>
            }}
            {if total > 0 {
                <ul key="rows" className="border-t">
                    {for item in rows {
                        <li
                            key={item["id"]}
                            className="group flex items-center gap-2.5 border-b py-1"
                        >
                            <Checkbox
                                checked={bool(item["done"])}
                                disabled={busy}
                                aria-label={"Done: " + str(item["text"])}
                                onCheckedChange={lambda (on: bool) { setItem(
                                    item["id"], "yes" if on else "no", ""
                                ); }}
                            />
                            {if editId == item["id"] {
                                <Input
                                    key="edit"
                                    className="h-7 flex-1 text-[13px] md:text-[13px]"
                                    value={editText}
                                    autoFocus={True}
                                    onChange={lambda (e: any) { editText = e.target.value; }}
                                    onBlur={lambda { rename(item["id"]); }}
                                    onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                        == "Enter" {
                                        e.preventDefault();
                                        rename(item["id"]);
                                    }}}
                                />
                            } else {
                                <button
                                    key="text"
                                    type="button"
                                    title="Rename"
                                    className={"min-w-0 flex-1 truncate py-0.5 text-left text-[13px] "
                                        + (
                                            "text-muted-foreground line-through"
                                                if item["done"]
                                                else ""
                                        )}
                                    onClick={lambda {
                                        editId = item["id"];
                                        editText = item["text"];
                                    }}
                                >
                                    {item["text"]}
                                </button>
                            } }
                            <button
                                type="button"
                                aria-label={"Remove " + str(item["text"])}
                                disabled={busy}
                                className="flex size-6 flex-none items-center justify-center rounded-sm text-muted-foreground opacity-0 transition-opacity duration-150 hover:bg-accent hover:text-foreground focus-visible:opacity-100 group-hover:opacity-100 pointer-coarse:opacity-100"
                                onClick={lambda { removeItem(item["id"]); }}
                            >
                                <svg
                                    width={14}
                                    height={14}
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth={2}
                                    strokeLinecap="round"
                                    aria-hidden="true"
                                >
                                    <path d="M18 6 6 18"/>
                                    <path d="m6 6 12 12"/>
                                </svg>
                            </button>
                        </li>
                    }}
                </ul>
            }}
            <Input
                className="h-8 text-[13px] md:text-[13px]"
                placeholder={"Add an item, Enter to save"
                    if total < 50
                    else "The checklist is full (50 items)"}
                value={draft}
                disabled={total >= 50}
                onChange={lambda (e: any) { draft = e.target.value; }}
                onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                    e.preventDefault();
                    add();
                }}}
            />
        </section>;
}
