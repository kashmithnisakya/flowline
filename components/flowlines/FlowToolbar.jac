"""The flow line page's controls as one row of pills: View or Edit, List or
Diagram on phones, Flow or Lanes, zoom and Edit flow line.
`pending` draws the same row inert for the first-load frame."""

import from .controls { ZoomControls }
import from .ViewSwitches { ViewSwitches }
import from ..ui.button { Button }

def:pub FlowToolbar(
    editing: bool = False,
    narrow: bool = False,
    showList: bool = False,
    phoneView: str = "list",
    lineView: str = "flow",
    zoom: float = 1.0,
    pending: bool = False,
    onMode: Callable[[str], None] = None,
    onPhoneView: Callable[[str], None] = None,
    onView: Callable[[str], None] = None,
    onZoom: Callable[[int], None] = None,
    onActual: Callable[[], None] = None,
    onFit: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            className={"flex min-w-0 flex-wrap items-center gap-2"
                + (" pointer-events-none" if pending else "")}
        >
            <ViewSwitches
                editing={editing}
                narrow={narrow}
                showList={showList}
                phoneView={phoneView}
                lineView={lineView}
                onMode={onMode}
                onPhoneView={onPhoneView}
                onView={onView}
            />
            {if not showList {
                <ZoomControls
                    key="zoom"
                    zoom={zoom}
                    pending={pending}
                    onOut={lambda { if onZoom { onZoom(-1); }}}
                    onIn={lambda { if onZoom { onZoom(1); }}}
                    onActual={onActual}
                    onFit={onFit}
                />
            }}
            {if not editing and not narrow {
                <Button
                    key="edit"
                    size="sm"
                    className="h-[30px] rounded-md px-3.5"
                    disabled={pending}
                    onClick={lambda { if onMode { onMode("edit"); }}}
                >
                    Edit flow line
                </Button>
            }}
        </div>;
}
