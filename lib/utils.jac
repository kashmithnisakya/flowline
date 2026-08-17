import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

def:pub cn(*inputs: any) -> str {
    return twMerge(clsx(inputs));
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
