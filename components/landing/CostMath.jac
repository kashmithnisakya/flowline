"""What a daily standup costs, as one light line of arithmetic with the team
size as an inline stepper. Multiplication only: no invented statistics."""

glob MIN_TEAM: int = 2,
     MAX_TEAM: int = 40,
     STEP_BTN: str = "inline-flex size-11 items-center justify-center rounded-md border border-input bg-card text-lg leading-none text-foreground transition-colors hover:bg-accent disabled:opacity-40 sm:size-9";

def:pub CostMath -> JsxElement {
    has size: int = 8;

    return
        <section className="landing-wrap pt-14 sm:pt-20">
            <div className="border-y py-8">
                <p
                    className="max-w-[46ch] text-[clamp(1.25rem,2.4vw,1.625rem)] leading-[1.6] font-semibold [font-stretch:108%]"
                >
                    {"A 15-minute standup for "}
                    <span className="inline-flex items-center gap-2 align-middle">
                        <button
                            type="button"
                            className={STEP_BTN}
                            aria-label="Fewer people"
                            disabled={size <= MIN_TEAM}
                            onClick={lambda { size = size - 1
                                if size > MIN_TEAM
                                else size; }}
                        >
                            −
                        </button>
                        <output
                            aria-live="polite"
                            className="min-w-[2ch] text-center font-mono tabular-nums"
                        >
                            {size}
                        </output>
                        <button
                            type="button"
                            className={STEP_BTN}
                            aria-label="More people"
                            disabled={size >= MAX_TEAM}
                            onClick={lambda { size = size + 1
                                if size < MAX_TEAM
                                else size; }}
                        >
                            +
                        </button>
                    </span>
                    {" people, every weekday for 48 weeks, is "}
                    <span className="font-mono tabular-nums">{size * 60}</span>
                    {" hours a year."}
                </p>
                <p className="mt-3 text-sm text-muted-foreground">
                    {str(size)
                        + " × 15 minutes × 5 days × 48 weeks. Multiplication, not a statistic."}
                </p>
            </div>
        </section>;
}
