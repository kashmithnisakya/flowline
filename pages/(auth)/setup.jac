"""flowline - the setup wizard, three steps on one page with no reloads: name
the workspace and first project, add people, choose how work moves. A step
saves only what it owns when it completes; the last one applies the template
and opens the board with the create dialog. Resumes at the first open step.
"""

import from "@jac/runtime" { navigate }
import from ...models { MemberView }
import from ...constants { FLOW_LINE_TEMPLATES }
import from ...services.projects.projects { ListProjects, SaveProject, AssignToProject }
import from ...services.roster.roster { ListMembers, SaveMember }
import from ...services.flowlines.flowlines { ApplyTemplate, GetFlowLine }
import from ...lib.session { fetchProfile, patchProfile }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.glyphs { Spinner, WarnIcon }
import from ...components.common.Avatar { Avatar, AvatarStack }
import from ...components.common.KindGlyph { KindGlyph }
import from ...components.common.StepName { StepName }

glob SCRATCH: str = "scratch",
     FIELD_LABEL: str = "text-[13px] font-semibold",
     HINTS: dict[int, str] = {
         1: "Cards on the board belong to a project. Its columns come from step 3.",
         2: "People you add here can be assigned to cards on this board.",
         3: "The preview follows your choice. The steps are created when you open the board."
     };

# The columns a choice gives the board, or none for a flow line drawn by hand.
def stepsFor(key: str) -> list[dict[str, any]] {
    for t in FLOW_LINE_TEMPLATES {
        if t["key"] == key {
            return t["steps"];
        }
    }
    return [];
}

def FieldError(id: str, message: str) -> JsxElement {
    return
        <p id={id} className="flex items-center gap-1.5 text-xs text-destructive">
            <WarnIcon size={12} className="shrink-0"/>
            {message}
        </p>;
}

def BoardPreview(
    steps: list[dict[str, any]],
    scratch: bool,
    project: str,
    org: str,
    people: list[str]
) -> JsxElement {
    return
        <div className="grid gap-2">
            <div className="flex min-w-0 items-center gap-2 text-[13px]">
                <span
                    className={"truncate font-semibold "
                        + ("" if project else "text-subtle")}
                >
                    {project or "Your first project"}
                </span>
                {if org {
                    <span key="org" className="truncate text-subtle">{"· " + org}</span>
                }}
                {if len(people) > 0 {
                    <span key="people" className="ml-auto shrink-0">
                        <AvatarStack names={people} max={4}/>
                    </span>
                }}
            </div>
            {if scratch {
                <div
                    key="scratch"
                    className="grid min-h-[190px] place-items-center rounded-md border border-dashed border-input bg-card px-6 text-center text-[13px] text-muted-foreground"
                >
                    You draw the steps on the flow line page, and the board's columns follow them.
                </div>
            } else {
                <div
                    key="columns"
                    className="overflow-x-auto rounded-md border bg-card"
                >
                    <div
                        className="grid min-h-[190px] auto-cols-[minmax(108px,1fr)] grid-flow-col"
                    >
                        {for (i, s) in enumerate(steps) {
                            <div
                                key={s["name"]}
                                className="grid content-start gap-2 border-r p-2.5 last:border-r-0"
                            >
                                <StepName
                                    name={s["name"]}
                                    color={s["color"]}
                                    className="text-[12.5px] font-semibold"
                                />
                                {if i == 0 {
                                    <div
                                        key="new"
                                        className="flex h-[30px] items-center rounded-md border border-dashed border-input px-2 text-xs text-subtle"
                                    >
                                        New task
                                    </div>
                                }}
                            </div>
                        }}
                    </div>
                </div>
            } }
        </div>;
}

