"""standup - Entry Point.

File-based routing: pages/ holds the routes. This module registers every
server endpoint (a walker name missing from these imports 404s) and renders
the routed children.
"""

import ".styles.global.css";

import from models {
    Project, Member, Repo, Task, LogEntry, TaskView, MemberView
}
import from walkers.projects {
    ListProjects, SaveProject, ArchiveProject,
    AssignToProject, UnassignFromProject
}
import from walkers.roster {
    ListMembers, SaveMember, ArchiveMember, ListRepos, AddRepo, RemoveRepo
}
import from walkers.tasks {
    ListTasks, CreateTask, UpdateTask, MoveTask, DeleteTask
}
import from walkers.log {
    ListLogEntries, LogActivity, UpdateLogEntry, DeleteLogEntry
}

def:pub app(children: any) -> JsxElement {
    <>{children}</>
}
