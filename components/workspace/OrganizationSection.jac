"""Rename the organization. The name lives in the account profile (the account
IS the organization), so this talks to /user/me through lib/session rather than
a walker. Save appears only once the name differs; the header hears about it
through a `flowline:org-renamed` event, so nothing has to reload.
"""

import from ...lib.session { fetchProfile, patchProfile }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.skeleton { Skeleton }
import from ..common.glyphs { Spinner }
import from .SectionHeader { SectionHeader }
import from .SettingRow { SettingRow }
import from "sonner" { toast }


def:pub OrganizationSection(onRenamed: Callable[[str], None] = None) -> JsxElement {
    has draft: str = "",
        saved: str = "",
        loading: bool = True,
        saving: bool = False;

    async can with entry {
        load();
    }

    async def load -> None;
    async def save -> None;

    changed = bool(draft.strip()) and draft.strip() != saved;
    return
        <div className="flex flex-col gap-4">
            <SectionHeader title="Organization"/>
            <div className="surface">
                <SettingRow
                    label="Organization name"
                    hint="Shown in the top bar and the account menu."
                    htmlFor="org-name"
                >
                    {if loading {
                        <Skeleton key="sk" className="h-9 w-full max-w-sm"/>
                    } else {
                        <form
                            key="form"
                            className="flex max-w-lg flex-wrap items-center gap-2"
                            onSubmit={lambda (e: FormEvent) {
                                e.preventDefault();
                                save();
                            }}
                        >
                            <Input
                                id="org-name"
                                className="h-9 min-w-0 flex-1"
                                value={draft}
                                placeholder="Acme Robotics"
                                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}
                            />
                            {if changed {
                                <Button
                                    key="save"
                                    type="submit"
                                    size="lg"
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
                                    size="lg"
                                    disabled={saving}
                                    onClick={lambda { draft = saved; }}
                                >
                                    Cancel
                                </Button>
                            }}
                        </form>
                    } }
                </SettingRow>
            </div>
        </div>;
}
