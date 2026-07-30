"""standup - Entry Point.

File-based routing: pages/ holds the routes, this module only registers the
server endpoints (every walker name MUST appear in this import list or its
endpoint 404s) and renders the routed children.
"""

import ".styles.global.css";

import from endpoints {
    Member, Repo, Task, LogEntry, TaskView,
    ListMembers, SaveMember, ArchiveMember,
    ListRepos, AddRepo, RemoveRepo,
    ListTasks, CreateTask, UpdateTask, MoveTask, DeleteTask,
    ListLogEntries, LogActivity, UpdateLogEntry, DeleteLogEntry,
    ImportCsv
}

def:pub app(children: any) -> JsxElement {
    <>{children}</>
}
