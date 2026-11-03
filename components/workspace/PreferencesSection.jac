"""Preferences for this browser: the theme, as one segmented control."""

import from ...lib.theme { getThemePref, setThemePref }
import from "react" { useEffect }
import from .SectionPanel { SectionPanel }
import from .SettingRow { SettingRow }

glob THEME_CHOICES: list[list[str]] = [
         ["light", "Light"],
         ["dark", "Dark"],
         ["system", "System"]
     ];

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
        <SectionPanel section="preferences" title="Preferences">
            <div>
                <SettingRow
                    label="Theme"
                    hint="System follows your device. Saved in this browser only."
                >
                    <div
                        role="group"
                        aria-label="Theme"
                        className="inline-flex gap-0.5 rounded-[7px] bg-bg-hover p-0.5"
                    >
                        {for opt in THEME_CHOICES {
                            <button
                                key={opt[0]}
                                type="button"
                                aria-pressed={pref == opt[0]}
                                className={"h-[26px] rounded-[5px] px-2.5 text-[13px] transition-colors "
                                    + (
                                        "bg-card font-medium text-text-primary ring-1 ring-border"
                                            if pref == opt[0]
                                            else "text-text-secondary hover:text-text-primary"
                                    )}
                                onClick={lambda { pick(opt[0]); }}
                            >
                                {opt[1]}
                            </button>
                        }}
                    </div>
                </SettingRow>
            </div>
        </SectionPanel>;
}
