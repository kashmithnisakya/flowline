"""Preferences for this browser: the theme. The swatch hexes are deliberately
hardcoded, since tokens would repaint every swatch to the current theme and
make the choice unreadable.
"""

import from ...lib.theme { getThemePref, setThemePref }
import from "react" { useEffect }
import from .SectionHeader { SectionHeader }
import from .SettingRow { SettingRow }

glob THEME_CHOICES: list[list[str]] = [
         ["light", "Light"],
         ["dark", "Dark"],
         ["system", "System"]
     ];

# A 28x18 sample of the palette a choice paints: the ground, with the accent
# as a bar. "system" shows both halves.
def ThemeSwatch(kind: str) -> JsxElement {
    if kind == "light" {
        return
            <span
                className="flex h-[18px] w-7 shrink-0 items-end gap-0.5 overflow-hidden rounded-xs border border-black/15 bg-bg-canvas p-1"
                aria-hidden="true"
            >
                <span className="h-1 w-3 rounded-full bg-primary"/>
            </span>;
    }
    if kind == "dark" {
        return
            <span
                className="flex h-[18px] w-7 shrink-0 items-end gap-0.5 overflow-hidden rounded-xs border border-white/20 bg-bg-canvas p-1"
                aria-hidden="true"
            >
                <span className="h-1 w-3 rounded-full bg-primary"/>
            </span>;
    }
    return
        <span
            className="flex h-[18px] w-7 shrink-0 overflow-hidden rounded-xs border border-black/15"
            aria-hidden="true"
        >
            <span className="flex flex-1 items-end bg-bg-canvas p-1">
                <span className="h-1 w-2 rounded-full bg-primary"/>
            </span>
            <span className="flex flex-1 items-end bg-bg-canvas p-1">
                <span className="h-1 w-2 rounded-full bg-primary"/>
            </span>
        </span>;
}


def:pub PreferencesSection -> JsxElement {
    has pref: str = "system";

    can with entry {
        pref = getThemePref();
    }

    # The account menu changes the same preference; every change ends in a
    # `flowline:theme` event, so this row follows without a reload.
    useEffect(
        lambda {
            w: any = window;
            onTheme = lambda (e: any) { pref = getThemePref(); };
            w.addEventListener("flowline:theme", onTheme);
            return lambda { w.removeEventListener("flowline:theme", onTheme); };
        },
        []
    );

    def pick(value: str) {
        setThemePref(value);
        pref = value;
    }

    return
        <div className="flex flex-col gap-4">
            <SectionHeader title="Preferences"/>
            <div className="surface max-w-[960px]">
                <SettingRow
                    label="Theme"
                    hint="System follows your device. Saved in this browser only."
                >
                    <div
                        role="group"
                        aria-label="Theme"
                        className="flex flex-wrap items-center gap-1.5"
                    >
                        {for opt in THEME_CHOICES {
                            <button
                                key={opt[0]}
                                type="button"
                                aria-pressed={pref == opt[0]}
                                className={"inline-flex h-9 items-center gap-2 rounded-md border px-3 text-[13.5px] transition-colors duration-150 "
                                    + (
                                        "border-foreground bg-card font-semibold text-foreground"
                                            if pref == opt[0]
                                            else "border-border text-muted-foreground hover:bg-accent hover:text-foreground"
                                    )}
                                onClick={lambda { pick(opt[0]); }}
                            >
                                <ThemeSwatch kind={opt[0]}/>
                                {opt[1]}
                            </button>
                        }}
                    </div>
                </SettingRow>
            </div>
        </div>;
}
