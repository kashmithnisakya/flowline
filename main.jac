"""standup - Entry Point.

File-based routing: pages/ holds the routes. This module registers every
server endpoint (a walker name missing from these imports 404s) and renders
the routed children.
"""

import ".styles.global.css";

import from models {
    Project, Member, Repo, Task, LogEntry, TaskView, MemberView,
    Milestone, MilestoneView, GithubConnectionView
}
import from walkers.projects {
    ListProjects, SaveProject, ArchiveProject,
    AssignToProject, UnassignFromProject
}
import from walkers.roster {
    ListMembers, SaveMember, ArchiveMember, ListRepos, AddRepo, RemoveRepo
}
import from walkers.tasks {
    ListTasks, CreateTask, UpdateTask, MoveTask, SetMoveInfo, DeleteTask
}
import from walkers.log {
    ListLogEntries, LogActivity, UpdateLogEntry, DeleteLogEntries
}
import from walkers.vocab { ListVocab, AddVocab, RemoveVocab }
import from walkers.roadmap {
    ListMilestones, SaveMilestone, DeleteMilestone, ReorderMilestone,
    SetTaskMilestone
}
import from walkers.github {
    GithubStatus, StartGithubInstall, CompleteGithubInstall, DisconnectGithub,
    ListGithubRepos, ListRepoIssues, ListRepoPulls, ImportIssues,
    CreateIssueFromTask, SyncGithub
}
import from walkers.insights { Digest }
import from walkers.assistant { AskAssistant, WriteStandup, ProposeAction }

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
