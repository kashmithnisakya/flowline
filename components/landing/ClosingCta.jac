"""The closing call to action, where the spine ends in a filled node. The line
stops at the node, so nothing runs on past the page's last ask."""

import from .PrimaryCta { PrimaryCta }
import from .Spine { SpineStep }

def:pub ClosingCta(loggedIn: bool) -> JsxElement {
    return
        <SpineStep anchor="start" tone="lp-step-end">
            <div className="flex flex-col items-start gap-3.5">
                <h2 className="lp-h1">Your line starts here.</h2>
                <p className="lp-lead">
                    Name your team, add your people, pick a template. The board opens with a new task ready to type.
                </p>
                <PrimaryCta loggedIn={loggedIn} className="mt-2 w-full sm:w-auto"/>
            </div>
        </SpineStep>;
}
