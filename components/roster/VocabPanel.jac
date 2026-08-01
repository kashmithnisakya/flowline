"""Workspace vocabulary: extend the category and section lists.

Every term is org-defined (no built-ins). Removing a term never rewrites
rows that already use it; category/tag values on entries are free text.
"""

import from ...models { VocabTerm }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub VocabPanel(
    customCategories: list[VocabTerm],
    customTags: list[VocabTerm],
    newCategory: str,
    newTag: str,
    onNewCategory: Callable[[str], None],
    onNewTag: Callable[[str], None],
    onAdd: Callable[[str], None],
    onRemove: Callable[[str], None]
) -> JsxElement {
    <>
    <Card>
        <CardHeader>
            <CardTitle>Categories</CardTitle>
            <CardDescription>
                Label the work in board and log dropdowns.
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
            <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-1.5">
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
        </CardContent>
    </Card>
    <Card>
        <CardHeader>
            <CardTitle>Tags</CardTitle>
            <CardDescription>
                Label your people; pick them on each member.
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
            <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-1.5">
                    {for t in customTags {
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
                        placeholder="New tag"
                        className="h-8"
                        value={newTag}
                        onChange={lambda (e: ChangeEvent) { onNewTag(e.target.value); }}
                        onKeyDown={lambda (e: KeyboardEvent) {
                            if e.key == "Enter" { onAdd("tag"); }
                        }}
                    />
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={lambda { onAdd("tag"); }}
                        disabled={not newTag.strip()}
                    >
                        Add
                    </Button>
                </div>
            </div>
        </CardContent>
    </Card>
    </>
}
