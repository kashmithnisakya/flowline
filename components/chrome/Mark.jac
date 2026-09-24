"""The brand mark drawn inline in currentColor: a start node, a bend, an end
node. The sidebar, the phone header and the setup bar all show it."""

def:pub Mark(size: int = 22, className: str = "") -> JsxElement {
    return
        <svg
            className={"shrink-0 text-mark " + className}
            width={size}
            height={size}
            viewBox="0 0 24 24"
            fill="none"
            aria-hidden="true"
        >
            <circle cx={5} cy={17} r={3} stroke="currentColor" strokeWidth={2.2}/>
            <path
                d="M8 17h3.5a3 3 0 0 0 3-3v-4a3 3 0 0 1 1.5-2.6"
                stroke="currentColor"
                strokeWidth={2.2}
                strokeLinecap="round"
            />
            <circle cx={19} cy={7} r={3} fill="currentColor"/>
        </svg>;
}
