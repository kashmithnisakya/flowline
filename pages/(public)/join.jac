"""flowline - Invite landing (/join?org=..&code=..). The link a manager
shares. Signed out it hands off to /login with the invite stashed; signed in
it parks the join request and polls until the owner's approval lands. The
display params (org_name, role, by) are cosmetic; the code is the proof."""

# jac 0.36.1 injection pin (see setup.jac).
import from "@jac/runtime" { useState, jacIsLoggedIn }
import from "react" { useEffect }
import from ...walkers.org { RequestJoin, CheckJoin }
import from ...lib.session { fetchProfile, fetchAccountEmail, setSpaceRoot }
import from ...constants { ORG_LEVEL_BLURBS }
import from ...components.common.KineticGrid { KineticGrid }
import from ...components.ui.card {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}
import from ...components.ui.button { Button }
import from ...components.common.glyphs { Spinner }

glob STASH_KEY: str = "standup_invite";


def readParam(name: str) -> str {
    search: str = window.location.search;
    if not search {
        return "";
    }
    for pair in search[1:].split("&") {
        bits: list[str] = pair.split("=");
        if len(bits) == 2 and bits[0] == name {
            return decodeURIComponent(bits[1].replace("+", " "));
        }
    }
    return "";
}


def:pub JoinPage -> JsxPage {
    has stage: str = "boot",
        iOrg: str = "",
        iCode: str = "",
        iOrgName: str = "",
        iRole: str = "editor",
        error: str = "",
        pollTick: int = 0;

    can with entry {
        # Query params win and refresh the stash; a return from /login (or
        # SSO) arrives with no params and reads the stash back.
        org = readParam("org");
        code = readParam("code");
        stash: str = "";
        try {
            stash = localStorage.getItem(STASH_KEY) or "";
        } except Exception {
            stash = "";
        }
        gotOrg = "";
        gotCode = "";
        gotName = "";
        gotRole = "editor";
        if org and code {
            gotOrg = org;
            gotCode = code;
            gotName = readParam("org_name");
            gotRole = readParam("role") or "editor";
            try {
                localStorage.setItem(
                    STASH_KEY,
                    JSON.stringify(
                        {
                            "org": gotOrg,
                            "code": gotCode,
                            "org_name": gotName,
                            "role": gotRole
                        }
                    )
                );
            } except Exception {
                gotOrg = gotOrg;
            }
        } elif stash {
            try {
                parsed: any = JSON.parse(stash);
                gotOrg = parsed["org"] or "";
                gotCode = parsed["code"] or "";
                gotName = parsed["org_name"] or "";
                gotRole = parsed["role"] or "editor";
            } except Exception {
                gotOrg = "";
            }
        }
        iOrg = gotOrg;
        iCode = gotCode;
        iOrgName = gotName;
        iRole = gotRole;
        if not gotOrg or not gotCode {
            stage = "invalid";
        } elif jacIsLoggedIn() {
            stage = "confirm";
        } else {
            stage = "signedout";
        }
    }

    async def joinNow -> None {
        stage = "waiting";
        error = "";
        try {
            profile = await fetchProfile();
            addr = await fetchAccountEmail();
            said = profile["full_name"] if profile["full_name"] else "";
            res = root spawn RequestJoin(
                org_root_id=iOrg, code=iCode, name=said, email=addr
            );
            got = res.reports[0] if res.reports else None;
            if not got or not got["ok"] {
                stage = "confirm";
                error = "Couldn't send the request. Try the link again.";
                return;
            }
            pollTick = pollTick + 1;
        } except Exception {
            stage = "confirm";
            error = "Couldn't send the request. Try the link again.";
        }
    }

    async def pollOnce -> None {
        try {
            res = root spawn CheckJoin(org_root_id=iOrg);
            got = res.reports[0] if res.reports else None;
            if got and got["status"] == "member" {
                setSpaceRoot(iOrg);
                try {
                    localStorage.removeItem(STASH_KEY);
                } except Exception {
                    stage = stage;
                }
                window.location.href = "/board";
                return;
            }
        } except Exception {
            error = error;
        }
        pollTick = pollTick + 1;
    }

    can poll with [stage, pollTick] entry {
        timer: any = 0;
        if stage == "waiting" and pollTick > 0 {
            timer = window.setTimeout(lambda { pollOnce(); }, 4000);
        }
        return lambda { if timer { window.clearTimeout(timer); }};
    }

    def stashAndGo(target: str) {
        window.location.href = target;
    }

    blurb = ORG_LEVEL_BLURBS[iRole] if iRole in ORG_LEVEL_BLURBS else "";
    orgLabel = iOrgName or "the workspace";

    return
        <div className="relative overflow-hidden">
            <KineticGrid
                className="[mask-image:linear-gradient(to_bottom,black_55%,transparent)]"
            />
            <div
                aria-hidden="true"
                className="bg-glow pointer-events-none absolute inset-0"
            />
            <div
                className="relative z-10 mx-auto flex min-h-[80svh] w-full max-w-md flex-col justify-center gap-6 py-10"
            >
                {if stage == "invalid" {
                    <Card key="invalid" className="w-full">
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                This invite link doesn't work
                            </CardTitle>
                            <CardDescription>
                                It may have been revoked, or the link was copied incompletely. Ask the person who sent it for a new one.
                            </CardDescription>
                        </CardHeader>
                        <CardFooter>
                            <Button
                                className="w-full"
                                onClick={lambda { window.location.href = "/"; }}
                            >
                                Go to flowline
                            </Button>
                        </CardFooter>
                    </Card>
                } elif stage == "signedout" {
                    <Card key="signedout" className="w-full">
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                {"Join " + orgLabel}
                            </CardTitle>
                            <CardDescription>
                                {"You've been invited as "
                                    + iRole
                                    + ". "
                                    + blurb
                                    + " Create an account, or sign in with one you already have."}
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-2">
                            <Button
                                className="h-11 w-full"
                                onClick={lambda { stashAndGo("/login?mode=signup"); }}
                            >
                                Create an account
                            </Button>
                            <Button
                                variant="outline"
                                className="h-11 w-full"
                                onClick={lambda { stashAndGo("/login"); }}
                            >
                                Sign in to join
                            </Button>
                        </CardContent>
                    </Card>
                } elif stage == "waiting" {
                    <Card key="waiting" className="w-full">
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                Almost in
                            </CardTitle>
                            <CardDescription>
                                {"Your request to join "
                                    + orgLabel
                                    + " is waiting for a manager's approval. This page checks by itself; usually it's a matter of moments."}
                            </CardDescription>
                        </CardHeader>
                        <CardContent
                            className="flex items-center gap-3 text-sm text-muted-foreground"
                        >
                            <Spinner/>
                            <span>Waiting for approval…</span>
                        </CardContent>
                    </Card>
                } elif stage == "confirm" {
                    <Card key="confirm" className="w-full">
                        <CardHeader>
                            <CardTitle className="font-display text-2xl tracking-tight">
                                {"Join " + orgLabel}
                            </CardTitle>
                            <CardDescription>
                                {"You'll join as " + iRole + ". " + blurb}
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            {if error {
                                <p key="err" className="text-sm text-destructive">
                                    {error}
                                </p>
                            }}
                        </CardContent>
                        <CardFooter>
                            <Button className="h-11 w-full" onClick={joinNow}>
                                {"Join " + orgLabel}
                            </Button>
                        </CardFooter>
                    </Card>
                } else {
                    <div
                        key="boot"
                        className="flex items-center justify-center gap-3 text-sm text-muted-foreground"
                    >
                        <Spinner/>
                        <span>One moment…</span>
                    </div>
                }    }
            </div>
        </div>;
}
