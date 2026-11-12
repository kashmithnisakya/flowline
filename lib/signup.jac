"""Turns a failed signup into one short line for the form. The server's own
text is never shown: it names policies and internals, and the runtime drops
the error code, so the message is matched by its wording.
"""

glob SIGNUP_REASONS: list[list[str]] = [
         ["already registered", "That email already has an account. Try signing in."],
         [
             "too common",
             "That password is too easy to guess. Choose a less common one."
         ],
         ["too short", "That password is too short. Use at least 8 characters."],
         ["username or email", "Your password can't contain your email."]
     ];

# Fallbacks by status: a rejected request is the user's input, the rest is ours.
def:pub signupProblem(res: any) -> str {
    said: str = str(res["error"] if res["error"] else "").lower();
    for pair in SIGNUP_REASONS {
        if pair[0] in said {
            return pair[1];
        }
    }
    if res["status"] == 400 or res["status"] == 422 {
        return "Check your email and password, then try again.";
    }
    return "We couldn't create your account right now. Try again.";
}
