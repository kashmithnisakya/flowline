"""flowline - Settings page (/settings): appearance only. The theme is a
per-browser preference (localStorage), not an account field. The theme cards
are mini app previews with deliberately hardcoded palette hexes: tokens would
repaint every card to the current theme and make the choice unreadable."""

import from ...lib.theme { getThemePref, setThemePref }

glob THEME_OPTIONS: list[list[str]] = [
         ["light", "Light", "Warm paper with the ember accent."],
         ["dark", "Dark", "Deep pine with the teal accent."],
         ["system", "System", "Follows your device's appearance."]
     ];

# Mini app preview for one theme card: surface, an accent dot + chip, and
# ghost text lines, in that theme's own palette.
def ThemePreview(kind: str) -> JsxElement {
    if kind == "light" {
        return
            <span
                className="flex h-16 w-full flex-col gap-1 overflow-hidden rounded-lg border border-[#E6DDCC] bg-[#F6F2EB] p-2.5"
            >
                <span className="flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#E8552F]"/>
                    <span className="h-1.5 w-10 rounded-full bg-[#14120F]/70"/>
                </span>
                <span className="h-1.5 w-3/4 rounded-full bg-[#14120F]/30"/>
                <span className="h-1.5 w-1/2 rounded-full bg-[#14120F]/15"/>
                <span className="mt-auto h-3 w-10 rounded-full bg-[#E8552F]"/>
            </span>;
    }
    if kind == "dark" {
        return
            <span
                className="flex h-16 w-full flex-col gap-1 overflow-hidden rounded-lg border border-[#E6EDEB]/15 bg-[#101514] p-2.5"
            >
                <span className="flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#2DD4BF]"/>
                    <span className="h-1.5 w-10 rounded-full bg-[#E6EDEB]/80"/>
                </span>
                <span className="h-1.5 w-3/4 rounded-full bg-[#E6EDEB]/35"/>
                <span className="h-1.5 w-1/2 rounded-full bg-[#E6EDEB]/20"/>
                <span className="mt-auto h-3 w-10 rounded-full bg-[#2DD4BF]"/>
            </span>;
    }
    return
        <span className="flex h-16 w-full overflow-hidden rounded-lg border">
            <span className="flex flex-1 flex-col gap-1 bg-[#F6F2EB] p-2.5">
                <span className="flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#E8552F]"/>
                    <span className="h-1.5 w-8 rounded-full bg-[#14120F]/70"/>
                </span>
                <span className="h-1.5 w-3/4 rounded-full bg-[#14120F]/30"/>
                <span className="mt-auto h-3 w-8 rounded-full bg-[#E8552F]"/>
            </span>
            <span className="flex flex-1 flex-col gap-1 bg-[#101514] p-2.5">
                <span className="flex items-center gap-1.5">
                    <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#2DD4BF]"/>
                    <span className="h-1.5 w-8 rounded-full bg-[#E6EDEB]/80"/>
                </span>
                <span className="h-1.5 w-3/4 rounded-full bg-[#E6EDEB]/35"/>
                <span className="mt-auto h-3 w-8 rounded-full bg-[#2DD4BF]"/>
            </span>
        </span>;
}


def:pub SettingsPage -> JsxPage {
    has pref: str = "system";

    can with entry {
        pref = getThemePref();
    }

    def pick(value: str) {
        setThemePref(value);
        pref = value;
    }

    return
        <div className="flex w-full flex-col gap-8">
            <div className="flex flex-col gap-2">
                <h1 className="page-title">Settings</h1>
                <p className="page-subtitle">Preferences for this browser.</p>
            </div>
            <div
                className="flex flex-col gap-4 rounded-xl border bg-card p-5 animate-in fade-in slide-in-from-bottom-1 duration-200"
            >
                <div className="flex flex-col gap-1">
                    <h2 className="font-display text-base font-semibold">Appearance</h2>
                    <p className="text-sm text-muted-foreground">
                        Light keeps the classic look; dark switches to the teal night palette. System follows your device, so the app flips when it does.
                    </p>
                </div>
                <div className="grid gap-3 sm:grid-cols-3">
                    {for opt in THEME_OPTIONS {
                        <button
                            key={opt[0]}
                            type="button"
                            className={"relative flex flex-col gap-2 rounded-xl border p-4 text-left transition-all hover:-translate-y-0.5 hover:shadow-md "
                                + (
                                    "border-primary ring-2 ring-primary/30"
                                        if pref == opt[0]
                                        else ""
                                )}
                            onClick={lambda { pick(opt[0]); }}
                        >
                            {if pref == opt[0] {
                                <span
                                    key="check"
                                    className="absolute right-2 top-2 z-10 flex h-5 w-5 items-center justify-center rounded-full bg-primary text-primary-foreground animate-in zoom-in-50 duration-200"
                                >
                                    <svg
                                        width={12}
                                        height={12}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={3}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <path d="M20 6 9 17l-5-5"/>
                                    </svg>
                                </span>
                            }}
                            <ThemePreview kind={opt[0]}/>
                            <span className="text-sm font-semibold">{opt[1]}</span>
                            <span className="text-xs text-muted-foreground">
                                {opt[2]}
                            </span>
                        </button>
                    }}
                </div>
                <p className="text-xs text-muted-foreground">
                    Stored in this browser only. The same account on another machine keeps its own choice.
                </p>
            </div>
        </div>;
}
