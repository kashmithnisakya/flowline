"""standup - the public landing page at /.

Hitting the server sells the product rather than bouncing to a login form.
A visitor with a session still sees this page, but every call to action
becomes "go to your board" instead of "sign up".
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

    <div className="bg-background">
        <SiteNav loggedIn={loggedIn} />
        <main>
            <Hero loggedIn={loggedIn} />
            <Features />
            <HowItWorks />
            <Faq />
            <SiteFooter loggedIn={loggedIn} />
        </main>
    </div>
}
