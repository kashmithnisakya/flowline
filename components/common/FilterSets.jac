"""The board's saved filters: a menu beside the title that names what is on
screen (a saved set, that set marked edited, or a custom or empty view),
switches between the sets, and saves, renames or deletes one. Its writes go
straight to their walkers; the board owns the filters themselves."""

import from "sonner" { toast }
import from ...models { MemberView, FilterSetView }
import from ...services.filters.filters { SaveFilterSet, DeleteFilterSet }
import from ...lib.filters { filterKey, filterSummary }
import from ...lib.workspace { forgetWorkspace }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuRadioGroup,
    DropdownMenuRadioItem,
    DropdownMenuItem,
    DropdownMenuSeparator
}
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..workspace.ConfirmDialog { ConfirmDialog }
import from .ErrorNote { ErrorNote }
import from .glyphs { Spinner }

glob NAME_MAX: int = 60;

def Bookmark(filled: bool) -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0"
        >
            <path
                d="M4.5 2.5h7v11L8 10.75 4.5 13.5z"
                fill={"currentColor" if filled else "none"}
                stroke="currentColor"
                strokeWidth={1.5}
                strokeLinejoin="round"
            />
        </svg>;
}

def Chevron -> JsxElement {
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0 opacity-80"
        >
            <path
                d="m4.5 6.5 3.5 3.5 3.5-3.5"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}

