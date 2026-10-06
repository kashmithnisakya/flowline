"""The app's toaster: bottom right beside the docked Ask column, above the
phone tab bar, and at the top while the Ask sheet covers the bottom."""

import from ..ui.toaster { Toaster }
import from ..common.KindGlyph { KindGlyph }
import from ..common.glyphs { WarnIcon }

glob TAB_CLEAR: str = "calc(4.5rem + env(safe-area-inset-bottom))",
     OPTIONS: dict[str, any] = {
         "classNames": {
             "toast": "rounded-xl! border-border! font-sans! text-[13.5px]! shadow-xl!",
             "title": "font-medium!",
             "description": "text-muted-foreground!",
             "error": "border-l-2! border-l-destructive!"
         }
     };

def:pub Toasts(narrow: bool, askSheet: bool, docked: bool, tabBar: bool) -> JsxElement {
    position = ("top-center" if narrow else "top-left") if askSheet else "bottom-right";
    offset: dict[str, str] = {
        "top": "24px",
        "left": "24px",
        "right": "376px" if docked else "24px",
        "bottom": TAB_CLEAR if narrow and tabBar else "24px"
    };
    mobile: dict[str, str] = {
        "top": "calc(12px + env(safe-area-inset-top))",
        "bottom": TAB_CLEAR if tabBar else "16px"
    };
    icons: dict[str, any] = {
        "success": <KindGlyph kind="done" size={16} className="text-success"/>,
        "error": <KindGlyph kind="blocked" size={16} className="text-destructive"/>,
        "warning": <WarnIcon size={16} className="text-warning"/>
    };
    return
        <Toaster
            position={position}
            offset={offset}
            mobileOffset={mobile}
            icons={icons}
            toastOptions={OPTIONS}
        />;
}
