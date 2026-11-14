"""Banner pattern layers, ported from Dragonfly
`server/block/banner_pattern_layer.go`."""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32, get_string
from ..item.colour import Colour
from ..world.block import NBTer
from .banner import invert_colour, invert_colour_id
from .banner_pattern_type import (
    BannerPatternType,
    banner_pattern_by_id,
    banner_pattern_id,
)


@fieldwise_init
struct BannerPatternLayer(Defaultable, Equatable, ImplicitlyCopyable, NBTer):
    """A pattern of one colour on a banner (Go `BannerPatternLayer`)."""

    var type: BannerPatternType
    """The pattern."""
    var colour: Colour
    """The colour of the pattern."""

    def __init__(out self):
        """Creates the zero layer (Go `BannerPatternLayer{}`)."""
        self.type = BannerPatternType(0)
        self.colour = Colour(0)

    def __eq__(self, other: Self) -> Bool:
        """Compares two layers.

        Args:
            other: The layer to compare with.

        Returns:
            True if both have the same pattern and colour.
        """
        return self.type == other.type and self.colour == other.colour

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the layer's NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "Pattern", banner_pattern_id(self.type))
        _ = tag.put_int(root, "Color", Int32(invert_colour(self.colour)))

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the layer decoded from NBT (Go `DecodeNBT`); raises on an
        unknown pattern, where Go panics."""
        var id = get_string(tag, root, "Pattern")
        var pattern = banner_pattern_by_id(id)
        if not pattern:
            raise Error(t"unknown banner pattern id {id}")
        return Self(
            pattern.value(),
            invert_colour_id(Int16(get_int32(tag, root, "Color"))),
        )
