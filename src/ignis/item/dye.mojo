"""Dye, ported from Dragonfly `server/item/dye.go`.

TODO(player): `UseOnBlock` (dyeing blocks) and the `dyeable` interface.
"""

from ..world.item import EncodedItem, Item, item_hash
from .colour import Colour, colours


@fieldwise_init
struct Dye(Equatable, ImplicitlyCopyable, Item):
    """An item that comes in 16 colours and dyes blocks and entities."""

    comptime BASE_HASH: UInt64 = item_hash("Dye")
    """`item_hash("Dye")`."""

    var colour: Colour
    """The colour of the dye."""

    def __init__(out self):
        """Creates white dye (Go `Dye{}`)."""
        self.colour = Colour.WHITE

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.colour}_dye"), 0)

    def hash(self) -> UInt64:
        """Returns the item hash: the colour."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Dye(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every colour."""
        var out = List[Self](capacity=16)
        for c in colours():
            out.append(Dye(colour=c))
        return out^
