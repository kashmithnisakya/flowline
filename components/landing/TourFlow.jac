"""The tour's flow line diagram: five steps, a branch through Design and a
loop back from Review. It grows with its column to about 960px and scrolls
sideways on phones rather than shrinking."""

import from .FlowNode { FlowNode }

glob FLOW_NODES: list[dict[str, any]] = [
         {
             "name": "Specify",
             "kind": "start",
             "color": "sky",
             "owner": "Anyone",
             "x": 6,
             "y": 110
         },
         {
             "name": "Design",
             "kind": "active",
             "color": "amber",
             "owner": "Architect",
             "x": 160,
             "y": 18
         },
         {
             "name": "Build",
             "kind": "active",
             "color": "indigo",
             "owner": "Model Pilot Engineer",
             "x": 314,
             "y": 110
         },
         {
             "name": "Review",
             "kind": "handoff",
             "color": "rose",
             "owner": "Reviewer",
             "x": 468,
             "y": 110
         },
         {
             "name": "Done",
             "kind": "done",
             "color": "emerald",
             "owner": "",
             "x": 622,
             "y": 110
         }
     ];

def:pub TourFlow -> JsxElement {
    return
        <div className="overflow-x-auto rounded-3xl border bg-background">
            <svg
                viewBox="0 0 744 236"
                className="mx-auto block h-auto w-full max-w-[960px] min-w-[744px]"
                role="img"
                aria-label="A flow line: Specify goes to Build, or through Design for big changes; Build goes to Review, Review to Done, and Review can send work back to Build."
            >
                <g
                    className="text-wire"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.6}
                >
                    <path d="M122 137H307"/>
                    <path d="M64 110C64 72 96 45 153 45"/>
                    <path d="M276 45C336 45 372 58 372 103"/>
                    <path d="M430 137H461"/>
                    <path d="M584 137H615"/>
                    <path d="M526 164C526 208 372 208 372 171" strokeDasharray="5 4"/>
                </g>
                <g className="text-wire" fill="currentColor">
                    <path d="M307 133l7 4-7 4z"/>
                    <path d="M153 41l7 4-7 4z"/>
                    <path d="M368 103l4 7 4-7z"/>
                    <path d="M461 133l7 4-7 4z"/>
                    <path d="M615 133l7 4-7 4z"/>
                    <path d="M368 171l4-7 4 7z"/>
                </g>
                <g
                    className="font-mono text-xs"
                    style={{"fill": "var(--subtle)"}}
                    textAnchor="middle"
                >
                    <text x={218} y={129}>Issue</text>
                    <text x={449} y={129}>PR</text>
                    <text x={603} y={129}>PR</text>
                    <text x={94} y={90} textAnchor="start">Big changes</text>
                    <text x={449} y={226}>Changes requested</text>
                </g>
                {for n in FLOW_NODES {
                    <FlowNode key={n["name"]} step={n}/>
                }}
            </svg>
        </div>;
}
