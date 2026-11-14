"""LapisLazuli, ported from Dragonfly `server/item/lapis_lazuli.go`.

TODO(port): `TrimMaterial`, `MaterialColour`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct LapisLazuli(Equatable, ImplicitlyCopyable, Item):
    """A mineral used for enchanting and decoration."""

    comptime BASE_HASH: UInt64 = item_hash("LapisLazuli")
    """`item_hash("LapisLazuli")`."""

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
