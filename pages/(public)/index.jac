"""flowline - the public landing page at /. Sells the product rather than
bouncing to login; a visitor with a session sees the same page with every
call to action pointing at their board. One line, the spine, runs through it.
"""

import from "@jac/runtime" { jacIsLoggedIn }
import from ...lib.session { checkSession }
import from ...components.landing.SiteNav { SiteNav }
import from ...components.landing.Hero { Hero }
import from ...components.landing.ProductShot { ProductShot }
import from ...components.landing.StepDraw { StepDraw }
import from ...components.landing.StepMove { StepMove }
import from ...components.landing.StepHandOff { StepHandOff }
import from ...components.landing.StepConnect { StepConnect }
import from ...components.landing.StepSee { StepSee }
import from ...components.landing.Faq { Faq }
import from ...components.landing.ClosingCta { ClosingCta }
import from ...components.landing.SiteFooter { SiteFooter }

def:pub LandingPage -> JsxPage {
    has loggedIn: bool = False;

    # A stored token shows the app links at once; a token the server no
    # longer takes turns them back into sign-in links.
    async can with entry {
        stored = jacIsLoggedIn();
        loggedIn = stored;
        if stored {
            loggedIn = await checkSession();
        }
    }

    return
        <div className="min-h-svh overflow-x-clip bg-background text-foreground">
            <SiteNav loggedIn={loggedIn}/>
            <main>
                <Hero loggedIn={loggedIn}/>
                <ProductShot/>
                <div className="lp-wrap">
                    <StepDraw/>
                    <StepMove/>
                </div>
                <StepHandOff/>
                <div className="lp-wrap">
                    <StepConnect/>
                    <StepSee/>
                    <Faq/>
                    <ClosingCta loggedIn={loggedIn}/>
                </div>
            </main>
            <SiteFooter/>
        </div>;
}
