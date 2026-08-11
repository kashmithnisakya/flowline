"""standup - Entry Point.

File-based routing: pages/ holds the routes. This module registers every
server endpoint (a walker name missing from these imports 404s) and renders
the routed children.
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
    ArchiveMember,
    ListRepos,
    AddRepo,
    RemoveRepo
}
import from walkers.tasks {
    ListTasks,
    CreateTask,
    UpdateTask,
    MoveTask,
    SetMoveInfo,
    DeleteTask
}
import from walkers.log {
    ListLogEntries,
    LogActivity,
    UpdateLogEntry,
    DeleteLogEntries
}
import from walkers.workflow {
    GetWorkflow,
    ApplyTemplate,
    SaveStep,
    MoveStep,
    DeleteStep,
    LinkTransition,
    LabelTransition,
    UnlinkTransition,
    GetWorkflowMeta,
    RenameWorkflow,
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
    SyncGithub
}
import from walkers.insights { Digest }
import from walkers.assistant { AskAssistant, WriteStandup, ProposeAction }

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
