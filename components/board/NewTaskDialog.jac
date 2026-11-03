"""The new-task dialog: a title, notes and chips for where it lands and who has
it, the rest behind More. Create another keeps the dialog open on a blank form,
and Describe it to Ask hands the job to the assistant."""

import from ...models { Project, MemberView }
import from ..ui.dialog { Dialog, DialogContent, DialogTitle, DialogDescription }
import from ..ui.switch { Switch }
import from ..ui.button { Button }
import from ..common.AiMark { AiMark }
import from ..common.glyphs { Spinner }
import from .sheet.NewTaskChips { NewTaskChips }
import from .sheet.NewTaskMore { NewTaskMore }

def:pub NewTaskDialog(
    open: bool,
    form: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    saving: bool,
    columnKeys: list[str],
    columnLabels: list[str],
    colors: list[str],
    assignees: list[str],
    categories: list[str],
    onField: Callable[[str, str], None],
    onToggleAssignee: Callable[[str], None],
    onOpenChange: Callable[[bool], None],
    onCreate: Callable[[bool], None]
) -> JsxElement {
    has another: bool = False,
        more: bool = False;

    canSave = not saving and bool(form["title"].strip()) and bool(form["project"]);

    def create {
        if canSave {
            onCreate(another);
        }
    }

    def askInstead {
        w: any = window;
        onOpenChange(False);
        w.dispatchEvent(new(w.CustomEvent, "flowline:ask", {"detail": {}}));
    }

    def onKeys(e: KeyboardEvent) {
        if e.key == "Enter" and (e.metaKey or e.ctrlKey) {
            e.preventDefault();
            create();
        }
    }

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent
                data-new-task="true"
                className="top-[12%] translate-y-0 gap-0 bg-popover p-0 sm:max-w-[640px]"
                onKeyDown={onKeys}
                onOpenAutoFocus={lambda (e: Event) {
                    e.preventDefault();
                    field: any = document.querySelector("[data-task-title]");
                    if field {
                        field.focus();
                    }
                }}
            >
                <DialogTitle className="sr-only">New task</DialogTitle>
                <DialogDescription className="sr-only">
                    A title, and where the task lands.
                </DialogDescription>
                <div className="flex flex-col gap-2.5 px-5 pt-5 pb-3.5">
                    <input
                        data-task-title="true"
                        aria-label="Title"
                        placeholder="What needs doing?"
                        className="w-full bg-transparent text-[20px] leading-snug font-semibold outline-none placeholder:text-subtle focus-visible:outline-none"
                        value={form["title"]}
                        onChange={lambda (e: ChangeEvent) { onField(
                            "title", e.target.value
                        ); }}
                        onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter"
                            and not e.isComposing {
                            e.preventDefault();
                            create();
                        }}}
                    />
                    <textarea
                        rows={3}
                        aria-label="Notes"
                        placeholder="Add notes, acceptance criteria or links. Markdown works."
                        className="w-full resize-none bg-transparent text-[13.5px] outline-none placeholder:text-subtle focus-visible:outline-none"
                        value={form["notes"]}
                        onChange={lambda (e: ChangeEvent) { onField(
                            "notes", e.target.value
                        ); }}
                    />
                    <NewTaskChips
                        form={form}
                        projects={projects}
                        members={members}
                        columnKeys={columnKeys}
                        columnLabels={columnLabels}
                        colors={colors}
                        assignees={assignees}
                        moreOpen={more}
                        onField={onField}
                        onToggleAssignee={onToggleAssignee}
                        onMore={lambda { more = not more; }}
                    />
                    {if more {
                        <NewTaskMore
                            key="more"
                            form={form}
                            categories={categories}
                            onField={onField}
                        />
                    }}
                </div>
                <div className="flex flex-wrap items-center gap-2 border-t px-5 py-3">
                    <button
                        type="button"
                        onClick={lambda { askInstead(); }}
                        className="ai-chip h-[30px]! hover:bg-bg-hover"
                    >
                        <AiMark/>
                        Describe it to Ask
                    </button>
                    <div className="ml-auto flex flex-wrap items-center gap-2">
                        <label
                            className="mr-2 flex items-center gap-2 text-[12.5px] text-text-tertiary"
                        >
                            <Switch
                                size="sm"
                                checked={another}
                                onCheckedChange={lambda (v: bool) { another = v; }}
                            />
                            Create another
                        </label>
                        <Button
                            variant="ghost"
                            onClick={lambda { onOpenChange(False); }}
                        >
                            Cancel
                        </Button>
                        <Button disabled={not canSave} onClick={lambda { create(); }}>
                            {if saving {
                                <Spinner key="sp"/>
                            }}
                            {"Creating…" if saving else "Create task"}
                        </Button>
                    </div>
                </div>
            </DialogContent>
        </Dialog>;
}
