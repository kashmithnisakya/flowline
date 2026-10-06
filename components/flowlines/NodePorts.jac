"""The four connection dots on a step's edges in edit mode: always shown on
the selected step, on hover elsewhere. Purely visual; the page hit-tests the
border strip (geometry PORT_ZONE) to start a wire."""

glob PORT_AT: list[str] = [
         "left-1/2 top-0 -translate-x-1/2 -translate-y-1/2",
         "bottom-0 left-1/2 -translate-x-1/2 translate-y-1/2",
         "left-0 top-1/2 -translate-x-1/2 -translate-y-1/2",
         "right-0 top-1/2 translate-x-1/2 -translate-y-1/2"
     ];

def:pub NodePorts(shown: bool = False) -> JsxElement {
    return
        <span aria-hidden="true">
            {for at in PORT_AT {
                <span
                    key={at}
                    className={"pointer-events-none absolute size-2 rounded-full border border-primary bg-card transition-opacity duration-150 "
                        + at
                        + (
                            " opacity-100"
                                if shown
                                else " opacity-0 group-hover:opacity-100"
                        )}
                />
            }}
        </span>;
}
