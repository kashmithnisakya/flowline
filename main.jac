"""flowline - Entry Point. File-based routing: pages/ holds the routes. This
module registers every server endpoint (a walker missing from these imports
404s) and renders the routed children.
"""

import ".styles.global.css";

import from models {
    Project,
    Member,
    Repo,
    Task,
    LogEntry,
    TaskView,
    MemberView,
    GithubConnectionView,
    WorkflowStep,
    WorkflowSteps,
    StepView
}
import from services.projects.projects {
    ListProjects,
    SaveProject,
    ArchiveProject,
    AssignToProject,
    UnassignFromProject
}
import from services.roster.roster {
    ListMembers,
    SaveMember,
    SetMemberRoles,
    ListRoles,
    SaveRole,
    DeleteRole,
    ArchiveMember,
    ListRepos,
    AddRepo,
    RemoveRepo
}
import from services.tasks.tasks {
    ListTasks,
    TaskCounts,
    TaskHistory,
    GetTask,
    AddChecklistItem,
    SetChecklistItem,
    RemoveChecklistItem,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from services.log.log {
    ListLogEntries,
    LogCounts,
    LogActivity,
    UpdateLogEntry,
    DeleteLogEntries
}
import from services.flowlines.flowlines {
    GetFlowLine,
    ApplyTemplate,
    SaveStep,
    MoveStep,
    DeleteStep,
    DeleteFlowLine,
    LinkTransition,
    LabelTransition,
    UnlinkTransition,
    GetFlowLineMeta,
    RenameFlowLine,
    ListStepTasks
}
import from services.github.github {
    GithubStatus,
    StartGithubInstall,
    CompleteGithubInstall,
    DisconnectGithub,
    ListGithubRepos,
    ListRepoIssues,
    ListRepoPulls,
    SearchRepoItems,
    ImportIssues,
    CreateIssueFromTask,
    SyncGithub,
    SetRepoAutoSync,
    SetRepoAutoDone,
    SetRepoAutoClose
}
import from services.github.events { GithubEvent, DrainGithubEvents }
import from services.board.board { BoardSnapshot }
import from services.iterations.iterations {
    ListIterations,
    SaveIteration,
    DeleteIteration,
    RoadmapSnapshot
}
import from services.insights.insights { Digest, OverviewSnapshot }
import from services.assistant.assistant { AskAssistant, WriteStandup, ProposeAction }

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