def:pub SetupPage -> JsxPage {
    has step: int = 0,
        orgName: str = "",
        savedOrg: str = "",
        projectName: str = "",
        projectId: str = "",
        savedProject: str = "",
        orgError: str = "",
        projectError: str = "",
        mFirst: str = "",
        mLast: str = "",
        mRole: str = "",
        firstError: str = "",
        added: list[MemberView] = [],
        choice: str = "simple",
        saveError: str = "",
        busy: bool = False;

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def saveWorkspace(e: FormEvent) -> None;
    async def addPerson -> bool;
    async def submitPerson(e: FormEvent) -> None;
    async def continuePeople -> None;
    def skipPeople -> None;
    async def finish -> None;
    async def submitFinish(e: FormEvent) -> None;
    def pickTemplate(key: str) -> None;
    def radioKey(e: KeyboardEvent, index: int, keys: list[str]) -> None;

    keys: list[str] = [str(t["key"]) for t in FLOW_LINE_TEMPLATES] + [SCRATCH];
    scratch = choice == SCRATCH;
    people: list[str] = [m.name for m in added];

    return
        <div className="mx-auto w-full max-w-[980px] px-4 py-6 sm:px-6 sm:py-12">
            <div
                className="grid overflow-hidden rounded-xl border bg-background md:min-h-[480px] md:grid-cols-2"
            >
                <div
                    className="grid content-start gap-5 border-b bg-card p-5 sm:p-7 md:border-r md:border-b-0"
                >
                    {if step == 0 {
                        <div key="loading" className="grid gap-4" aria-busy="true">
                            <Skeleton className="h-4 w-28"/>
                            <Skeleton className="h-8 w-56"/>
                            <Skeleton className="h-9 w-full"/>
                            <Skeleton className="h-9 w-full"/>
                            <Skeleton className="h-9 w-28"/>
                        </div>
                    } else {
                        <div
                            key="progress"
                            className="flex items-center gap-2 font-mono text-[12.5px] text-subtle"
                        >
                            <span>{"Step " + str(step) + " of 3"}</span>
                            <span className="flex gap-1.5" aria-hidden="true">
                                {for n in [1, 2, 3] {
                                    <i
                                        key={"bar-" + str(n)}
                                        className={"inline-block h-[3px] w-7 rounded-full "
                                            + (
                                                "bg-primary"
                                                    if n <= step
                                                    else "bg-border"
                                            )}
                                    ></i>
                                }}
                            </span>
                        </div>
                    } }
                    {if step == 1 {
                        <form
                            key="workspace"
                            onSubmit={saveWorkspace}
                            noValidate={True}
                            className="grid gap-5"
                        >
                            <h1
                                className="text-2xl leading-tight font-[750] tracking-[-0.01em] [font-stretch:115%]"
                            >
                                Name your workspace
                            </h1>
                            <div className="grid gap-1.5">
                                <Label htmlFor="setup-org" className={FIELD_LABEL}>
                                    Team or company name
                                </Label>
                                <Input
                                    id="setup-org"
                                    value={orgName}
                                    autoComplete="organization"
                                    aria-invalid={orgError != ""}
                                    aria-describedby={"setup-org-error"
                                        if orgError
                                        else None}
                                    onChange={lambda (e: ChangeEvent) {
                                        orgName = e.target.value;
                                        orgError = "";
                                    }}
                                    placeholder="Acme Robotics"
                                    autoFocus={True}
                                    className="h-9"
                                />
                                {if orgError {
                                    <FieldError
                                        key="org-error"
                                        id="setup-org-error"
                                        message={orgError}
                                    />
                                }}
                            </div>
                            <div className="grid gap-1.5">
                                <Label htmlFor="setup-project" className={FIELD_LABEL}>
                                    First project
                                </Label>
                                <Input
                                    id="setup-project"
                                    value={projectName}
                                    aria-invalid={projectError != ""}
                                    aria-describedby={"setup-project-error"
                                        if projectError
                                        else "setup-project-hint"}
                                    onChange={lambda (e: ChangeEvent) {
                                        projectName = e.target.value;
                                        projectError = "";
                                    }}
                                    placeholder="Website redesign"
                                    className="h-9"
                                />
                                {if projectError {
                                    <FieldError
                                        key="project-error"
                                        id="setup-project-error"
                                        message={projectError}
                                    />
                                } else {
                                    <p
                                        key="project-hint"
                                        id="setup-project-hint"
                                        className="text-xs text-subtle"
                                    >
                                        You can add more projects later from Workspace.
                                    </p>
                                } }
                            </div>
                            {if saveError {
                                <p
                                    key="err"
                                    role="alert"
                                    className="text-sm text-destructive"
                                >
                                    {saveError}
                                </p>
                            }}
                            <div className="flex flex-wrap items-center gap-3">
                                <Button
                                    type="submit"
                                    disabled={busy}
                                    className="h-10 w-full px-4 font-semibold sm:h-9 sm:w-auto"
                                >
                                    {if busy {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Saving…" if busy else "Continue"}
                                </Button>
                                <span className="hidden text-xs text-subtle sm:inline">
                                    {"or press "}
                                    <span className="kbd">Enter</span>
                                </span>
                            </div>
                        </form>
                    } elif step == 2 {
                        <div key="people" className="grid gap-5">
                            <div className="grid gap-2">
                                <h1
                                    className="text-2xl leading-tight font-[750] tracking-[-0.01em] [font-stretch:115%]"
                                >
                                    {"Who works on "
                                        + (projectName.strip() or "this project")
                                        + "?"}
                                </h1>
                                <p className="text-sm text-muted-foreground">
                                    Add people now or skip. They appear as assignees; nobody gets an email or an account.
                                </p>
                            </div>
                            <form
                                onSubmit={submitPerson}
                                noValidate={True}
                                className="grid gap-2 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]"
                            >
                                <div className="grid gap-1.5">
                                    <Label
                                        htmlFor="setup-first"
                                        className={FIELD_LABEL}
                                    >
                                        First name
                                    </Label>
                                    <Input
                                        id="setup-first"
                                        value={mFirst}
                                        autoComplete="off"
                                        aria-invalid={firstError != ""}
                                        aria-describedby={"setup-first-error"
                                            if firstError
                                            else None}
                                        onChange={lambda (e: ChangeEvent) {
                                            mFirst = e.target.value;
                                            firstError = "";
                                        }}
                                        placeholder="First name"
                                        autoFocus={True}
                                        className="h-9"
                                    />
                                </div>
                                <div className="grid gap-1.5">
                                    <Label htmlFor="setup-last" className={FIELD_LABEL}>
                                        Last name
                                    </Label>
                                    <Input
                                        id="setup-last"
                                        value={mLast}
                                        autoComplete="off"
                                        onChange={lambda (e: ChangeEvent) { mLast = e.target.value; }}
                                        placeholder="Last name"
                                        className="h-9"
                                    />
                                </div>
                                {if firstError {
                                    <div key="first-error" className="sm:col-span-2">
                                        <FieldError
                                            id="setup-first-error"
                                            message={firstError}
                                        />
                                    </div>
                                }}
                                <div className="grid gap-1.5">
                                    <Label htmlFor="setup-role" className={FIELD_LABEL}>
                                        {"Role "}
                                        <span className="font-normal text-subtle">
                                            (optional)
                                        </span>
                                    </Label>
                                    <Input
                                        id="setup-role"
                                        value={mRole}
                                        autoComplete="off"
                                        onChange={lambda (e: ChangeEvent) { mRole = e.target.value; }}
                                        placeholder="Builder"
                                        className="h-9"
                                    />
                                </div>
                                <div className="flex items-end">
                                    <Button
                                        type="submit"
                                        variant="outline"
                                        disabled={busy}
                                        className="h-9 w-full px-4 font-semibold sm:w-auto"
                                    >
                                        {if busy {
                                            <Spinner key="sp"/>
                                        }}
                                        Add
                                    </Button>
                                </div>
                            </form>
                            {if saveError {
                                <p
                                    key="err"
                                    role="alert"
                                    className="text-sm text-destructive"
                                >
                                    {saveError}
                                </p>
                            }}
                            {if len(added) > 0 {
                                <ul
                                    key="added"
                                    aria-label="People added"
                                    className="grid gap-2 border-t pt-4 text-[13.5px]"
                                >
                                    {for m in added {
                                        <li
                                            key={m.id}
                                            className="flex min-w-0 items-center gap-2"
                                        >
                                            <Avatar name={m.name} size="xs"/>
                                            <span className="truncate font-medium">
                                                {m.name}
                                            </span>
                                            {if len(m.roles) > 0 {
                                                <span
                                                    key="roles"
                                                    className="truncate text-subtle"
                                                >
                                                    {", ".join(m.roles)}
                                                </span>
                                            }}
                                        </li>
                                    }}
                                </ul>
                            } else {
                                <p
                                    key="nobody"
                                    className="border-t pt-4 text-[13px] text-subtle"
                                >
                                    Nobody yet. People you add appear here.
                                </p>
                            } }
                            <div className="flex flex-wrap items-center gap-2">
                                <Button
                                    type="button"
                                    disabled={busy}
                                    className="h-10 w-full px-4 font-semibold sm:h-9 sm:w-auto"
                                    onClick={continuePeople}
                                >
                                    Continue
                                </Button>
                                <Button
                                    type="button"
                                    variant="ghost"
                                    disabled={busy}
                                    className="h-10 w-full px-3 text-muted-foreground sm:h-9 sm:w-auto"
                                    onClick={skipPeople}
                                >
                                    Skip for now
                                </Button>
                            </div>
                        </div>
                    } elif step == 3 {
                        <form
                            key="flow"
                            onSubmit={submitFinish}
                            noValidate={True}
                            className="grid gap-5"
                        >
                            <div className="grid gap-2">
                                <h1
                                    className="text-2xl leading-tight font-[750] tracking-[-0.01em] [font-stretch:115%]"
                                >
                                    How does work move?
                                </h1>
                                <p className="text-sm text-muted-foreground">
                                    Pick a starting point. The steps become your board's columns, and you can redraw them any time.
                                </p>
                            </div>
                            <div
                                role="radiogroup"
                                aria-label="How work moves"
                                className="grid gap-2"
                            >
                                {for (i, t) in enumerate(FLOW_LINE_TEMPLATES) {
                                    <button
                                        key={t["key"]}
                                        id={"tpl-" + str(t["key"])}
                                        type="button"
                                        role="radio"
                                        aria-checked={choice == t["key"]}
                                        tabIndex={0 if choice == t["key"] else -1}
                                        autoFocus={choice == t["key"]}
                                        onClick={lambda { pickTemplate(t["key"]); }}
                                        onKeyDown={lambda (e: KeyboardEvent) { radioKey(
                                            e, i, keys
                                        ); }}
                                        className={"grid gap-2 rounded-md border bg-card px-3.5 py-3 text-left transition-colors duration-150 "
                                            + (
                                                "border-primary ring-1 ring-primary"
                                                    if choice == t["key"]
                                                    else "hover:border-input"
                                            )}
                                    >
                                        <span
                                            className="flex items-center gap-2 text-sm font-semibold"
                                        >
                                            <KindGlyph
                                                kind={"done"
                                                    if choice == t["key"]
                                                    else "start"}
                                                className={"text-primary"
                                                    if choice == t["key"]
                                                    else "text-subtle"}
                                            />
                                            {t["name"]}
                                            {if i == 0 {
                                                <span
                                                    key="rec"
                                                    className="ml-auto text-xs font-medium text-success"
                                                >
                                                    Recommended
                                                </span>
                                            }}
                                        </span>
                                        <span
                                            className="flex flex-wrap gap-x-3 gap-y-1 text-[12.5px] text-muted-foreground"
                                        >
                                            {for s in t["steps"] {
                                                <StepName
                                                    key={s["name"]}
                                                    name={s["name"]}
                                                    color={s["color"]}
                                                />
                                            }}
                                        </span>
                                        <span className="text-xs text-subtle">
                                            {t["description"]}
                                        </span>
                                    </button>
                                }}
                                <button
                                    key={SCRATCH}
                                    id={"tpl-" + SCRATCH}
                                    type="button"
                                    role="radio"
                                    aria-checked={scratch}
                                    tabIndex={0 if scratch else -1}
                                    autoFocus={scratch}
                                    onClick={lambda { pickTemplate(SCRATCH); }}
                                    onKeyDown={lambda (e: KeyboardEvent) { radioKey(
                                        e, len(keys) - 1, keys
                                    ); }}
                                    className={"grid gap-2 rounded-md border bg-card px-3.5 py-3 text-left transition-colors duration-150 "
                                        + (
                                            "border-primary ring-1 ring-primary"
                                                if scratch
                                                else "hover:border-input"
                                        )}
                                >
                                    <span
                                        className="flex items-center gap-2 text-sm font-semibold"
                                    >
                                        <KindGlyph
                                            kind={"done" if scratch else "start"}
                                            className={"text-primary"
                                                if scratch
                                                else "text-subtle"}
                                        />
                                        Draw my own
                                    </span>
                                    <span
                                        className="text-[12.5px] text-muted-foreground"
                                    >
                                        Opens the flow line designer after setup
                                    </span>
                                </button>
                            </div>
                            {if saveError {
                                <p
                                    key="err"
                                    role="alert"
                                    className="text-sm text-destructive"
                                >
                                    {saveError}
                                </p>
                            }}
                            <div className="flex flex-wrap items-center gap-3">
                                <Button
                                    type="submit"
                                    disabled={busy}
                                    className="h-10 w-full px-4 font-semibold sm:h-9 sm:w-auto"
                                >
                                    {if busy {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Open the designer"
                                        if scratch
                                        else "Open the board"}
                                    <svg
                                        width={14}
                                        height={14}
                                        viewBox="0 0 16 16"
                                        aria-hidden="true"
                                    >
                                        <path
                                            d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={1.6}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        />
                                    </svg>
                                </Button>
                                <span className="text-xs text-subtle">
                                    {"Draw the steps, then the board follows them."
                                        if scratch
                                        else "Your first task opens ready to type."}
                                </span>
                            </div>
                        </form>
                    }  }
                </div>
                <aside
                    aria-label="Preview of your board"
                    className="grid content-start gap-3 p-5 sm:p-7"
                >
                    <p className="font-mono text-xs text-subtle">
                        Preview of your board
                    </p>
                    <BoardPreview
                        steps={stepsFor(choice)}
                        scratch={scratch}
                        project={projectName.strip()}
                        org={orgName.strip()}
                        people={people}
                    />
                    {if step > 0 {
                        <p key="hint" className="text-xs text-subtle">{HINTS[step]}</p>
                    }}
                </aside>
            </div>
        </div>;
}
