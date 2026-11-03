"""The picture of the product: the board, drawn from sample rows at a fixed
text scale and clipped by its frame. It reads no data and takes no pointer.
The layout stays fluid, so `.lp-shot-in` only picks the scale per breakpoint.
"""

import from .ShotBar { ShotBar }
import from .ShotGroup { ShotGroup }
import from .ShotHead { ShotHead }
import from .ShotSidebar { ShotSidebar }
import from .shotData { SHOT_STEPS }

def:pub ProductShot -> JsxElement {
    return
        <div className="lp-wrap pb-2">
            <div
                role="img"
                aria-label="The Flowline board with sample tasks: a line of five steps with tasks stacked under each, and an AI code review running on the Review step."
                className="lp-shot"
            >
                <div className="lp-shot-in flex">
                    <ShotSidebar/>
                    <div className="min-w-0 flex-1">
                        <ShotHead/>
                        <ShotBar/>
                        {for s in SHOT_STEPS {
                            <ShotGroup key={s.name} step={s}/>
                        }}
                    </div>
                </div>
            </div>
        </div>;
}
