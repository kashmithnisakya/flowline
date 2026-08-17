"""Rename the organization and its project manager. Both live in the account
profile (the account IS the organization), so this talks to /user/me through
lib/session rather than a walker. Self-contained state.
"""

import from ...lib.session { fetchProfile, patchProfile }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent, CardHeader, CardTitle, CardDescription }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.skeleton { Skeleton }
import from "sonner" { toast }
import from ..common.glyphs { Spinner }


def:pub OrganizationSection() -> JsxElement {
    has orgName: str = "",
        fullName: str = "",
        loading: bool = True,
        saving: bool = False;

    async can with entry {
        load();
    }

    async def load -> None;
    async def save -> None;

    return <Card>
        <CardHeader>
            <CardTitle>Organization</CardTitle>
            <CardDescription>
                The only place these two are editable. The organization name heads
                every page in standup.
            </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
            {if loading {
                <div key="sk" className="grid gap-4">
                    <div className="grid gap-2">
                        <Skeleton className="h-4 w-36"/>
                        <Skeleton className="h-9 w-full"/>
                    </div>
                    <div className="grid gap-2">
                        <Skeleton className="h-4 w-24"/>
                        <Skeleton className="h-9 w-full"/>
                        <Skeleton className="h-3 w-56 max-w-full"/>
                    </div>
                    <Skeleton className="h-9 w-32"/>
                </div>
            } else {
                <div key="fields" className="grid gap-4">
                    <div className="grid gap-2">
                        <Label>Organization name</Label>
                        <Input
                            value={orgName}
                            onChange={lambda (e: ChangeEvent) { orgName = e.target.value; }}
                            placeholder="Acme Robotics"
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Your name</Label>
                        <Input
                            value={fullName}
                            onChange={lambda (e: ChangeEvent) { fullName = e.target.value; }}
                            placeholder="Priya Raman"
                        />
                        <p className="text-xs text-muted-foreground">
                            Signs the entries you write in the daily log.
                        </p>
                    </div>
                    <div>
                        <Button
                            onClick={save}
                            disabled={saving or not orgName.strip() or not fullName.strip()}
                        >
                            {if saving {
                                <Spinner key="sp"/>
                            }}
                            {"Saving…" if saving else "Save changes"}
                        </Button>
                    </div>
                </div>
            }}
        </CardContent>
    </Card>;
}
