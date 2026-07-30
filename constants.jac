"""standup - shared vocabulary lists.

One vocabulary for the whole app: board columns, log dropdowns, and server
validation all read these. Adding a value here is a data edit, not a schema
migration.
"""

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];

glob TEAMS: list[str] = ["Jac Core", "Jac Scale", "Jac Builder", "Jac Mobile", "CA"];

glob CATEGORIES: list[str] = ["Architecture", "Reviewing", "Coding"];

glob PRIORITIES: list[str] = ["High", "Medium", "Low"];

glob SECTIONS: list[str] = ["Deployment Layer", "Data Layer", "Application Layer"];
