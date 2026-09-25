"""First-run gallery: pick how the team moves work. Every card reads its steps,
roles and send-backs from FLOW_LINE_TEMPLATES itself, so what a team sees is
what ApplyTemplate seeds. The "simple" template is the recommended one."""

import from ...constants { FLOW_LINE_TEMPLATES }
import from .kinds { colorKey }
import from ..common.StepName { StepName }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..common.glyphs { Spinner }

# Plain-language summaries by template key; a template without one falls back
# to its own description.
glob PLAIN: dict[str, str] = {
         "simple": "Four steps most teams already use. Work goes from To do to Doing to Review, and Review can send it back.",
         "jaseci": "Seven steps across four roles for a team shipping from GitHub. Issues are validated and picked, labels and merges move the work, and oversight decides when it is done."
     },
     RECOMMENDED: str = "simple";


# Template rows ready for JSX: steps as name and colour, the roles, and each
# send-back spelled out. Typed locals, the checker cannot subscript the
# template's nested `any` values inside the tree.
def templateRows -> list[dict[str, any]] {
    hasRecommended = False;
    for t in FLOW_LINE_TEMPLATES {
        if t["key"] == RECOMMENDED {
            hasRecommended = True;
        }
    }
    rows: list[dict[str, any]] = [];
    for (i, t) in enumerate(FLOW_LINE_TEMPLATES) {
        raws: list[dict[str, any]] = t["steps"];
        steps: list[dict[str, any]] = [];
        for (si, s) in enumerate(raws) {
            steps.append(
                {
                    "name": str(s["name"]),
                    "color": colorKey(str(s["color"])),
                    "first": si == 0
                }
            );
        }
        roleNames: list[str] = [];
        roleRaws: list[dict[str, any]] = t["roles"] if "roles" in t else [];
        for r in roleRaws {
            roleNames.append(str(r["name"]));
        }
        backs: list[str] = [];
        pairs: list[list[int]] = t["links"] if "links" in t else [];
        for pair in pairs {
            if pair[1] < pair[0] and pair[0] < len(raws) {
                backs.append(steps[pair[0]]["name"] + " to " + steps[pair[1]]["name"]);
            }
        }
        key = str(t["key"]);
        lead = key == RECOMMENDED if hasRecommended else i == 0;
        rows.append(
            {
                "key": key,
                "name": str(t["name"]),
                "about": PLAIN[key] if key in PLAIN else str(t["description"]),
                "steps": steps,
                "roles": ", ".join(roleNames),
                "backs": ", ".join(backs),
                "recommended": key == RECOMMENDED,
                "lead": lead
            }
        );
    }
    # The recommended template leads the list wherever it sits in constants.
    rows.sort(key=lambda (r: dict[str, any]) { 0 if r["lead"] else 1; });
    return rows;
}


def:pub TemplatePicker(
    applying: str = "",
    onPick: Callable[[str], None] = None,
    onScratch: Callable[[], None] = None
) -> JsxElement {
    rows = templateRows();
    return
        <div className="flex w-full flex-col gap-5">
            <div className="flex flex-col gap-1">
                <h2 className="section-title text-lg">How does your team move work?</h2>
                <p className="text-sm text-muted-foreground">
                    Pick a starting point. Steps, names and connections can all change later.
                </p>
            </div>
            <div
                className="grid items-start gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]"
            >
                <div className="flex min-w-0 flex-col gap-4">
                    {for t in rows {
                        <section
                            key={t["key"]}
                            aria-label={t["name"]}
                            className={"surface flex flex-col gap-3 p-5"
                                + (
                                    " opacity-60"
                                        if applying != "" and applying != t["key"]
                                        else ""
                                )}
                        >
                            <div className="flex flex-wrap items-center gap-2">
                                <h3 className="section-title">{t["name"]}</h3>
                                {if t["recommended"] {
                                    <Badge key="rec" variant="secondary">
                                        Recommended
                                    </Badge>
                                }}
                            </div>
                            <p className="max-w-prose text-sm text-muted-foreground">
                                {t["about"]}
                            </p>
                            <ol
                                className="flex flex-wrap items-center gap-x-1.5 gap-y-1.5"
                                aria-label="Steps"
                            >
                                {for st in t["steps"] {
                                    <li
                                        key={st["name"]}
                                        className="flex items-center gap-1.5 text-[13px] font-medium"
                                    >
                                        {if not st["first"] {
                                            <span
                                                key="arrow"
                                                className="text-subtle"
                                                aria-hidden="true"
                                            >
                                                →
                                            </span>
                                        }}
                                        <StepName
                                            name={st["name"]}
                                            color={st["color"]}
                                        />
                                    </li>
                                }}
                            </ol>
                            {if t["roles"] or t["backs"] {
                                <dl
                                    key="facts"
                                    className="grid gap-x-3 gap-y-1 text-xs sm:grid-cols-[auto_minmax(0,1fr)]"
                                >
                                    {if t["roles"] {
                                        <div key="roles" className="contents">
                                            <dt className="text-subtle">Roles</dt>
                                            <dd className="text-muted-foreground">
                                                {t["roles"]}
                                            </dd>
                                        </div>
                                    }}
                                    {if t["backs"] {
                                        <div key="backs" className="contents">
                                            <dt className="text-subtle">Sends back</dt>
                                            <dd className="text-muted-foreground">
                                                {t["backs"]}
                                            </dd>
                                        </div>
                                    }}
                                </dl>
                            }}
                            <div className="pt-1">
                                <Button
                                    variant={"default" if t["lead"] else "outline"}
                                    disabled={bool(applying)}
                                    aria-label={None
                                        if t["lead"]
                                        else "Use template: " + t["name"]}
                                    onClick={lambda { if onPick { onPick(t["key"]); }}}
                                >
                                    {if applying == t["key"] {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Setting up"
                                        if applying == t["key"]
                                        else "Use template"}
                                </Button>
                            </div>
                        </section>
                    }}
                </div>
                <section
                    aria-label="Start from scratch"
                    className={"surface flex flex-col gap-3 p-5"
                        + (" opacity-60" if applying != "" else "")}
                >
                    <h3 className="section-title">Start from scratch</h3>
                    <p className="text-sm text-muted-foreground">
                        A blank canvas. Add your own steps and draw how work moves between them.
                    </p>
                    <div className="pt-1">
                        <Button
                            variant="outline"
                            disabled={bool(applying)}
                            onClick={lambda { if onScratch { onScratch(); }}}
                        >
                            Open a blank canvas
                        </Button>
                    </div>
                </section>
            </div>
        </div>;
}
