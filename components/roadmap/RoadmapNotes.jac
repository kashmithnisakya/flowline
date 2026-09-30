"""The line under the timeline when the snapshot was cut off, so a missing
task never looks like an unscheduled one. The bar's hover title says how to
read it; the undated count is a link in the page's subtitle."""

def:pub RoadmapNotes(shown: int) -> JsxElement {
    return
        <p className="text-xs text-muted-foreground">
            {"Showing the first " + str(shown) + " scheduled tasks."}
        </p>;
}
