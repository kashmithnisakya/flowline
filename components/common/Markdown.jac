"""Renders free text (task notes, blockers) as markdown. react-markdown emits no
raw HTML, so typed input stays safe; with no typography plugin, element styling
rides on arbitrary child selectors sized for a dialog or card.
"""

import from "react-markdown" { default as ReactMarkdown }
import from "remark-gfm" { default as remarkGfm }
import from ...lib.utils { cn }

glob PROSE: str = (
         "min-w-0 break-words "
         "[&>*:first-child]:mt-0 [&>*:last-child]:mb-0 "
         "[&_p]:my-1 "
         "[&_ul]:my-1 [&_ul]:list-disc [&_ul]:pl-5 "
         "[&_ol]:my-1 [&_ol]:list-decimal [&_ol]:pl-5 "
         "[&_li]:my-0.5 "
         "[&_li_input]:mr-1.5 [&_li_input]:accent-primary [&_li:has(input)]:list-none [&_li:has(input)]:-ml-5 "
         "[&_h1]:mt-2 [&_h1]:mb-1 [&_h1]:text-base [&_h1]:font-semibold "
         "[&_h2]:mt-2 [&_h2]:mb-1 [&_h2]:text-sm [&_h2]:font-semibold "
         "[&_h3]:mt-2 [&_h3]:mb-1 [&_h3]:text-sm [&_h3]:font-medium "
         "[&_strong]:font-semibold [&_em]:italic "
         "[&_a]:text-primary [&_a]:underline [&_a]:underline-offset-2 "
         "[&_code]:rounded [&_code]:bg-muted [&_code]:px-1 [&_code]:py-0.5 [&_code]:text-[0.85em] "
         "[&_pre]:my-1 [&_pre]:overflow-x-auto [&_pre]:rounded-md [&_pre]:bg-muted [&_pre]:p-2 "
         "[&_pre_code]:bg-transparent [&_pre_code]:p-0 "
         "[&_blockquote]:my-1 [&_blockquote]:border-l-2 [&_blockquote]:border-border [&_blockquote]:pl-3 [&_blockquote]:text-muted-foreground "
         "[&_table]:my-1 [&_table]:w-full [&_table]:border-collapse "
         "[&_th]:border [&_th]:px-2 [&_th]:py-1 [&_th]:text-left [&_th]:font-medium "
         "[&_td]:border [&_td]:px-2 [&_td]:py-1 "
         "[&_hr]:my-2"
     );

def:pub Markdown(text: str, className: str = "") -> JsxElement {
    return
        <div className={cn(PROSE, className)}>
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{text}</ReactMarkdown>
        </div>;
}
