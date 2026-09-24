"""The flow line's view pills: View or Edit, List or Diagram on phones (not
while editing), and Flow or Lanes wherever the diagram shows."""

import from .controls { Segmented }

glob MODES: list[dict[str, str]] = [
         {"value": "view", "label": "View"},
         {"value": "edit", "label": "Edit"}
     ],
     LAYOUTS: list[dict[str, str]] = [
         {"value": "flow", "label": "Flow"},
         {"value": "lanes", "label": "Lanes"}
     ],
     PHONE_VIEWS: list[dict[str, str]] = [
         {"value": "list", "label": "List"},
         {"value": "diagram", "label": "Diagram"}
     ];

def:pub ViewSwitches(
    editing: bool = False,
    narrow: bool = False,
    showList: bool = False,
    phoneView: str = "list",
    lineView: str = "flow",
    onMode: Callable[[str], None] = None,
    onPhoneView: Callable[[str], None] = None,
    onView: Callable[[str], None] = None
) -> JsxElement {
    return
        <>
            <Segmented
                label="Mode"
                options={MODES}
                value={"edit" if editing else "view"}
                onChange={onMode}
            />
            {if narrow and not editing {
                <Segmented
                    key="phoneview"
                    label="Show"
                    options={PHONE_VIEWS}
                    value={phoneView}
                    onChange={onPhoneView}
                />
            }}
            {if not editing and not showList {
                <Segmented
                    key="layout"
                    label="Layout"
                    options={LAYOUTS}
                    value={lineView}
                    onChange={onView}
                />
            }}
        </>;
}
