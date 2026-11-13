"""Transactions, ported from Dragonfly `server/world/tx.go`.

In Go every world operation runs inside a transaction (`*Tx`) on the
world's goroutine, reached through `World.Exec`. Ignis runs everything on
one loop thread, so a transaction is simply the world itself: `Tx` is an
alias of `World`, and Go's `tx.SetBlock(...)` is `tx.set_block(...)` on a
`World` passed as `mut tx: Tx[T]`. `Tx.Defer` has no counterpart: code that
must run after the current callback runs after it.

The methods of Go's `Tx` live on `World` (`world.mojo`).
"""

from .world import World

comptime Tx = World
"""Go `*Tx`: the world, during the loop."""


@fieldwise_init
struct Context(Copyable, Defaultable):
    """A cancellable event scope passed to handlers (Go `Context`)."""

    var _cancel: Bool

    def __init__(out self):
        """Creates a context that is not cancelled (Go `Tx.Event`)."""
        self._cancel = False

    def cancelled(self) -> Bool:
        """Reports whether a handler cancelled the event (Go `Cancelled`).

        Returns:
            True if cancelled.
        """
        return self._cancel

    def cancel(mut self):
        """Cancels the event: its default behaviour does not run (Go
        `Cancel`)."""
        self._cancel = True


@fieldwise_init
struct SetOpts(Copyable, Defaultable, ImplicitlyCopyable):
    """Options that disable parts of `World.set_block` (Go `SetOpts`)."""

    var disable_block_updates: Bool
    """Do not update neighbouring blocks."""
    var disable_liquid_displacement: Bool
    """Do not move liquids between layers."""
    var disable_redstone_updates: Bool
    """Do not invalidate redstone around the block (no effect until
    redstone is ported)."""
    var keep_redstone_power: Bool
    """Keep the redstone power of the position (no effect until redstone
    is ported)."""

    def __init__(out self):
        """Creates options with every update enabled."""
        self.disable_block_updates = False
        self.disable_liquid_displacement = False
        self.disable_redstone_updates = False
        self.keep_redstone_power = False
