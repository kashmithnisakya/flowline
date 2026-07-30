"""Implementations for the root layout."""

impl Shell.loadMembers -> None {
    try {
        result = root spawn ListMembers();
        fetched = result.reports[0] if result.reports else [];
        members = fetched;
        # Drop a WhoAmI that no longer resolves (roster re-import mints new
        # jids) — a stale one would silently blank every log-form prefill.
        who = localStorage.getItem("standup_who") or "";
        if who and fetched {
            found = False;
            for m in fetched {
                if jid(m) == who {
                    found = True;
                }
            }
            if not found {
                localStorage.removeItem("standup_who");
                whoAmI = "";
            }
        }
    } except Exception as e {
        members = [];
    }
}

impl Shell.setWho(memberId: str) -> None {
    whoAmI = memberId;
    localStorage.setItem("standup_who", memberId);
}
