"""standup - Onboarding wizard: organization -> first project -> people.

The Board redirects here when GetMe reports no org; this page sends the PM
to the Board once setup is done, so a fresh account passes through once.
"""

import from ...models { MemberView }
import from ...walkers.org { GetMe, CreateOrganization }
import from ...walkers.projects { ListProjects, SaveProject }
import from ...walkers.roster { SaveMember }
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
    async def createOrg -> None;
    async def createProject -> None;
    async def addPerson -> None;

    <div className="mx-auto flex min-h-[70svh] max-w-lg items-center">
        {if step == 0 {
            <p key="loading" className="w-full text-center text-sm text-muted-foreground">Loading…</p>
        } elif step == 1 {
            <Card key="org" className="w-full">
                <CardHeader>
                    <CardTitle>Welcome! Name your organization</CardTitle>
                    <CardDescription>Step 1 of 3 — this is your private workspace.</CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="grid gap-2">
                        <Label>Organization name</Label>
                        <Input
                            value={orgName}
                            onChange={lambda (e: ChangeEvent) { orgName = e.target.value; }}
                            placeholder="Jaseci Labs"
                        />
                    </div>
                </CardContent>
                <CardFooter className="justify-end">
                    <Button onClick={createOrg} disabled={busy or not orgName.strip()}>
                        Continue
                    </Button>
                </CardFooter>
            </Card>
        } elif step == 2 {
            <Card key="project" className="w-full">
                <CardHeader>
                    <CardTitle>Create your first project</CardTitle>
                    <CardDescription>Step 2 of 3 — tasks and daily logs are scoped to projects.</CardDescription>
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
                        Step 3 of 3 — team members are roster records (no accounts).
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
                    <Button onClick={lambda { window.location.href = "/"; }}>
                        Go to the board
                    </Button>
                </CardFooter>
            </Card>
        }}
    </div>
}
