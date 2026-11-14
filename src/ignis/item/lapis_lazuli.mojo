"""LapisLazuli, ported from Dragonfly `server/item/lapis_lazuli.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .armour_trim import ArmourTrimMaterial


@fieldwise_init
struct LapisLazuli(ArmourTrimMaterial, Equatable, ImplicitlyCopyable, Item):
    """A mineral used for enchanting and decoration."""

    comptime BASE_HASH: UInt64 = item_hash("LapisLazuli")
    """`item_hash("LapisLazuli")`."""

    def trim_material(self) -> StaticString:
        """Returns the trim material identifier (Go `TrimMaterial`)."""
        return "lapis"

    def material_colour(self) -> StaticString:
        """Returns the trim text colour (Go `MaterialColour`, `text.Lapis`)."""
        return "§t"

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:lapis_lazuli", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the type has one value."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]
