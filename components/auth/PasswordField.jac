"""The password field: its reveal button, then under it the error or, on signup,
the length rule."""

import from ..ui.input { Input }
import from ..ui.label { Label }
import from .AuthGlyphs { EyeGlyph, RuleGlyph }

def:pub PasswordField(
    value: str, error: str, signup: bool, minLength: int, onValue: Callable[[str], None]
) -> JsxElement {
    has reveal: bool = False;

    longEnough = len(value) >= minLength;
    return
        <div className="grid gap-1.5">
            <Label htmlFor="auth-password" className="text-[13px] font-medium">
                Password
            </Label>
            <div className="relative flex items-center">
                <Input
                    id="auth-password"
                    type={"text" if reveal else "password"}
                    name="password"
                    autoComplete={"new-password" if signup else "current-password"}
                    value={value}
                    aria-invalid={error != ""}
                    aria-describedby={"auth-password-note" if signup or error else None}
                    onChange={lambda (ev: ChangeEvent) { onValue(ev.target.value); }}
                    placeholder="••••••••••"
                    className="h-10 pr-11"
                />
                <button
                    type="button"
                    aria-label={"Hide password" if reveal else "Show password"}
                    aria-pressed={reveal}
                    className="absolute right-1 inline-flex size-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                    onClick={lambda { reveal = not reveal; }}
                >
                    <EyeGlyph crossed={reveal}/>
                </button>
            </div>
            {if error {
                <p
                    key="password-error"
                    id="auth-password-note"
                    className="text-xs text-destructive"
                >
                    {error}
                </p>
            } elif signup {
                <p
                    key="rule"
                    id="auth-password-note"
                    className={"flex items-center gap-1.5 text-xs "
                        + ("text-success" if longEnough else "text-muted-foreground")}
                >
                    <RuleGlyph met={longEnough}/>
                    {"At least " + str(minLength) + " characters"}
                </p>
            } }
        </div>;
}
