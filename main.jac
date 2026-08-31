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
    WorkflowMeta,
    StepView
}
import from walkers.projects {
    ListProjects,
    SaveProject,
    ArchiveProject,
    AssignToProject,
    UnassignFromProject
}
import from walkers.roster {
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
import from walkers.tasks {
    ListTasks,
    TaskCounts,
    GetTask,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from walkers.log {
    ListLogEntries,
    LogCounts,
    LogActivity,
    UpdateLogEntry,
    DeleteLogEntries
}
import from walkers.flowlines {
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
import from walkers.github {
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
    SetRepoAutoSync
}
import from walkers.insights { Digest }
import from walkers.assistant { AskAssistant, WriteStandup, ProposeAction }

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
