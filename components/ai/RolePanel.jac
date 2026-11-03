"""The AI page's responsibilities: one block per role, each with its lines, add
buttons and editor, from the same component the settings used. A role owns the
steps it runs on, so that is where a responsibility belongs."""

import from "@jac/runtime" { Link }
import from ...models { RoleView, StepView, ResponsibilityView }
import from ..workspace.roles.Responsibilities { Responsibilities }

def:pub RolePanel(
    roles: list[RoleView],
    steps: list[StepView],
    items: list[ResponsibilityView],
    aiEnabled: bool,
    onChanged: Callable[[], any]
) -> JsxElement {
    return
        <section className="surface bg-bg-elevated" aria-label="Responsibilities">
            <div className="flex min-h-11 items-center border-b px-4">
                <h2 className="text-sm font-semibold">Responsibilities</h2>
            </div>
            <div className="flex flex-col divide-y">
                {for r in roles {
                    <div key={r.id} className="flex flex-col gap-1 px-4 py-2.5">
                        <span className="text-[13px] font-medium">{r.name}</span>
                        <Responsibilities
                            roleId={r.id}
                            roleName={r.name}
                            items={[
                                x
                                for x in items
                                if x.role_id == r.id
                            ]}
                            steps={steps}
                            aiEnabled={aiEnabled}
                            onChanged={onChanged}
                            onOrganization={lambda { window.scrollTo(0, 0); }}
                        />
                    </div>
                }}
                {if len(roles) == 0 {
                    <p key="none" className="px-4 py-4 text-[13px] text-text-tertiary">
                        AI work belongs to a role.{" "}
                        <Link
                            to="/workspace?tab=roles"
                            className="text-text-primary underline underline-offset-2"
                        >
                            Add a role
                        </Link>{" "}
                        first.
                    </p>
                }}
            </div>
        </section>;
}
