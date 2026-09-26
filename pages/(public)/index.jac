"""flowline - the public landing page at /. Sells the product rather than
bouncing to login; a visitor with a session sees the same page with every
call to action pointing at their board. Every section renders on load.
"""

import from "@jac/runtime" { jacIsLoggedIn }
import from ...lib.session { checkSession }
import from ...components.landing.SiteNav { SiteNav }
import from ...components.landing.Hero { Hero }
import from ...components.landing.Tour { Tour }
import from ...components.landing.TourFilm { TourFilm }
import from ...components.landing.Features { Features }
import from ...components.landing.HowItWorks { HowItWorks }
import from ...components.landing.Faq { Faq }
import from ...components.landing.SiteFooter { SiteFooter }

def:pub LandingPage -> JsxPage {
    has loggedIn: bool = False;

    # A stored token shows the app links at once; a token the server no
    # longer takes turns them back into sign-in links.
    async can with entry {
        loggedIn = jacIsLoggedIn();
        if loggedIn {
            loggedIn = await checkSession();
        }
    }

    return
        <div className="min-h-svh bg-background text-foreground">
            <SiteNav loggedIn={loggedIn}/>
            <main>
                <Hero loggedIn={loggedIn}/>
                <Tour/>
                <TourFilm/>
                <Features/>
                <HowItWorks/>
                <Faq/>
            </main>
            <SiteFooter loggedIn={loggedIn}/>
        </div>;
}
