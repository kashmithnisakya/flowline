"""The flow line page's toolbar: View or Edit, List or Diagram on phones, Flow or
Lanes and a short hint on the left; edit actions, Templates and zoom on the
right. `pending` draws the same row inert for the first-load frame."""

import from .ZoomControls { ZoomControls }
import from .ViewSwitches { ViewSwitches }
import from .EditActions { EditActions }
import from ..ui.button { Button }

glob HINT_VIEW: str = "Click a step to see its work. In Edit, drag to connect.",
     HINT_EDIT: str = "Changes save as you go. Drag from a step's edge to connect.";

def:pub FlowToolbar(
    editing: bool = False,
    narrow: bool = False,
    showList: bool = False,
    phoneView: str = "list",
    lineView: str = "flow",
    zoom: float = 1.0,
    pending: bool = False,
    busy: bool = False,
    onMode: Callable[[str], None] = None,
    onPhoneView: Callable[[str], None] = None,
    onView: Callable[[str], None] = None,
    onZoom: Callable[[int], None] = None,
    onActual: Callable[[], None] = None,
    onFit: Callable[[], None] = None,
    onTemplates: Callable[[], None] = None,
    onAdd: Callable[[], None] = None,
    onRename: Callable[[], None] = None,
    onWipe: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            className={"toolbar min-w-0" + (" pointer-events-none" if pending else "")}
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
            <span className="meta hidden min-w-0 md:inline">
                {HINT_EDIT if editing else HINT_VIEW}
            </span>
            <div className="ml-auto flex flex-wrap items-center gap-1.5">
                {if editing {
                    <EditActions
                        key="edit"
                        disabled={busy}
                        onAdd={onAdd}
                        onRename={onRename}
                        onWipe={onWipe}
                    />
                }}
                <Button
                    variant="ghost"
                    size="sm"
                    className="h-[30px]"
                    disabled={pending}
                    onClick={lambda { if onTemplates { onTemplates(); }}}
                >
                    Templates
                </Button>
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
            </div>
        </div>;
}
