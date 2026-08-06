"""standup - Onboarding wizard: you -> project -> vocabulary -> people.

Signup takes credentials only, so the wizard opens by naming the
organization and its project manager, then the first project, the workspace
vocabulary (categories and tags), and the roster. Finishing lands on the
board. Any half-typed member is saved by the finish button; typed input is
never silently discarded.

The wizard resumes where it stopped: an account with no organization name
starts at step 1, one that has a name but no project starts at step 2.
"""

import from ...models { MemberView }
import from ...walkers.projects { ListProjects, SaveProject }
import from ...walkers.roster { SaveMember }
import from ...walkers.vocab { AddVocab }
import from ...lib.session { fetchProfile, patchProfile }
import from ...components.ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.ui.badge { Badge }

# Tap-to-keep suggestions; nothing is created unless picked.
glob SUGGESTED_CATEGORIES: list[str] = ["Coding", "Review", "Planning", "Meetings"];

def:pub SetupPage() -> JsxPage {
    has step: int = 0,
        orgName: str = "",
        fullName: str = "",
        projectName: str = "",
        pickedCategories: list[str] = [],
        newCategory: str = "",
        newTag: str = "",
        pickedTags: list[str] = [],
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
    async def saveVocabulary -> None;
    async def addPerson -> None;
    async def finish -> None;
    def toggleCategory(value: str) -> None;
    def addCategory -> None;
    def addTag -> None;

    return <div className="mx-auto flex min-h-[70svh] max-w-lg items-center">
        {if step == 0 {
            <p key="loading" className="w-full text-center text-sm text-muted-foreground">Loading…</p>
        } elif step == 1 {
            <Card key="profile" className="w-full">
                <CardHeader>
                    <CardTitle>Name your workspace</CardTitle>
                    <CardDescription>
                        Step 1 of 4: the organization name heads every page, and your
                        name is who the daily log is written by. Both stay editable
                        on the Workspace tab.
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
                        <p key="err" className="text-sm text-destructive">{saveError}</p>
                    }}
                </CardContent>
                <CardFooter className="justify-end">
                    <Button
                        onClick={saveProfile}
                        disabled={busy or not orgName.strip() or not fullName.strip()}
                    >
                        Continue
                    </Button>
                </CardFooter>
            </Card>
        } elif step == 2 {
            <Card key="project" className="w-full">
                <CardHeader>
                    <CardTitle>
                        {"Welcome to " + orgName if orgName else "Create your first project"}
                    </CardTitle>
                    <CardDescription>
                        Step 2 of 4: tasks and daily logs are scoped to projects.
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
                    <Button onClick={createProject} disabled={busy or not projectName.strip()}>
                        Continue
                    </Button>
                </CardFooter>
            </Card>
        } elif step == 3 {
            <Card key="vocab" className="w-full">
                <CardHeader>
                    <CardTitle>Your vocabulary</CardTitle>
                    <CardDescription>
                        Step 3 of 4: categories label the work (board and log dropdowns);
                        tags label your people. Both stay editable on the Workspace tab.
                    </CardDescription>
                </CardHeader>
                <CardContent className="grid gap-5">
                    <div className="grid gap-2">
                        <Label>Categories</Label>
                        <div className="flex flex-wrap gap-1.5">
                            {for c in SUGGESTED_CATEGORIES {
                                <Badge
                                    key={c}
                                    variant={"default" if c in pickedCategories else "outline"}
                                    className="cursor-pointer"
                                    onClick={lambda { toggleCategory(c); }}
                                >
                                    {c}
                                </Badge>
                            }}
                            {for c in pickedCategories {
                                if c not in SUGGESTED_CATEGORIES {
                                    <Badge
                                        key={c}
                                        variant="default"
                                        className="cursor-pointer"
                                        onClick={lambda { toggleCategory(c); }}
                                    >
                                        {c} ✕
                                    </Badge>
                                }
                            }}
                        </div>
                        <div className="flex gap-2">
                            <Input
                                placeholder="Add your own"
                                className="h-8"
                                value={newCategory}
                                onChange={lambda (e: ChangeEvent) { newCategory = e.target.value; }}
                                onKeyDown={lambda (e: KeyboardEvent) {
                                    if e.key == "Enter" { addCategory(); }
                                }}
                            />
                            <Button variant="outline" size="sm" onClick={addCategory} disabled={not newCategory.strip()}>
                                Add
                            </Button>
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>Tags (optional)</Label>
                        <div className="flex flex-wrap gap-1.5">
                            {for t in pickedTags {
                                <Badge key={t} variant="default" className="cursor-pointer">
                                    {t}
                                </Badge>
                            }}
                        </div>
                        <div className="flex gap-2">
                            <Input
                                placeholder="Frontend, Infra, Design…"
                                className="h-8"
                                value={newTag}
                                onChange={lambda (e: ChangeEvent) { newTag = e.target.value; }}
                                onKeyDown={lambda (e: KeyboardEvent) {
                                    if e.key == "Enter" { addTag(); }
                                }}
                            />
                            <Button variant="outline" size="sm" onClick={addTag} disabled={not newTag.strip()}>
                                Add
                            </Button>
                        </div>
                    </div>
                </CardContent>
                <CardFooter className="justify-end">
                    <Button onClick={saveVocabulary} disabled={busy}>
                        Continue
                    </Button>
                </CardFooter>
            </Card>
        } else {
            <Card key="people" className="w-full">
                <CardHeader>
                    <CardTitle>Add your people</CardTitle>
                    <CardDescription>
                        Step 4 of 4: team members are roster records (no accounts).
                        You can add more any time on the Workspace tab.
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
                    <Button onClick={finish} disabled={busy}>
                        Design your workflow
                    </Button>
                </CardFooter>
            </Card>
        }}
    </div>;
}
