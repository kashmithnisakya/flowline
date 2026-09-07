import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

def:pub cn(*inputs: any) -> str {
    return twMerge(clsx(inputs));
}

# A task estimate for display: whole numbers drop the ".0", so "3" not "3.0"
# and "1.5" stays. Shared by the card and the table so they read alike.
def:pub fmtEstimate(n: float) -> str {
    whole = int(n);
    if float(whole) == n {
        return str(whole);
    }
    return str(n);
}

# A form estimate string to the float the walker stores. Empty or unparseable
# reads as 0.0 (unestimated); a number input already keeps out non-numerics.
def:pub parseEstimate(raw: str) -> float {
    s = raw.strip();
    if not s {
        return 0.0;
    }
    try {
        val = float(s);
    } except Exception {
        return 0.0;
    }
    return val if val > 0.0 else 0.0;
}

# Accepts a pasted GitHub URL (https/ssh, optional .git) or bare org/repo
# and returns the normalized org/repo form ("" when nothing usable).
def:pub normalizeRepoInput(raw: str) -> str {
    cleaned = raw.strip();
    cleaned = cleaned.replace("https://github.com/", "");
    cleaned = cleaned.replace("http://github.com/", "");
    cleaned = cleaned.replace("git@github.com:", "");
    cleaned = cleaned.replace("www.github.com/", "");
    if cleaned.endswith(".git") {
        cleaned = cleaned[:-4];
    }
    cleaned = cleaned.strip("/");
    parts = [
        p
        for p in cleaned.split("/")
        if p
    ];
    if len(parts) >= 2 {
        return parts[0] + "/" + parts[1];
    }
    return cleaned;
}
