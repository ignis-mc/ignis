"""Durable items, ported from Dragonfly `server/item/durability.go`."""

from .stack import Stack


@fieldwise_init
struct DurabilityInfo(Copyable, Equatable, Writable):
    """The durability of a durable item (Go `DurabilityInfo`).

    Go's `BrokenItem func() Stack` is not ported yet: every ported durable
    item breaks into nothing. Items that break into another item (elytra)
    add it when they are ported.
    """

    var max_durability: Int
    """The maximum durability; positive."""
    var attack_durability: Int
    """The durability lost when attacking with the item."""
    var break_durability: Int
    """The durability lost when breaking a block with the item."""
    var persistent: Bool
    """Whether the item stays at its last durability stage instead of
    breaking."""


trait Durable:
    """An item that has durability and may break (Go `Durable`)."""

    def durability_info(self) -> DurabilityInfo:
        """Returns the item's durability info.

        Returns:
            The info.
        """
        ...


trait Repairable(Durable):
    """A durable item that can be repaired with other items (Go
    `Repairable`)."""

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether the stack passed repairs the item.

        Args:
            i: The stack offered as repair material.

        Returns:
            True if it repairs the item.
        """
        ...
