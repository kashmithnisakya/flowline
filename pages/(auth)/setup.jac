"""flowline - Onboarding wizard: workspace name -> first project -> people ->
flow line designer. Resumes where it stopped (no org name: step 1; no project:
step 2), and the finish button saves any half-typed member. Keyed Cards remount
per step for the entrance animation; `finishing` gives Finish its own spinner."""

import from ...models { MemberView }
import from ...walkers.projects { ListProjects, SaveProject }
import from ...walkers.roster { SaveMember }
import from ...lib.session { fetchProfile, patchProfile }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.ui.card {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.ui.badge { Badge }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.glyphs { Spinner }
import from ...components.common.ErrorNote { ErrorNote }

def:pub SetupPage -> JsxPage {
    has step: int = 0,
        orgName: str = "",
        fullName: str = "",
        projectName: str = "",
        mName: str = "",
        added: list[MemberView] = [],
        saveError: str = "",
        busy: bool = False,
        finishing: bool = False;

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def saveProfile -> None;
    async def createProject -> None;
    async def addPerson -> None;
    async def finish -> None;

    return
        <div className="relative overflow-hidden">
            <KineticGrid
                className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"
            />
            <div
                aria-hidden="true"
                className="bg-glow pointer-events-none absolute inset-0"
            />
            <div
                className="relative z-10 mx-auto flex min-h-[80svh] w-full max-w-lg flex-col justify-center gap-6 py-10"
            >
                {if step == 0 {
                    <div key="stepper-skel" className="grid w-full gap-2">
                        <Skeleton className="h-4 w-24"/>
                        <div className="flex items-center gap-2">
                            <Skeleton className="h-1.5 flex-1 rounded-full"/>
                            <Skeleton className="h-1.5 flex-1 rounded-full"/>
                            <Skeleton className="h-1.5 flex-1 rounded-full"/>
                        </div>
                    </div>
                } else {
                    <div key="stepper" className="grid w-full gap-2">
                        <p
                            className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                        >
                            {"Step "}
                            <span className="tabular-nums text-foreground">{step}</span>
                            {" of 3"}
                        </p>
                        <div className="flex items-center gap-2">
                            {for n in [1, 2, 3] {
                                <div
                                    key={"seg-" + str(n)}
                                    className={"h-1.5 flex-1 rounded-full bg-primary transition-all duration-300"
                                        if n < step
                                        else (
                                            "h-1.5 flex-1 rounded-full bg-primary ring-2 ring-primary/30 ring-offset-2 ring-offset-background transition-all duration-300"
                                                if n == step
                                                else "h-1.5 flex-1 rounded-full bg-muted transition-all duration-300"
                                        )}
                                />
                            }}
                        </div>
                    </div>
                } }
                {if step == 0 {
                    <Card key="loading" className="w-full">
                        <CardHeader>
                            <Skeleton className="h-8 w-56"/>
                            <div className="grid gap-1.5 pt-1">
                                <Skeleton className="h-4 w-full"/>
                                <Skeleton className="h-4 w-2/3"/>
                            </div>
                        </CardHeader>
                        <CardContent className="grid gap-4">
                            <div className="grid gap-2">
                                <Skeleton className="h-4 w-24"/>
                                <Skeleton className="h-8 w-full"/>
                            </div>
                            <div className="grid gap-2">
                                <Skeleton className="h-4 w-20"/>
                                <Skeleton className="h-8 w-full"/>
                            </div>
                        </CardContent>
                        <CardFooter className="justify-end">
                            <Skeleton className="h-8 w-24"/>
                        </CardFooter>
                    </Card>
                } elif step == 1 {
                    <Card
                        key="profile"
                        className="w-full animate-in fade-in slide-in-from-bottom-2 duration-300"
                    >
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                Name your workspace
                            </CardTitle>
                            <CardDescription>
                                The organization name heads every page, and your name is who the daily log is written by. Both stay editable on the Workspace tab.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-4">
                            <div className="grid gap-2">
                                <Label>Organization</Label>
                                <Input
                                    value={orgName}
                                    onChange={lambda (e: ChangeEvent) { orgName = e.target.value; }}
                                    placeholder="Acme Robotics"
                                    autoFocus={True}
                                />
                            </div>
                            <div className="grid gap-2">
                                <Label>Your name</Label>
                                <Input
                                    value={fullName}
                                    onChange={lambda (e: ChangeEvent) { fullName = e.target.value; }}
                                    placeholder="Priya Raman"
                                />
                            </div>
                            {if saveError {
                                <ErrorNote key="err" message={saveError}/>
                            }}
                        </CardContent>
                        <CardFooter className="justify-end">
                            <Button
                                onClick={saveProfile}
                                disabled={busy
                                or not orgName.strip()
                                or not fullName.strip()}
                            >
                                {if busy {
                                    <Spinner key="sp"/>
                                }}
                                {"Saving…" if busy else "Continue"}
                            </Button>
                        </CardFooter>
                    </Card>
                } elif step == 2 {
                    <Card
                        key="project"
                        className="w-full animate-in fade-in slide-in-from-bottom-2 duration-300"
                    >
                        <CardHeader>
                            {if orgName {
                                <p
                                    key="eyebrow"
                                    className="text-xs font-semibold uppercase tracking-wide text-primary"
                                >
                                    {"Welcome to " + orgName}
                                </p>
                            }}
                            <CardTitle className="font-display text-2xl tracking-tight">
                                Create your first project
                            </CardTitle>
                            <CardDescription>
                                Tasks and daily logs are scoped to projects.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-4">
                            <div className="grid gap-2">
                                <Label>Project name</Label>
                                <Input
                                    value={projectName}
                                    onChange={lambda (e: ChangeEvent) { projectName = e.target.value; }}
                                    placeholder="Website redesign"
                                    autoFocus={True}
                                />
                            </div>
                            {if saveError {
                                <ErrorNote key="err" message={saveError}/>
                            }}
                        </CardContent>
                        <CardFooter className="justify-end">
                            <Button
                                onClick={createProject}
                                disabled={busy or not projectName.strip()}
                            >
                                {if busy {
                                    <Spinner key="sp"/>
                                }}
                                {"Creating…" if busy else "Continue"}
                            </Button>
                        </CardFooter>
                    </Card>
                } else {
                    <Card
                        key="people"
                        className="w-full animate-in fade-in slide-in-from-bottom-2 duration-300"
                    >
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                Add your people
                            </CardTitle>
                            <CardDescription>
                                Names only for now: you will pick a flow line next, and assign roles on the Workspace tab. Members are roster records (no accounts).
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-4">
                            <div className="flex flex-col gap-2 sm:flex-row">
                                <Input
                                    placeholder="Name"
                                    value={mName}
                                    onChange={lambda (e: ChangeEvent) { mName = e.target.value; }}
                                    autoFocus={True}
                                />
                                <Button
                                    variant="outline"
                                    onClick={addPerson}
                                    disabled={busy or not mName.strip()}
                                >
                                    {if busy {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Adding…" if busy else "Add"}
                                </Button>
                            </div>
                            {if saveError {
                                <ErrorNote key="err" message={saveError}/>
                            }}
                            {if len(added) > 0 {
                                <div key="added" className="grid gap-2">
                                    <p className="text-xs text-muted-foreground">
                                        <span
                                            className="font-medium tabular-nums text-foreground"
                                        >
                                            {len(added)}
                                        </span>
                                        {" added"}
                                    </p>
                                    <div className="flex flex-wrap gap-2">
                                        {for m in added {
                                            <Badge
                                                key={m.id}
                                                variant="secondary"
                                                className="animate-in zoom-in-95 duration-200"
                                            >
                                                {m.name}
                                            </Badge>
                                        }}
                                    </div>
                                </div>
                            } else {
                                <p key="hint" className="text-xs text-muted-foreground">
                                    People you add appear here.
                                </p>
                            } }
                        </CardContent>
                        <CardFooter className="justify-end">
                            <Button onClick={finish} disabled={busy or finishing}>
                                {if finishing {
                                    <Spinner key="sp"/>
                                }}
                                {"Finishing…" if finishing else "Design your flow line"}
                            </Button>
                        </CardFooter>
                    </Card>
                }   }
            </div>
        </div>;
}
