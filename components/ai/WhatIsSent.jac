"""What leaves this server for AI. Shared by the AI page and the dialog that turns
responsibilities on, so the two can never disagree. Ask does not depend on that
switch, so it says what Ask sends as well."""

def:pub WhatIsSent -> JsxElement {
    return
        <div className="flex flex-col gap-2 text-[13px]">
            <p className="font-medium">
                For a responsibility, only while it runs on a task:
            </p>
            <ul className="flex list-disc flex-col gap-1.5 pl-5">
                <li>
                    The changed files of the task's linked pull request: the diff, never the whole repository.
                </li>
                <li>The task's title and the first line of its notes.</li>
                <li>Your team's instructions for that responsibility.</li>
            </ul>
            <p className="font-medium">For Ask, each time you use it:</p>
            <p>
                A summary of the workspace: its counts, blocked, overdue, aging and in-review tasks, people, projects and recent log lines.
            </p>
            <p className="text-[12.5px] text-text-tertiary">
                Both go to the AI model provider this Flowline server is set up with. Ask does not depend on the AI responsibilities switch.
            </p>
        </div>;
}
