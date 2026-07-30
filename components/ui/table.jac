import from ...lib.utils { cn }

def:pub Table(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div data-slot="table-container" className="relative w-full overflow-x-auto">
        <table
            {**attrs}
            data-slot="table"
            className={cn("w-full caption-bottom text-sm", props["className"])}
        />
    </div>
}

def:pub TableHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <thead
        {**attrs}
        data-slot="table-header"
        className={cn("[&_tr]:border-b", props["className"])}
    />
}

def:pub TableBody(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <tbody
        {**attrs}
        data-slot="table-body"
        className={cn("[&_tr:last-child]:border-0", props["className"])}
    />
}

def:pub TableFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <tfoot
        {**attrs}
        data-slot="table-footer"
        className={cn("bg-muted/50 border-t font-medium [&>tr]:last:border-b-0", props["className"])}
    />
}

def:pub TableRow(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <tr
        {**attrs}
        data-slot="table-row"
        className={cn("hover:bg-muted/50 data-[state=selected]:bg-muted border-b transition-colors", props["className"])}
    />
}

def:pub TableHead(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <th
        {**attrs}
        data-slot="table-head"
        className={cn("text-foreground h-10 px-2 text-left align-middle font-medium whitespace-nowrap [&:has([role=checkbox])]:pr-0", props["className"])}
    />
}

def:pub TableCell(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <td
        {**attrs}
        data-slot="table-cell"
        className={cn("p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0", props["className"])}
    />
}

def:pub TableCaption(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <caption
        {**attrs}
        data-slot="table-caption"
        className={cn("text-muted-foreground mt-4 text-sm", props["className"])}
    />
}
