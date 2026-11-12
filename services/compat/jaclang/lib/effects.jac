"""Stand-in for `jaclang.lib.effects` until jaseci-labs/jac#10447 ships. The native
kernel ignores the real decorator; the effect pass honours one compiled from source
at a path ending in `jaclang/lib/effects.jac`, so this path must not change."""

import from jaclang.lib.effects { effects as declare }


def effects(reads: list[str], writes: list[str]) -> Callable {
    return declare(reads=reads, writes=writes);
}
