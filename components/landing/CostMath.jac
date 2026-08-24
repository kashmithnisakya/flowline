"""The page's one number: what the standup costs, as arithmetic the visitor
does with a slider. No invented statistics; a 15-minute meeting times the
team times five days is just multiplication. Styled like the footer's ink
band so the two bookend the page.
"""

# Week minutes are size*75, so the fraction is always a quarter hour.
glob REM_LABEL: dict[int, str] = {0: "", 15: ".25", 30: ".5", 45: ".75"};

def weekHours(size: int) -> str {
    minutes = size * 75;
    return str(minutes // 60) + REM_LABEL[minutes % 60];
}

def:pub CostMath -> JsxElement {
    has size: int = 8;

    return
        <section className="mx-auto max-w-[1180px] px-7 pt-24">
            <div
                className="relative overflow-hidden rounded-3xl bg-foreground px-8 py-12 text-background sm:px-12"
            >
                <div
                    aria-hidden="true"
                    className="absolute inset-0 bg-[radial-gradient(42rem_22rem_at_50%_-6rem,color-mix(in_oklab,var(--primary)_25%,transparent),transparent_70%)]"
                ></div>
                <div
                    className="relative grid items-center gap-10 lg:grid-cols-[1fr_auto] lg:gap-16"
                >
                    <div>
                        <span
                            className="text-xs font-semibold uppercase tracking-widest text-background/60"
                        >
                            Just arithmetic
                        </span>
                        <h2
                            className="font-display mt-3 max-w-md text-[clamp(1.7rem,3.5vw,2.4rem)] font-extrabold leading-[1.05] tracking-[-0.04em]"
                        >
                            What does your 9:45 actually cost?
                        </h2>
                        <p className="mt-4 max-w-md text-sm text-background/70">
                            A 15-minute standup, every weekday, the whole team in the room. No invented statistics, only multiplication.
                        </p>
                        <div className="mt-7 flex items-center gap-4">
                            <input
                                type="range"
                                min="2"
                                max="20"
                                value={str(size)}
                                onChange={lambda (e: ChangeEvent) { size = int(
                                    e.target.value
                                ); }}
                                aria-label="Team size"
                                className="h-2 w-full max-w-[260px] cursor-pointer accent-primary"
                            />
                            <span
                                className="shrink-0 text-sm font-semibold tabular-nums"
                            >
                                {size} people
                            </span>
                        </div>
                        <p className="mt-3 text-xs tabular-nums text-background/60">
                            {size} people × 15 minutes × 5 days, over 48 working weeks
                        </p>
                    </div>
                    <div className="flex gap-12 lg:flex-col lg:gap-7 lg:text-right">
                        <div>
                            <div
                                className="font-display text-[clamp(2.4rem,6vw,3.4rem)] font-extrabold leading-none tracking-[-0.03em] tabular-nums"
                            >
                                {weekHours(size)}
                            </div>
                            <div
                                className="mt-1.5 text-[10px] font-semibold uppercase tracking-widest text-background/60"
                            >
                                hours a week
                            </div>
                        </div>
                        <div>
                            <div
                                className="font-display text-[clamp(2.4rem,6vw,3.4rem)] font-extrabold leading-none tracking-[-0.03em] tabular-nums"
                            >
                                {size * 60}
                            </div>
                            <div
                                className="mt-1.5 text-[10px] font-semibold uppercase tracking-widest text-background/60"
                            >
                                hours a year
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>;
}
