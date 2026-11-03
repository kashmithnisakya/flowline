"""Step 2: who works on the first project. A panel of the people added so far over
the form that adds one; continuing keeps a name still in the fields."""

import from ...models { MemberView }
import from ..ui.button { Button }
import from ..common.Avatar { Avatar }
import from .PersonForm { PersonForm }
import from .SetupParts { StepTitle, SaveError }

def:pub PeopleStep(
    project: str,
    added: list[MemberView],
    first: str,
    last: str,
    role: str,
    firstError: str,
    saveError: str,
    busy: bool,
    onField: Callable[[str, str], None],
    onSubmit: Callable[[FormEvent], any],
    onBack: Callable[[], None],
    onSkip: Callable[[], None],
    onContinue: Callable[[], any]
) -> JsxElement {
    return
        <section className="flex flex-col gap-5">
            <StepTitle
                title={"Who works on " + (project or "this project") + "?"}
                sub="Add people now or skip. They are names you assign tasks to, not accounts."
            />
            <div className="surface">
                {if len(added) > 0 {
                    <ul
                        key="added"
                        aria-label="People added"
                        className="divide-y border-b"
                    >
                        {for m in added {
                            <li
                                key={m.id}
                                className="flex min-h-11 min-w-0 items-center gap-2.5 px-3 py-2 text-[13.5px]"
                            >
                                <Avatar name={m.name} size="xs"/>
                                <span className="truncate font-medium">{m.name}</span>
                                {if len(m.roles) > 0 {
                                    <span key="roles" className="meta truncate">
                                        {", ".join(m.roles)}
                                    </span>
                                }}
                            </li>
                        }}
                    </ul>
                }}
                <PersonForm
                    first={first}
                    last={last}
                    role={role}
                    firstError={firstError}
                    busy={busy}
                    onField={onField}
                    onSubmit={onSubmit}
                />
            </div>
            {if saveError {
                <SaveError key="err" message={saveError}/>
            }}
            <div className="flex flex-wrap items-center gap-2">
                <Button type="button" variant="ghost" onClick={lambda { onBack(); }}>
                    Back
                </Button>
                <Button
                    type="button"
                    variant="ghost"
                    disabled={busy}
                    className="ml-auto text-muted-foreground"
                    onClick={lambda { onSkip(); }}
                >
                    Skip for now
                </Button>
                <Button
                    type="button"
                    disabled={busy}
                    className="h-10 px-4 font-semibold"
                    onClick={lambda { onContinue(); }}
                >
                    Continue
                </Button>
            </div>
        </section>;
}
