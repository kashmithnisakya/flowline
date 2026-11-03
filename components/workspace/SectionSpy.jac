"""Renders nothing. Moves the rail to the section being read as the page scrolls,
and while a section is held (a rail click, a deep link) keeps it in place as the
column above it grows, until the reader takes over."""

import from "react" { useEffect }
import from .sections { sectionAtLine, heldSection, releaseSection, scrollToSection }

glob READER_INPUT: list[str] = ["wheel", "touchstart", "keydown", "mousedown"];

def:pub SectionSpy(column: str, onCurrent: Callable[[str], None]) -> JsxElement {
    useEffect(
        lambda {
            w: any = window;
            doc: any = document;
            pending: any = 0;
            read = lambda {
                pending = 0;
                if not heldSection() {
                    onCurrent(sectionAtLine());
                }
            };
            onScroll = lambda (e: any) { if not pending {
                pending = w.requestAnimationFrame(read);
            }};
            letGo = lambda (e: any) { releaseSection(); };
            grown: any = new(
                w.ResizeObserver,
                lambda (entries: any) {
                    held = heldSection();
                    if held {
                        scrollToSection(held);
                    }
                }
            );
            grown.observe(doc.getElementById(column));
            w.addEventListener("scroll", onScroll, {"passive": True});
            for kind in READER_INPUT {
                w.addEventListener(kind, letGo, {"passive": True});
            }
            return lambda {
                grown.disconnect();
                w.removeEventListener("scroll", onScroll);
                for kind in READER_INPUT {
                    w.removeEventListener(kind, letGo);
                }
                if pending {
                    w.cancelAnimationFrame(pending);
                }
                releaseSection();
            };
        },
        []
    );
    return <></>;
}
