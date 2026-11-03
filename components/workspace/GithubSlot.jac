"""Where the GitHub section mounts. It waits for its place to near the viewport,
so a reader who stays on People never starts it, unless the address or the rail
asks for it (`wake`). Once mounted it stays; both states carry the anchor id.
"""

import from "react" { useEffect }
import from .GithubFrame { GithubFrame }
import from .GithubSection { GithubSection }
import from .SectionPanel { SectionPanel }

def:pub GithubSlot(
    wake: bool, syncKey: int, onChanged: Callable[[], any]
) -> JsxElement {
    has near: bool = False,
        slot: Ref[any] = Ref();

    useEffect(
        lambda {
            watcher: any = 0;
            w: any = window;
            if slot.current and not (wake or near) {
                watcher = new(
                    w.IntersectionObserver,
                    lambda (entries: any) { for seen in entries {
                        if seen.isIntersecting {
                            near = True;
                        }
                    }},
                    {"rootMargin": "600px 0px"}
                );
                watcher.observe(slot.current);
            }
            return lambda { if watcher { watcher.disconnect(); }};
        },
        [wake, near]
    );

    return
        <div ref={slot}>
            {if wake or near {
                <GithubSection key="on" syncKey={syncKey} onChanged={onChanged}/>
            } else {
                <SectionPanel key="off" section="github" title="GitHub">
                    <GithubFrame/>
                </SectionPanel>
            } }
        </div>;
}
