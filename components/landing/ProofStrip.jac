"""The proof bar under the hero: four facts that are true on every server, in
mono between hairlines. No logos, counts or quotes."""

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     FACT: str = "py-1.5 pr-4 sm:mr-3.5 sm:border-r sm:py-2 sm:pr-3.5 sm:last:mr-0 sm:last:border-r-0";

def:pub ProofStrip -> JsxElement {
    return
        <ul
            aria-label="Facts about Flowline"
            className="flex flex-wrap border-y font-mono text-[12.5px] text-muted-foreground"
        >
            <li className={FACT}>MIT licensed</li>
            <li className={FACT}>
                <a
                    href={REPO_URL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="underline-offset-2 hover:text-foreground hover:underline"
                >
                    Source on GitHub
                </a>
            </li>
            <li className={FACT}>Built with Jac</li>
            <li className={FACT}>Each workspace is its own isolated graph</li>
        </ul>;
}
