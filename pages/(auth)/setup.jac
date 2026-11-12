"""flowline - the setup wizard, three steps on one page with no reloads: name the
workspace and first project, add people, choose how work moves. A step saves only
what it owns when it completes; the last one applies the template and opens the
board with the create dialog. Resumes at the first open step.
"""

import from "@jac/runtime" { navigate }
import from ...models { MemberView }
import from ...constants { FLOW_LINE_TEMPLATES }
import from ...services.projects.projects { ListProjects, SaveProject, AssignToProject }
import from ...services.roster.roster { ListMembers, SaveMember }
import from ...services.flowlines.flowlines { ApplyTemplate, GetFlowLine }
import from ...lib.session { fetchProfile, patchProfile }
import from ...lib.workspace { forgetWorkspace }
import from ...components.setup.FlowStep { FlowStep }
import from ...components.setup.PeopleStep { PeopleStep }
import from ...components.setup.SetupProgress { SetupProgress }
import from ...components.setup.TeamStep { TeamStep }
import from ...components.ui.skeleton { Skeleton }

# A skipped step 2 leaves nothing on the server, so this browser remembers per
# project that it was answered and a revisit resumes at step 3.
def rememberPeopleStep(project: str) -> None {
    try {
        localStorage.setItem("flowline-setup-people:" + project, "1");
    } except Exception {
        return;
    }
}

def peopleStepDone(project: str) -> bool {
    try {
        return localStorage.getItem("flowline-setup-people:" + project) == "1";
    } except Exception {
        return False;
    }
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
    def personField(field: str, value: str) -> None;
    def goBack -> None;
    def drawOwn -> None;
    async def finish -> None;
    async def submitFinish(e: FormEvent) -> None;
    def pickTemplate(key: str) -> None;
    def radioKey(e: KeyboardEvent, index: int, keys: list[str]) -> None;

    return
        <div
            className="mx-auto flex w-full max-w-[680px] flex-col gap-8 pt-2 pb-12 sm:pt-6"
        >
            <SetupProgress step={step}/>
            {if step == 0 {
                <div key="loading" className="flex flex-col gap-5" aria-busy="true">
                    <Skeleton className="h-8 w-72 max-w-full"/>
                    <Skeleton className="h-10 w-full"/>
                    <Skeleton className="h-10 w-full"/>
                </div>
            } elif step == 1 {
                <TeamStep
                    key="team"
                    orgName={orgName}
                    projectName={projectName}
                    orgError={orgError}
                    projectError={projectError}
                    saveError={saveError}
                    busy={busy}
                    onOrg={lambda (v: str) {
                        orgName = v;
                        orgError = "";
                    }}
                    onProject={lambda (v: str) {
                        projectName = v;
                        projectError = "";
                    }}
                    onSubmit={saveWorkspace}
                />
            } elif step == 2 {
                <PeopleStep
                    key="people"
                    project={projectName.strip()}
                    added={added}
                    first={mFirst}
                    last={mLast}
                    role={mRole}
                    firstError={firstError}
                    saveError={saveError}
                    busy={busy}
                    onField={personField}
                    onSubmit={submitPerson}
                    onBack={goBack}
                    onSkip={skipPeople}
                    onContinue={continuePeople}
                />
            } elif step == 3 {
                <FlowStep
                    key="flow"
                    choice={choice}
                    keys={[str(t["key"]) for t in FLOW_LINE_TEMPLATES]}
                    saveError={saveError}
                    busy={busy}
                    onPick={pickTemplate}
                    onKey={radioKey}
                    onSubmit={submitFinish}
                    onBack={goBack}
                    onDraw={drawOwn}
                />
            }   }
        </div>;
}
