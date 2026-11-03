"""The line under the timeline when the snapshot was cut off, so a missing
task never looks like an unscheduled one. The undated count is a link in the
toolbar."""

def:pub RoadmapNotes(shown: int) -> JsxElement {
    return
        <p className="meta">
            {"Showing the first " + str(shown) + " scheduled tasks."}
        </p>;
}
