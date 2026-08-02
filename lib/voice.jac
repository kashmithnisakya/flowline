"""Dictation via the browser's Web Speech API.

byLLM has no audio surface at all (Text / Image / Video only), so transcription
either happens in the browser or it means hand-rolling an OpenAI client, which
is outside the "byLLM only" rule. This is the browser route: free, no key, no
server round trip.

It is a *progressive enhancement*. `hasVoice()` gates the mic button so Firefox
and Safari see an ordinary composer rather than a button that does nothing.
Two honest caveats worth surfacing in the UI: it is Chromium-only in practice,
and Chrome ships the audio to a Google service to transcribe it.
"""

# Module-level mutable holder rather than a rebindable `glob`: only one
# recogniser may run at a time, and starting a second throws InvalidStateError.
glob _voice: dict[str, any] = {"rec": None};


# SpeechRecognition is not in the DOM typings the checker carries, so reach it
# through an untyped alias.
def _ctor -> any {
    w: any = window;
    return w.SpeechRecognition or w.webkitSpeechRecognition;
}

# True when this browser can transcribe. Everything else is gated on it.
def:pub hasVoice -> bool {
    if _ctor() {
        return True;
    }
    return False;
}

# Begin dictating. `onText` fires on every interim result so the composer fills
# in as the user speaks; `onEnd` fires once, on silence or on error, and is the
# only place the caller should clear its "listening" flag.
def:pub startVoice(onText: Callable[[str], None], onEnd: Callable[[], None]) -> bool {
    Ctor = _ctor();
    if not Ctor {
        return False;
    }
    stopVoice();
    rec: any = new(Ctor);
    rec.lang = window.navigator.language or "en-US";
    rec.interimResults = True;
    rec.continuous = False;
    rec.maxAlternatives = 1;
    rec.onresult = lambda (e: any) {
        # SpeechRecognitionResultList is array-like but not reliably iterable,
        # so walk it by index.
        text = "";
        i = 0;
        while i < e.results.length {
            text = text + e.results[i][0].transcript;
            i = i + 1;
        }
        onText(text);
    };
    rec.onerror = lambda (e: any) { onEnd(); };
    rec.onend = lambda { onEnd(); };
    try {
        rec.start();
    } except Exception as e {
        onEnd();
        return False;
    }
    _voice["rec"] = rec;
    return True;
}

# Stop dictating. Safe to call when nothing is running.
def:pub stopVoice -> None {
    rec: any = _voice["rec"];
    if not rec {
        return;
    }
    # Clear first: stop() throws if the recogniser already ended on its own,
    # and the handle is dead either way.
    _voice["rec"] = None;
    try {
        rec.stop();
    } except Exception as e {
        _voice["rec"] = None;
    }
}
