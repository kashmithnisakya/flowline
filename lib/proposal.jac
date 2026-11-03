"""The change Ask has proposed and nobody has answered yet. The board draws it
dashed in the step it would land in; Apply or Dismiss in Ask clears it. Module
state, since Ask lives in the layout and the board may mount later."""

glob CELL: dict[str, any] = {"proposal": None};

def tell {
    w: any = window;
    w.dispatchEvent(new(w.CustomEvent, "flowline:proposal"));
}

def:pub currentProposal -> any {
    return CELL["proposal"];
}

def:pub showProposal(proposal: any) {
    CELL["proposal"] = proposal;
    tell();
}

def:pub clearProposal {
    CELL["proposal"] = None;
    tell();
}
