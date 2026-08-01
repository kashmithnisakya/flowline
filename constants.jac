"""standup - shared vocabulary lists.

One vocabulary for the whole app: board columns, log dropdowns, and server
validation all read these. Adding a value here is a data edit, not a schema
migration. (Teams were retired in v2 — projects are nodes with CRUD.)
"""

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];

glob CATEGORIES: list[str] = ["Architecture", "Reviewing", "Coding"];

glob PRIORITIES: list[str] = ["High", "Medium", "Low"];

glob SECTIONS: list[str] = ["Deployment Layer", "Data Layer", "Application Layer"];
