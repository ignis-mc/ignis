"""Copper oxidation, ported from Dragonfly `server/block/oxidizable.go`.

TODO(world-runtime): attemptOxidation, which needs `world.Tx`.
"""

from ..world.block import Block
from .oxidation_type import OxidationType


trait Oxidisable(Block):
    """A copper block that oxidises over time (Go `Oxidisable`)."""

    def can_oxidate(self) -> Bool:
        """Reports whether the block can still oxidise (Go `CanOxidate`).

        Returns:
            True unless the block is waxed.
        """
        ...

    def oxidation_level(self) -> OxidationType:
        """Returns the oxidation level (Go `OxidationLevel`).

        Returns:
            The oxidation level.
        """
        ...

    def with_oxidation_level(self, o: OxidationType) -> Self:
        """Returns the block with another oxidation level (Go
        `WithOxidationLevel`).

        Args:
            o: The new oxidation level.

        Returns:
            The updated block.
        """
        ...


def copper_block_name(
    block_name: StringSlice, oxidation: OxidationType, waxed: Bool
) -> String:
    """Returns the name of a copper block with its oxidation and wax
    prefixes (Go `copperBlockName`).

    Args:
        block_name: The name without prefixes or namespace.
        oxidation: The oxidation level.
        waxed: Whether the block is waxed.

    Returns:
        The namespaced name.
    """
    var name = String(block_name)
    if oxidation != OxidationType.UNOXIDISED:
        name = String(t"{oxidation}_{name}")
    if waxed:
        name = "waxed_" + name
    return "minecraft:" + name
