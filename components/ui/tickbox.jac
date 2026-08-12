"""jac-shadcn's Checkbox, owned here under a name the installer cannot write.

Deliberately NOT checkbox.jac. A published jac-shadcn ships this component
with a trailing `# noqa` after the Indicator's closing tag, which is inside
the JSX tree, so it is not a comment at all: it lowers to a text node and
every checkbox prints "# noqa" onto the page. Production showed it beside
each issue number as "# noqa#8079".

`jac install --shadcn checkbox` writes components/ui/checkbox.jac, so a
fixed copy under that name is overwritten by the next install or by any
build that reinstalls the registry. Under this name it cannot be. Same
reasoning as toaster.jac, which exists so sonner.jac cannot clobber it.
"""

import from "radix-ui" { Checkbox as CheckboxPrimitive }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Tick02Icon }

def:pub Checkbox(props: any) -> JsxElement {
    <CheckboxPrimitive.Root
        {**props}
        data-slot="checkbox"
        className={cn(
            "border-input dark:bg-input/30 data-checked:bg-primary data-checked:text-primary-foreground dark:data-checked:bg-primary data-checked:border-primary aria-invalid:aria-checked:border-primary aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 flex size-4 items-center justify-center rounded-[4px] border transition-colors group-has-disabled/field:opacity-50 focus-visible:ring-3 aria-invalid:ring-3 peer relative shrink-0 outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50",
            props["className"]
        )}
    >
        <CheckboxPrimitive.Indicator
            data-slot="checkbox-indicator"
            className="[&>svg]:size-3.5 grid place-content-center text-current transition-none"
        >
            <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
        </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
}
