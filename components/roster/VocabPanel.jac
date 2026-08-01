"""Workspace vocabulary: extend the category and section lists.

Built-in terms (constants.jac) show as locked chips; custom VocabTerm
nodes get a remove control. Removing a term never rewrites rows that
already use it, the category/section fields on entries are free text.
"""

import from ...models { VocabTerm }
import from ...constants { CATEGORIES, SECTIONS }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub VocabPanel(
    customCategories: list[VocabTerm],
    customSections: list[VocabTerm],
    newCategory: str,
    newSection: str,
    onNewCategory: Callable[[str], None],
    onNewSection: Callable[[str], None],
    onAdd: Callable[[str], None],
    onRemove: Callable[[str], None]
) -> JsxElement {
    <Card>
        <CardHeader>
            <CardTitle>Vocabulary</CardTitle>
            <CardDescription>
                The categories and sections offered in dropdowns. Add your own next to the built-ins.
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-5">
            <div className="space-y-2">
                <Label className="text-xs uppercase tracking-wide text-muted-foreground">Categories</Label>
                <div className="flex flex-wrap items-center gap-1.5">
                    {for c in CATEGORIES {
                        <Badge key={c} variant="secondary" className="font-normal">{c}</Badge>
                    }}
                    {for t in customCategories {
                        <Badge
                            key={jid(t)}
                            variant="outline"
                            className="cursor-pointer font-normal"
                            title="Click to remove"
                            onClick={lambda { onRemove(jid(t)); }}
                        >
                            {t.value} ✕
                        </Badge>
                    }}
                </div>
                <div className="flex gap-2">
                    <Input
                        placeholder="New category"
                        className="h-8"
                        value={newCategory}
                        onChange={lambda (e: ChangeEvent) { onNewCategory(e.target.value); }}
                        onKeyDown={lambda (e: KeyboardEvent) {
                            if e.key == "Enter" { onAdd("category"); }
                        }}
                    />
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={lambda { onAdd("category"); }}
                        disabled={not newCategory.strip()}
                    >
                        Add
                    </Button>
                </div>
            </div>
            <div className="space-y-2">
                <Label className="text-xs uppercase tracking-wide text-muted-foreground">Sections</Label>
                <div className="flex flex-wrap items-center gap-1.5">
                    {for s in SECTIONS {
                        <Badge key={s} variant="secondary" className="font-normal">{s}</Badge>
                    }}
                    {for t in customSections {
                        <Badge
                            key={jid(t)}
                            variant="outline"
                            className="cursor-pointer font-normal"
                            title="Click to remove"
                            onClick={lambda { onRemove(jid(t)); }}
                        >
                            {t.value} ✕
                        </Badge>
                    }}
                </div>
                <div className="flex gap-2">
                    <Input
                        placeholder="New section"
                        className="h-8"
                        value={newSection}
                        onChange={lambda (e: ChangeEvent) { onNewSection(e.target.value); }}
                        onKeyDown={lambda (e: KeyboardEvent) {
                            if e.key == "Enter" { onAdd("section"); }
                        }}
                    />
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={lambda { onAdd("section"); }}
                        disabled={not newSection.strip()}
                    >
                        Add
                    </Button>
                </div>
            </div>
        </CardContent>
    </Card>
}
