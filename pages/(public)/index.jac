"""standup - the public landing page at /. Sells the product rather than
bouncing to login; a visitor with a session sees the same page with every
call to action pointing at their board.
"""

import from "@jac/runtime" { jacIsLoggedIn }
import from ...components.landing.SiteNav { SiteNav }
import from ...components.landing.Hero { Hero }
import from ...components.landing.Features { Features }
import from ...components.landing.HowItWorks { HowItWorks }
import from ...components.landing.Faq { Faq }
import from ...components.landing.SiteFooter { SiteFooter }

def:pub LandingPage() -> JsxPage {
    has loggedIn: bool = False;

    can with entry {
        loggedIn = jacIsLoggedIn();
    }

    return <div className="bg-background">
        <SiteNav loggedIn={loggedIn} />
        <main>
            <Hero loggedIn={loggedIn} />
            <Features />
            <HowItWorks />
            <Faq />
        </main>
        <SiteFooter loggedIn={loggedIn} />
    </div>;
}
