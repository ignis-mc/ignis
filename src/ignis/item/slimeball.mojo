"""Slimeball, ported from Dragonfly `server/item/slimeball.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Slimeball(Equatable, ImplicitlyCopyable, Item):
    """A crafting ingredient commonly dropped by slimes, and can be sneezed out by pandas.
    """

    comptime BASE_HASH: UInt64 = item_hash("Slimeball")
    """`item_hash("Slimeball")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:slime_ball", 0)

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
