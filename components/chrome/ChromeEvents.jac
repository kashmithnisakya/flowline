"""The window events the chrome follows: the workspace rename, a theme change
made elsewhere, the palette's Ask action, and the two viewport bands (Ask
docks at 1280px, the phone chrome is below 768px). Renders nothing."""

import from "react" { useEffect }

def:pub ChromeEvents(
    onRenamed: Callable[[str], None],
    onTheme: Callable[[], None],
    onAsk: Callable[[], None],
    onWide: Callable[[bool], None],
    onNarrow: Callable[[bool], None]
) -> JsxElement {
    useEffect(
        lambda {
            w: any = window;
            renamed = lambda (e: any) {
                name = str(e.detail.name or "") if e.detail else "";
                if name {
                    onRenamed(name);
                }
            };
            theme = lambda (e: any) { onTheme(); };
            ask = lambda (e: any) { onAsk(); };
            wideQ: any = w.matchMedia("(min-width: 1280px)");
            mdQ: any = w.matchMedia("(min-width: 768px)");
            wideNow = lambda (e: any) { onWide(bool(e.matches)); };
            mdNow = lambda (e: any) { onNarrow(not bool(e.matches)); };
            onWide(bool(wideQ.matches));
            onNarrow(not bool(mdQ.matches));
            w.addEventListener("flowline:org-renamed", renamed);
            w.addEventListener("flowline:theme", theme);
            w.addEventListener("flowline:ask", ask);
            wideQ.addEventListener("change", wideNow);
            mdQ.addEventListener("change", mdNow);
            return lambda {
                w.removeEventListener("flowline:org-renamed", renamed);
                w.removeEventListener("flowline:theme", theme);
                w.removeEventListener("flowline:ask", ask);
                wideQ.removeEventListener("change", wideNow);
                mdQ.removeEventListener("change", mdNow);
            };
        },
        []
    );
    return <></>;
}
