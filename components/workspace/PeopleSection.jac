"""People: the roster as a table in a panel. Find matches name, role or project on
the client: the roster is a whole list already, so a search needs no round trip.
The page owns the writes and the member dialog.
"""

import from ...models { Project, MemberView }
import from ...components.roster.MemberTable { MemberTable }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ..common.Reveal { Reveal }
import from .SectionPanel { SectionPanel }
import from .icons { IconPlus, IconSearch }

def:pub PeopleSection(
    members: list[MemberView],
    projects: list[Project],
    roleOptions: list[str],
    showTags: bool,
    loading: bool,
    handlers: dict[str, any],
    onCreate: Callable[[], None]
) -> JsxElement {
    has query: str = "";

    needle = query.strip().lower();
    shown = members;
    if needle {
        hits: list[MemberView] = [];
        for m in members {
            hay = m.name + " " + " ".join(m.roles) + " " + " ".join(m.project_names);
            if needle in hay.lower() {
                hits.append(m);
            }
        }
        shown = hits;
    }

    return
        <SectionPanel
            section="people"
            title="People"
            count={"" if loading else str(len(members))}
            flush={True}
            actions={<>
                {if len(members) > 0 or loading {
                    <div
                        key="find"
                        className="relative min-w-0 flex-1 sm:w-48 sm:flex-none"
                    >
                        <IconSearch
                            className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-subtle"
                        />
                        <Input
                            className="h-8 pl-8"
                            placeholder="Find a person"
                            aria-label="Find a person"
                            value={query}
                            onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                        />
                    </div>
                }}
                <Button size="sm" variant="outline" onClick={onCreate}>
                    <IconPlus/>
                    Add person
                </Button>
            </>}
        >
            <Reveal
                ready={not loading}
                frame={<MemberTable
                    members={[]}
                    projects={[]}
                    roleOptions={[]}
                    {**handlers}
                    placeholder={4}
                />}
            >
                <div key="table">
                    <MemberTable
                        members={shown}
                        projects={projects}
                        roleOptions={roleOptions}
                        query={query.strip()}
                        showTags={showTags}
                        onCreate={onCreate}
                        {**handlers}
                    />
                </div>
            </Reveal>
        </SectionPanel>;
}
