"""standup - Onboarding wizard: first project -> people.

The organization is created at signup (its name lives in the account
profile), so the wizard starts at the first project. The Board sends a PM
here while they have no projects yet; finishing lands them on the board.
"""

import from ...models { MemberView }
import from ...walkers.projects { ListProjects, SaveProject }
import from ...walkers.roster { SaveMember }
import from ...lib.session { fetchOrgName }
import from ...components.ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.ui.badge { Badge }

def:pub SetupPage() -> JsxPage {
    has step: int = 0,
        orgName: str = "",
        projectName: str = "",
        mName: str = "",
        mRole: str = "",
        added: list[MemberView] = [],
        busy: bool = False;

    async can with entry {
        boot();
    }

    async def boot -> None;
    async def createProject -> None;
    async def addPerson -> None;

    <div className="mx-auto flex min-h-[70svh] max-w-lg items-center">
        {if step == 0 {
            <p key="loading" className="w-full text-center text-sm text-muted-foreground">Loading…</p>
        } elif step == 1 {
            <Card key="project" className="w-full">
                <CardHeader>
                    <CardTitle>
                        {"Welcome to " + orgName if orgName else "Create your first project"}
                    </CardTitle>
                    <CardDescription>
                        Step 1 of 2: tasks and daily logs are scoped to projects.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="grid gap-2">
                        <Label>Project name</Label>
                        <Input
                            value={projectName}
                            onChange={lambda (e: ChangeEvent) { projectName = e.target.value; }}
                            placeholder="Jac Core"
                        />
                    </div>
                </CardContent>
                <CardFooter className="justify-end">
                    <Button onClick={createProject} disabled={busy or not projectName.strip()}>
                        Continue
                    </Button>
                </CardFooter>
            </Card>
        } else {
            <Card key="people" className="w-full">
                <CardHeader>
                    <CardTitle>Add your people</CardTitle>
                    <CardDescription>
                        Step 2 of 2: team members are roster records (no accounts).
                        You can add more any time on the People page.
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
                        <Button variant="outline" onClick={addPerson} disabled={busy or not mName.strip()}>
                            Add
                        </Button>
                    </div>
                    {if len(added) > 0 {
                        <div key="added" className="flex flex-wrap gap-1">
                            {for m in added {
                                <Badge key={m.id} variant="secondary">{m.name}</Badge>
                            }}
                        </div>
                    }}
                </CardContent>
                <CardFooter className="justify-end">
                    <Button onClick={lambda { window.location.href = "/board"; }}>
                        Go to the board
                    </Button>
                </CardFooter>
            </Card>
        }}
    </div>
}
