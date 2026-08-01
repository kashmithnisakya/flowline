"""Server-only helpers. Kept out of models.jac so that module stays free of
Python imports — client components import types from models, and a Python
anchor there would drag the wasm host into the browser bundle."""

import datetime;


def now_iso -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}
