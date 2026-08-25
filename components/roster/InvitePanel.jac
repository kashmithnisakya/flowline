"""Access panel for the People tab: who holds a login key to this board,
invites, and the approvals queue. Grants execute only in the org owner's
session (a runtime rule), so managers can mint and share invite links but
the final Approve is the owner's; the button says so. Renders nothing for
members below manager."""

# jac 0.36.1 injection pin (see setup.jac).
import from "@jac/runtime" { useState }
import from "react" { useEffect }
import from ...models { MemberView }
import from ...walkers.org {
    GetOrgContext,
    CreateInvite,
    ListInvites,
    RevokeInvite,
    ApproveJoin,
    SetMemberLevel,
    RemoveMember
}
import from ...lib.session { spaceRoot }
import from ...constants { ORG_LEVELS, ORG_LEVEL_BLURBS }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.badge { Badge }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..common.Avatar { Avatar }
import from "sonner" { toast }


def:pub InvitePanel(members: list[MemberView], onChanged: any) -> JsxElement {
    has ctxLevel: str = "",
        orgRootId: str = "",
        orgName: str = "",
        invites: list[dict[str, any]] = [],
        claims: list[dict[str, any]] = [],
        dialogOpen: bool = False,
        fEmail: str = "",
        fLevel: str = "editor",
        fMemberId: str = "",
        createdLink: str = "",
        busy: bool = False,
        pollTick: int = 0;

    async def load -> None {
        try {
            t = spaceRoot();
            cres = t spawn GetOrgContext();
            ctx = cres.reports[0] if cres.reports else None;
            if not ctx or not ctx["ok"] {
                return;
            }
            lvl = ctx["level"];
            ctxLevel = lvl;
            orgRootId = ctx["org_root_id"];
            if ctx["org_name"] {
                orgName = ctx["org_name"];
            }
            if lvl not in ["owner", "manager"] {
                return;
            }
            t2 = spaceRoot();
            ires = t2 spawn ListInvites();
            got = ires.reports[0] if ires.reports else None;
            if got and got["ok"] {
                invites = got["invites"] or [];
                claims = got["claims"] or [];
            }
        } except Exception {
            ctxLevel = ctxLevel;
        }
    }

    can with entry {
        load();
        pollTick = 1;
    }

    # Approvals arrive from outside this session; poll gently while the
    # tab is open so the queue shows up without a manual refresh.
    can tick with [pollTick] entry {
        timer: any = 0;
        if pollTick > 0 {
            timer = window.setTimeout(
                lambda {
                    load();
                    pollTick = pollTick + 1;
                },
                12000
            );
        }
        return lambda { if timer { window.clearTimeout(timer); }};
    }

    async def createInvite {
        busy = True;
        try {
            t = spaceRoot();
            res = t spawn CreateInvite(
                email=fEmail.strip(), level=fLevel, member_id=fMemberId
            );
            got = res.reports[0] if res.reports else None;
            if got and got["ok"] {
                origin: str = window.location.origin;
                createdLink = origin
                    + "/join?org="
                    + orgRootId
                    + "&code="
                    + got["code"]
                    + "&role="
                    + fLevel
                    + "&org_name="
                    + encodeURIComponent(orgName);
                load();
            } else {
                toast("Couldn't create the invite.");
            }
        } except Exception {
            toast("Couldn't create the invite.");
        }
        busy = False;
    }

    def copyLink {
        try {
            navigator.clipboard.writeText(createdLink);
            toast("Invite link copied");
        } except Exception {
            toast("Copy failed - select the link text instead");
        }
    }

    async def approve(requestId: str) {
        try {
            t = spaceRoot();
            res = t spawn ApproveJoin(request_id=requestId, org_name=orgName);
            got = res.reports[0] if res.reports else None;
            if got and got["ok"] {
                toast("They're in.");
                load();
                onChanged();
            } else {
                toast("Couldn't approve that request.");
            }
        } except Exception {
            toast("Couldn't approve that request.");
        }
    }

    async def revoke(inviteId: str) {
        try {
            t = spaceRoot();
            t spawn RevokeInvite(invite_id=inviteId);
            load();
        } except Exception {
            toast("Couldn't revoke the invite.");
        }
    }

    async def setLevel(memberId: str, level: str) {
        try {
            t = spaceRoot();
            res = t spawn SetMemberLevel(member_id=memberId, level=level);
            got = res.reports[0] if res.reports else None;
            if got and got["ok"] {
                toast("Access updated");
                onChanged();
            } else {
                toast("Only the org owner can change access.");
            }
        } except Exception {
            toast("Couldn't change access.");
        }
    }

    async def removeAccess(memberId: str) {
        try {
            t = spaceRoot();
            res = t spawn RemoveMember(member_id=memberId);
            got = res.reports[0] if res.reports else None;
            if got and got["ok"] {
                toast("Access removed. They stay on the roster.");
                load();
                onChanged();
            } else {
                toast("Only the org owner can remove access.");
            }
        } except Exception {
            toast("Couldn't remove access.");
        }
    }

    def openDialog {
        fEmail = "";
        fLevel = "editor";
        fMemberId = "";
        createdLink = "";
        dialogOpen = True;
    }

    if ctxLevel in ["editor", "viewer"] {
        return <></>;
    }

    isOwner = ctxLevel == "owner";
    linked = [
        m
        for m in members
        if m.linked
    ];
    unlinked = [
        m
        for m in members
        if not m.linked and m.active
    ];

    return
        <Card>
            <CardHeader>
                <div className="flex items-start justify-between gap-4">
                    <div className="grid gap-1">
                        <CardTitle className="text-base">Access</CardTitle>
                        <CardDescription>
                            Teammates sign in with their own accounts; a role decides what each one can do here.
                        </CardDescription>
                    </div>
                    <Button size="sm" onClick={openDialog}>Invite someone</Button>
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                {if len(claims) > 0 {
                    <div key="claims" className="grid gap-2">
                        <p
                            className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                        >
                            Waiting for approval
                        </p>
                        {for c in claims {
                            <div
                                key={c["request_id"]}
                                className="flex items-center gap-3 rounded-lg border border-border/70 bg-muted/40 px-3 py-2"
                            >
                                <Avatar
                                    name={c["name"] or c["email"] or "?"}
                                    size="sm"
                                />
                                <div className="min-w-0 flex-1">
                                    <p className="truncate text-sm font-medium">
                                        {c["name"] or c["email"] or "Someone"}
                                    </p>
                                    <p
                                        className="truncate text-xs text-muted-foreground"
                                    >
                                        {(c["email"] or "no email")
                                            + " · joins as "
                                            + c["level"]}
                                    </p>
                                </div>
                                <Button
                                    size="sm"
                                    disabled={not isOwner}
                                    title={""
                                        if isOwner
                                        else "Only the org owner can finalize access"}
                                    onClick={lambda { approve(c["request_id"]); }}
                                >
                                    Approve
                                </Button>
                            </div>
                        }}
                    </div>
                }}
                {if len(linked) > 0 {
                    <div key="linked" className="grid gap-2">
                        <p
                            className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                        >
                            Have access
                        </p>
                        {for m in linked {
                            <div
                                key={m.id}
                                className="flex items-center gap-3 rounded-lg border border-border/70 px-3 py-2"
                            >
                                <Avatar name={m.name} size="sm"/>
                                <div className="min-w-0 flex-1">
                                    <p className="truncate text-sm font-medium">
                                        {m.name}
                                    </p>
                                    <p
                                        className="truncate text-xs text-muted-foreground"
                                    >
                                        {m.email or "linked account"}
                                    </p>
                                </div>
                                {if isOwner {
                                    <Select
                                        key="lvl"
                                        value={m.level}
                                        onValueChange={lambda (v: str) { setLevel(
                                            m.id, v
                                        ); }}
                                    >
                                        <SelectTrigger
                                            size="sm"
                                            className="w-28 capitalize"
                                        >
                                            <SelectValue/>
                                        </SelectTrigger>
                                        <SelectContent>
                                            {for lvl in ORG_LEVELS {
                                                <SelectItem
                                                    key={lvl}
                                                    value={lvl}
                                                    className="capitalize"
                                                >
                                                    {lvl}
                                                </SelectItem>
                                            }}
                                        </SelectContent>
                                    </Select>
                                } else {
                                    <Badge
                                        key="lvl-ro"
                                        variant="secondary"
                                        className="capitalize"
                                    >
                                        {m.level}
                                    </Badge>
                                } }
                                {if isOwner {
                                    <Button
                                        key="rm"
                                        variant="ghost"
                                        size="sm"
                                        className="text-destructive"
                                        onClick={lambda { removeAccess(m.id); }}
                                    >
                                        Remove
                                    </Button>
                                }}
                            </div>
                        }}
                    </div>
                }}
                {if len(invites) > 0 {
                    <div key="invites" className="grid gap-2">
                        <p
                            className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                        >
                            Open invites
                        </p>
                        {for inv in invites {
                            <div
                                key={inv["id"]}
                                className="flex items-center gap-3 rounded-lg border border-dashed border-border/70 px-3 py-2"
                            >
                                <div className="min-w-0 flex-1">
                                    <p className="truncate text-sm">
                                        {inv["email"] or "Link invite"}
                                    </p>
                                    <p
                                        className="truncate text-xs text-muted-foreground capitalize"
                                    >
                                        {str(inv["level"]) + " · " + str(inv["status"])}
                                    </p>
                                </div>
                                {if inv["status"] == "pending" {
                                    <Button
                                        key="rv"
                                        variant="ghost"
                                        size="sm"
                                        onClick={lambda { revoke(inv["id"]); }}
                                    >
                                        Revoke
                                    </Button>
                                }}
                            </div>
                        }}
                    </div>
                }}
                {if len(claims) == 0 and len(linked) == 0 and len(invites) == 0 {
                    <p key="empty" className="text-sm text-muted-foreground">
                        Only you have access. Invite teammates to view or edit this board.
                    </p>
                }}
            </CardContent>
            <Dialog
                open={dialogOpen}
                onOpenChange={lambda (o: bool) { dialogOpen = o; }}
            >
                <DialogContent className="sm:max-w-md">
                    {if createdLink {
                        <DialogHeader key="done-h">
                            <DialogTitle>Invite created</DialogTitle>
                            <DialogDescription>
                                Send this link yourself - flowline does not send email yet. It works once and expires in 14 days.
                            </DialogDescription>
                        </DialogHeader>
                    } else {
                        <DialogHeader key="form-h">
                            <DialogTitle>Invite someone</DialogTitle>
                            <DialogDescription>
                                They'll sign in with their own account; you (or the owner) approve them with one click.
                            </DialogDescription>
                        </DialogHeader>
                    } }
                    {if createdLink {
                        <div key="done" className="grid gap-3">
                            <Input
                                readOnly={True}
                                value={createdLink}
                                onFocus={lambda (e: any) { e.target.select(); }}
                            />
                            <Button onClick={copyLink}>Copy link</Button>
                        </div>
                    } else {
                        <div key="form" className="grid gap-4">
                            <div className="grid gap-2">
                                <Label>Email (recommended)</Label>
                                <Input
                                    value={fEmail}
                                    placeholder="them@company.com"
                                    onChange={lambda (e: ChangeEvent) { fEmail = e.target.value; }}
                                />
                                <p className="text-xs text-muted-foreground">
                                    With an email the invite only works for that address. Leave it empty for an open link.
                                </p>
                            </div>
                            <div className="grid gap-2">
                                <Label>Role</Label>
                                {for lvl in ORG_LEVELS {
                                    <button
                                        key={lvl}
                                        type="button"
                                        className={"rounded-lg border px-3 py-2 text-left text-sm transition-colors "
                                            + (
                                                "border-primary bg-primary/5"
                                                    if fLevel == lvl
                                                    else "border-border/70 hover:bg-accent"
                                            )}
                                        onClick={lambda { fLevel = lvl; }}
                                    >
                                        <span className="font-medium capitalize">
                                            {lvl}
                                        </span>
                                        <span
                                            className="block text-xs text-muted-foreground"
                                        >
                                            {ORG_LEVEL_BLURBS[lvl]}
                                        </span>
                                    </button>
                                }}
                            </div>
                            {if len(unlinked) > 0 {
                                <div key="link-roster" className="grid gap-2">
                                    <Label>Link to a person on the board</Label>
                                    <Select
                                        value={fMemberId or "none"}
                                        onValueChange={lambda (v: str) { fMemberId = ""
                                            if v == "none"
                                            else v; }}
                                    >
                                        <SelectTrigger className="w-full">
                                            <SelectValue/>
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="none">
                                                New member row
                                            </SelectItem>
                                            {for m in unlinked {
                                                <SelectItem key={m.id} value={m.id}>
                                                    {m.name}
                                                </SelectItem>
                                            }}
                                        </SelectContent>
                                    </Select>
                                    <p className="text-xs text-muted-foreground">
                                        Their task history and log entries carry over.
                                    </p>
                                </div>
                            }}
                        </div>
                    } }
                    <DialogFooter>
                        {if createdLink {
                            <Button
                                key="close"
                                variant="outline"
                                onClick={lambda { dialogOpen = False; }}
                            >
                                Done
                            </Button>
                        } else {
                            <Button key="create" disabled={busy} onClick={createInvite}>
                                Create invite
                            </Button>
                        } }
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </Card>;
}
