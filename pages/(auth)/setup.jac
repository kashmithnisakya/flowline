"""standup - Onboarding wizard: you -> project -> people -> workflow.

Signup takes credentials only, so the wizard opens by naming the
organization and its project manager, then the first project and the
roster. Finishing hands over to the workflow designer, where the org draws
how its work moves. Any half-typed member is saved by the finish button;
typed input is never silently discarded.

The wizard resumes where it stopped: an account with no organization name
starts at step 1, one that has a name but no project starts at step 2.
"""

import from ...models { MemberView }
import from ...walkers.projects { ListProjects, SaveProject }
import from ...walkers.roster { SaveMember }
import from ...lib.session { fetchProfile, patchProfile }
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

def:pub SetupPage -> JsxPage {
    has step: int = 0,
        orgName: str = "",
        fullName: str = "",
        projectName: str = "",
        mName: str = "",
        mRole: str = "",
        added: list[MemberView] = [],
        saveError: str = "",
        busy: bool = False;

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def saveProfile -> None;
    async def createProject -> None;
    async def addPerson -> None;
    async def finish -> None;

    return
        <div className="mx-auto flex min-h-[70svh] max-w-lg items-center">
            {if step == 0 {
                <p
                    key="loading"
                    className="w-full text-center text-sm text-muted-foreground"
                >
                    Loading…
                </p>
            } elif step == 1 {
                <Card key="profile" className="w-full">
                    <CardHeader>
                        <CardTitle>Name your workspace</CardTitle>
                        <CardDescription>
                            Step 1 of 3: the organization name heads every page, and your name is who the daily log is written by. Both stay editable on the Workspace tab.
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-4">
                        <div className="grid gap-2">
                            <Label>Organization</Label>
                            <Input
                                value={orgName}
                                onChange={lambda (e: ChangeEvent) { orgName = e.target.value; }}
                                placeholder="Acme Robotics"
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
                            <p key="err" className="text-sm text-destructive">
                                {saveError}
                            </p>
                        }}
                    </CardContent>
                    <CardFooter className="justify-end">
                        <Button
                            onClick={saveProfile}
                            disabled={busy
                                or not orgName.strip()
                                or not fullName.strip()}
                        >
                            Continue
                        </Button>
                    </CardFooter>
                </Card>
            } elif step == 2 {
                <Card key="project" className="w-full">
                    <CardHeader>
                        <CardTitle>
                            {"Welcome to " + orgName
                                if orgName
                                else "Create your first project"}
                        </CardTitle>
                        <CardDescription>
                            Step 2 of 3: tasks and daily logs are scoped to projects.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="grid gap-2">
                            <Label>Project name</Label>
                            <Input
                                value={projectName}
                                onChange={lambda (e: ChangeEvent) { projectName = e.target.value; }}
                                placeholder="Website redesign"
                            />
                        </div>
                    </CardContent>
                    <CardFooter className="justify-end">
                        <Button
                            onClick={createProject}
                            disabled={busy or not projectName.strip()}
                        >
                            Continue
                        </Button>
                    </CardFooter>
                </Card>
            } else {
                <Card key="people" className="w-full">
                    <CardHeader>
                        <CardTitle>Add your people</CardTitle>
                        <CardDescription>
                            Step 3 of 3: team members are roster records (no accounts). You can add more any time on the Workspace tab.
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-4">
                        <div className="flex gap-2">
                            <Input
                                placeholder="Name"
                                value={mName}
                                onChange={lambda (e: ChangeEvent) { mName = e.target.value; }}
                            />
                            <Input
                                placeholder="Role (optional)"
                                value={mRole}
                                onChange={lambda (e: ChangeEvent) { mRole = e.target.value; }}
                            />
                            <Button
                                variant="outline"
                                onClick={addPerson}
                                disabled={busy or not mName.strip()}
                            >
                                Add
                            </Button>
                        </div>
                        {if len(added) > 0 {
                            <div key="added" className="flex flex-wrap gap-1">
                                {for m in added {
                                    <Badge key={m.id} variant="secondary">
                                        {m.name}
                                    </Badge>
                                }}
                            </div>
                        }}
                    </CardContent>
                    <CardFooter className="justify-end">
                        <Button onClick={finish} disabled={busy}>
                            Design your workflow
                        </Button>
                    </CardFooter>
                </Card>
            }   }
        </div>;
}
