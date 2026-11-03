"""The sign-in page's right pane: a flow line drawn large (two steps, an AI step
in dashed teal, then done) over the product's two sentences. Dark in both
themes, since `dark` rescopes the tokens; hidden below lg.
"""

glob NODE: str = "size-[18px] shrink-0 rounded-full border-[3px] ",
     WIRE: str = "h-[3px] flex-1 bg-primary";

def:pub AuthBand -> JsxElement {
    return
        <aside
            className="dark hidden min-w-0 flex-1 flex-col justify-center gap-10 border-l bg-bg-sidebar p-12 text-foreground lg:flex"
        >
            <div aria-hidden="true" className="flex items-center">
                <span className={NODE + "border-primary"}/>
                <span className={WIRE}/>
                <span className={NODE + "border-primary"}/>
                <span className={WIRE}/>
                <span className={NODE + "border-dashed border-ai"}/>
                <span className="flex-1 border-t-[3px] border-dashed border-ai"/>
                <span className={NODE + "border-primary bg-primary"}/>
            </div>
            <p
                className="text-[clamp(30px,3.2vw,46px)] leading-[1.04] font-bold tracking-[-0.03em] text-balance"
            >
                Draw how your team works.
                <br/>
                <span className="text-text-tertiary">The board follows.</span>
            </p>
        </aside>;
}
