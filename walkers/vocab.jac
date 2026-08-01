"""Custom vocabulary walkers: org-defined categories and sections.

Built-in terms live in constants.jac; these walkers manage the extra
terms an org adds from the Workspace tab. The client merges both lists,
so removing a custom term never touches rows that already use it (the
category/section fields on tasks and log entries are free text).
"""

import from models { VocabTerm, resolve, on_attached, owned }

glob VOCAB_KINDS: list[str] = ["category", "section"];

walker ListVocab {
    has results: list[VocabTerm] = [],
        reports: list[list[VocabTerm]] = [];

    can start with Root entry {
        visit [here-->[?:VocabTerm]];
    }

    can gather with VocabTerm entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (t: VocabTerm) { t.value; });
        report self.results;
    }
}

walker AddVocab {
    has kind: str,
        value: str,
        reports: list[VocabTerm] = [];

    can add with Root entry {
        if self.kind not in VOCAB_KINDS or not self.value.strip() {
            disengage;
        }
        v = self.value.strip();
        existing = [here-->[?:VocabTerm, kind == self.kind, value == v]];
        if existing {
            report existing[0];
        } else {
            fresh = here ++> VocabTerm(kind=self.kind, value=v);
            on_attached(here, fresh);
            report fresh;
        }
    }
}

walker RemoveVocab {
    has term_id: str;

    can remove with Root entry {
        target = resolve(self.term_id);
        if isinstance(target, VocabTerm) and owned(here, target) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}
