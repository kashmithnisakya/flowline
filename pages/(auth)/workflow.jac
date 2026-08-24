"""flowline - /workflow redirect. The page moved to /flowlines when the feature
was renamed; this keeps old links and bookmarks landing on the right tab.
"""

def:pub WorkflowRedirect -> JsxPage {
    can with entry {
        # replace(), not href: the old URL should not stay in history behind
        # the new one, or Back would bounce straight into the redirect again.
        window.location.replace("/flowlines" + window.location.search);
    }

    return <div className="min-h-[40svh]"/>;
}
