"""Organization walkers: the onboarding gate."""

import from models { Organization }
import from walkers.util { now_iso }

# ------------------------------------------------------- org and onboarding

walker GetMe {
    """The caller's Organization, or no report — client redirects to /setup."""
    has reports: list[Organization] = [];

    can run with Root entry {
        orgs = [here-->[?:Organization]];
        if orgs {
            report orgs[0];
        }
    }
}

walker CreateOrganization {
    """Idempotent: a root gets exactly one org; a second call reports the
    existing one. pm_root_ids is the v3 multi-PM hook, seeded server-side."""
    has name: str,
        reports: list[Organization] = [];

    can create with Root entry {
        orgs = [here-->[?:Organization]];
        if orgs {
            report orgs[0];
        } else {
            fresh = here ++> Organization(
                name=self.name.strip(), created_at=now_iso(),
                pm_root_ids=[jid(here)]
            );
            report fresh;
        }
    }
}