def:pub FilterSetMenu(
    sets: list[FilterSetView],
    activeId: str,
    filters: dict[str, str],
    members: list[MemberView],
    onApply: Callable[[FilterSetView], None],
    onAll: Callable[[], None],
    onSaved: Callable[[FilterSetView], None],
    onDeleted: Callable[[str], None],
    # The first load: no sets yet, so the trigger names what this browser saw.
    loading: bool = False,
    lastName: str = ""
) -> JsxElement {
    # `naming` is "new" or "rename" while the name dialog is open; the set a
    # rename or delete acts on is held by id from the moment it is asked for.
    # `asked` is the dialog an item asked for, opened once the menu has closed
    # and handed focus back to its trigger (earlier, the menu's unmount pulls
    # focus out of the dialog, and closing the dialog has nowhere to return).
    has asked: str = "",
        naming: str = "",
        draft: str = "",
        problem: str = "",
        busy: bool = False,
        targetId: str = "",
        confirming: bool = False;

    nowKey = filterKey(filters);

    def same(s: FilterSetView) -> bool {
        return filterKey(s.filters) == nowKey;
    }
    # The set the filters came from, and the set they equal right now (that
    # one first, else any set with the same filters).
    active: any = None;
    for s in sets {
        if s.id == activeId {
            active = s;
        }
    }
    shown: any = None;
    if active and same(active) {
        shown = active;
    }
    if not shown and nowKey {
        for s in sets {
            if not shown and same(s) {
                shown = s;
            }
        }
    }
    edited = bool(active) and not shown;
    target: any = shown or active;
    label = "All tasks";
    if shown {
        label = shown.name;
    } elif active {
        label = active.name;
    } elif loading and lastName {
        label = lastName;
    } elif nowKey {
        label = "Filtered";
    }
    picked = shown.id if shown else ("all" if not nowKey else "");
    targetName = target.name if target else "";
    held: any = None;
    for s in sets {
        if s.id == targetId {
            held = s;
        }
    }

    def pick(value: str) {
        if value == "all" {
            onAll();
            return;
        }
        for s in sets {
            if s.id == value {
                onApply(s);
            }
        }
    }

    def ask(kind: str) {
        targetId = target.id if target else "";
        asked = kind;
    }

    def openAsked(e: any) {
        kind = asked;
        asked = "";
        if kind == "new" or kind == "rename" {
            draft = targetName if kind == "rename" else "";
            problem = "";
            window.setTimeout(lambda { naming = kind; }, 0);
        } elif kind == "delete" {
            window.setTimeout(lambda { confirming = True; }, 0);
        }
    }

    def closeNaming(o: bool) {
        if not o and not busy {
            naming = "";
        }
    }

    # One SaveFilterSet for a new set, a rename and "save changes": the
    # reported set goes to the page, a refusal to the dialog (or a toast).
    async def save(setId: str, name: str, values: dict[str, str], note: str) -> bool {
        busy = True;
        problem = "";
        ok = False;
        try {
            result = root spawn SaveFilterSet(
                set_id=setId, name=name, page="board", filters=values
            );
            payload: any = result.reports[0] if result.reports else None;
            if payload and payload["ok"] {
                forgetWorkspace();
                onSaved(payload["set"]);
                if note {
                    toast.success(note);
                }
                ok = True;
            } else {
                problem = payload["message"]
                    if payload
                    else "Could not save the filters.";
            }
        } except Exception as e {
            problem = "Could not save the filters.";
        }
        busy = False;
        return ok;
    }

    async def submit(e: FormEvent) {
        e.preventDefault();
        name = draft.strip();
        if not name or busy {
            return;
        }
        done = False;
        if naming == "rename" and held {
            done = await save(held.id, name, held.filters, "");
        } else {
            done = await save("", name, filters, "Saved as “" + name + "”");
        }
        if done {
            naming = "";
        }
    }

    async def saveChanges {
        if not active {
            return;
        }
        done = await save(
            active.id, active.name, filters, "Updated “" + active.name + "”"
        );
        if not done {
            toast.error(problem or "Could not save the filters.");
        }
    }

    async def remove {
        gone = targetId;
        busy = True;
        try {
            result = root spawn DeleteFilterSet(set_id=gone);
            payload: any = result.reports[0] if result.reports else None;
            if payload and payload["ok"] {
                forgetWorkspace();
                onDeleted(gone);
                confirming = False;
            } else {
                toast.error("Could not delete the saved filters");
            }
        } except Exception as e {
            toast.error("Could not delete the saved filters");
        }
        busy = False;
    }

    def summaryOf(values: dict[str, str]) -> str {
        return filterSummary(values, members);
    }

    namingNote = (
        "Saves the board's filters: "
        + summaryOf(filters)
        + ". The title search is not saved."
    );
    if naming == "rename" and held {
        namingNote = "Keeps its filters: " + summaryOf(held.filters) + ".";
    }

    return
        <>
            <DropdownMenu modal={False}>
                <DropdownMenuTrigger
                    disabled={loading}
                    data-active={"true" if shown or edited else None}
                    aria-label={"Saved filters: "
                        + label
                        + (", edited" if edited else "")}
                    className="toolbar-filter h-8! max-w-[min(20rem,48vw)] gap-1.5! px-2! text-[13.5px]! disabled:opacity-100"
                >
                    <Bookmark filled={bool(shown) or edited}/>
                    <span className="truncate">{label}</span>
                    {if edited {
                        <span
                            key="edited"
                            className="shrink-0 text-xs font-normal text-muted-foreground"
                        >
                            edited
                        </span>
                    }}
                    <Chevron/>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                    align="start"
                    collisionPadding={16}
                    className="w-80 max-w-[calc(100vw-2rem)]"
                    onCloseAutoFocus={openAsked}
                >
                    <DropdownMenuLabel
                        className="text-xs font-medium text-muted-foreground"
                    >
                        Saved filters
                    </DropdownMenuLabel>
                    <DropdownMenuRadioGroup value={picked} onValueChange={pick}>
                        <DropdownMenuRadioItem value="all">
                            All tasks
                        </DropdownMenuRadioItem>
                        {for s in sets {
                            <DropdownMenuRadioItem
                                key={s.id}
                                value={s.id}
                                className="items-start"
                            >
                                <span className="flex min-w-0 flex-col gap-0.5">
                                    <span className="flex min-w-0 items-center gap-1.5">
                                        <span className="truncate">{s.name}</span>
                                        {if edited and s.id == activeId {
                                            <span
                                                key="edited"
                                                className="shrink-0 text-xs text-muted-foreground"
                                            >
                                                edited
                                            </span>
                                        }}
                                    </span>
                                    <span
                                        className="truncate text-xs text-muted-foreground"
                                    >
                                        {summaryOf(s.filters)}
                                    </span>
                                </span>
                            </DropdownMenuRadioItem>
                        }}
                    </DropdownMenuRadioGroup>
                    <DropdownMenuSeparator/>
                    <DropdownMenuItem
                        disabled={not nowKey}
                        onSelect={lambda { ask("new"); }}
                    >
                        <span className="flex min-w-0 flex-col gap-0.5">
                            <span>Save filters as…</span>
                            {if not nowKey {
                                <span
                                    key="hint"
                                    className="text-xs text-muted-foreground"
                                >
                                    Pick a filter first
                                </span>
                            }}
                        </span>
                    </DropdownMenuItem>
                    {if edited and nowKey {
                        <DropdownMenuItem
                            key="update"
                            onSelect={lambda { saveChanges(); }}
                        >
                            <span className="truncate">
                                {"Save changes to “" + active.name + "”"}
                            </span>
                        </DropdownMenuItem>
                    }}
                    {if target {
                        <DropdownMenuItem
                            key="rename"
                            onSelect={lambda { ask("rename"); }}
                        >
                            <span className="truncate">
                                {"Rename “" + targetName + "”…"}
                            </span>
                        </DropdownMenuItem>
                    }}
                    {if target {
                        <DropdownMenuItem
                            key="delete"
                            variant="destructive"
                            onSelect={lambda { ask("delete"); }}
                        >
                            <span className="truncate">
                                {"Delete “" + targetName + "”…"}
                            </span>
                        </DropdownMenuItem>
                    }}
                </DropdownMenuContent>
            </DropdownMenu>
            <Dialog open={bool(naming)} onOpenChange={closeNaming}>
                <DialogContent className="bg-card p-5 sm:max-w-md">
                    <form className="grid gap-4" onSubmit={submit}>
                        <DialogHeader>
                            <DialogTitle className="section-title">
                                {"Rename saved filters"
                                    if naming == "rename"
                                    else "Save filters"}
                            </DialogTitle>
                            <DialogDescription className="leading-relaxed">
                                {namingNote}
                            </DialogDescription>
                        </DialogHeader>
                        <label className="grid gap-1.5">
                            <span className="text-[13px] font-semibold">Name</span>
                            <Input
                                autoFocus={True}
                                maxLength={NAME_MAX}
                                placeholder="My open work"
                                value={draft}
                                aria-invalid={"true" if problem else None}
                                onChange={lambda (e: ChangeEvent) {
                                    draft = e.target.value;
                                    problem = "";
                                }}
                            />
                        </label>
                        {if problem {
                            <ErrorNote key="problem" message={problem}/>
                        }}
                        <DialogFooter
                            className="mx-0 mb-0 mt-1 border-t-0 bg-transparent p-0"
                        >
                            <Button
                                type="button"
                                variant="outline"
                                disabled={busy}
                                onClick={lambda { naming = ""; }}
                            >
                                Cancel
                            </Button>
                            <Button type="submit" disabled={busy or not draft.strip()}>
                                {if busy {
                                    <Spinner key="sp"/>
                                }}
                                Save
                            </Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
            <ConfirmDialog
                open={confirming}
                title={"Delete “" + (held.name if held else "") + "”?"}
                body="Only the saved name goes. The board keeps the filters it shows now."
                confirmLabel="Delete"
                busy={busy}
                onConfirm={lambda { remove(); }}
                onOpenChange={lambda (o: bool) { if not busy { confirming = o; }}}
            />
        </>;
}
