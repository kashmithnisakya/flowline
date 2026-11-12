"""The organization's name (the account profile, through lib/session; the
header hears a rename as `flowline:org-renamed`) and the way to the AI page."""

import from "@jac/runtime" { Link }
import from ...lib.session { fetchProfile, patchProfile, cachedOrgName }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.skeleton { Skeleton }
import from ..common.AiMark { AiMark }
import from ..common.glyphs { Spinner }
import from .SectionPanel { SectionPanel }
import from .SettingRow { SettingRow }
import from "sonner" { toast }

def:pub OrganizationSection -> JsxElement {
    # The header's cached name fills the field at once; the profile read
    # then confirms it (and only replaces an untouched draft).
    has draft: str = cachedOrgName(),
        saved: str = cachedOrgName(),
        loading: bool = not bool(cachedOrgName()),
        saving: bool = False;

    async can with entry {
        load();
    }

    async def load -> None;
    async def save -> None;

    changed = bool(draft.strip()) and draft.strip() != saved;
    return
        <SectionPanel section="organization" title="Organization">
            <div>
                <SettingRow
                    label="Name"
                    hint="Shown in the top bar and the account menu."
                    htmlFor="org-name"
                >
                    {if loading {
                        <Skeleton key="sk" className="h-8 w-full sm:w-[280px]"/>
                    } else {
                        <form
                            key="form"
                            className="flex flex-wrap items-center gap-2"
                            onSubmit={lambda (e: FormEvent) {
                                e.preventDefault();
                                save();
                            }}
                        >
                            <Input
                                id="org-name"
                                className="h-8 w-full min-w-0 sm:w-[280px]"
                                value={draft}
                                placeholder="Acme Robotics"
                                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}
                            />
                            {if changed {
                                <Button
                                    key="save"
                                    type="submit"
                                    size="sm"
                                    disabled={saving}
                                >
                                    {if saving {
                                        <Spinner key="sp"/>
                                    }}
                                    {"Saving…" if saving else "Save"}
                                </Button>
                            }}
                            {if changed {
                                <Button
                                    key="cancel"
                                    type="button"
                                    variant="ghost"
                                    size="sm"
                                    disabled={saving}
                                    onClick={lambda { draft = saved; }}
                                >
                                    Cancel
                                </Button>
                            }}
                        </form>
                    } }
                </SettingRow>
                <SettingRow label="AI" hint="Responsibilities, runs and what is sent">
                    <Button asChild={True} variant="outline" size="sm">
                        <Link to="/ai">
                            <AiMark/>
                            Open AI
                        </Link>
                    </Button>
                </SettingRow>
            </div>
        </SectionPanel>;
}
