"""Wheat, ported from Dragonfly `server/item/wheat.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import Compostable


@fieldwise_init
struct Wheat(Compostable, Equatable, ImplicitlyCopyable, Item):
    """A crop used to craft bread, cake, & cookies."""

    comptime BASE_HASH: UInt64 = item_hash("Wheat")
    """`item_hash("Wheat")`."""

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:wheat", 0)

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
