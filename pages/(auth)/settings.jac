"""standup - Settings page (/settings): personal preferences.

Appearance only for now. The theme is a per-browser preference (localStorage),
not an account field: the same account on a laptop and a meeting-room screen
legitimately wants different modes.
"""

import from ...lib.theme { getThemePref, setThemePref }

glob THEME_OPTIONS: list[list[str]] = [
         ["light", "Light", "Warm paper with the ember accent."],
         ["dark", "Dark", "Deep pine with the teal accent."],
         ["system", "System", "Follows your device's appearance."]
     ];


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
                <h1 className="font-display text-3xl font-semibold tracking-tight">
                    Settings
                </h1>
                <p className="text-sm text-muted-foreground">
                    Preferences for this browser.
                </p>
            </div>
            <div className="flex flex-col gap-3 rounded-lg border bg-card p-5">
                <div>
                    <h2 className="font-display text-base font-semibold">Appearance</h2>
                    <p className="text-sm text-muted-foreground">
                        Light keeps the classic look; dark switches to the teal night palette.
                    </p>
                </div>
                <div className="grid gap-3 sm:grid-cols-3">
                    {for opt in THEME_OPTIONS {
                        <button
                            key={opt[0]}
                            type="button"
                            className={"flex flex-col gap-2 rounded-lg border p-4 text-left transition-shadow hover:shadow-sm "
                                + (
                                    "border-primary ring-2 ring-primary/30"
                                        if pref == opt[0]
                                        else ""
                                )}
                            onClick={lambda { pick(opt[0]); }}
                        >
                            <span
                                className={"h-10 w-full rounded-md border "
                                    + (
                                        "bg-[#101514]"
                                            if opt[0] == "dark"
                                            else (
                                                "bg-[#F6F2EB]"
                                                    if opt[0] == "light"
                                                    else "bg-gradient-to-r from-[#F6F2EB] to-[#101514]"
                                            )
                                    )}
                            />
                            <span className="text-sm font-semibold">{opt[1]}</span>
                            <span className="text-xs text-muted-foreground">
                                {opt[2]}
                            </span>
                        </button>
                    }}
                </div>
            </div>
        </div>;
}
