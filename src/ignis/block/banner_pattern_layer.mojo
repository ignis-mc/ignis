"""Banner pattern layers, ported from Dragonfly
`server/block/banner_pattern_layer.go`.

TODO(world-runtime): EncodeNBT and DecodeNBT, with block NBT.
"""

from ..item.colour import Colour
from .banner_pattern_type import BannerPatternType


@fieldwise_init
struct BannerPatternLayer(Equatable, ImplicitlyCopyable):
    """A pattern of one colour on a banner (Go `BannerPatternLayer`)."""

    var type: BannerPatternType
    """The pattern."""
    var colour: Colour
    """The colour of the pattern."""

    def __eq__(self, other: Self) -> Bool:
        """Compares two layers.

        Args:
            other: The layer to compare with.

        Returns:
            True if both have the same pattern and colour.
        """
        return self.type == other.type and self.colour == other.colour
