"""MelonSlice, ported from Dragonfly `server/item/melon_slice.go`.

TODO(port): `AlwaysConsumable`, `ConsumeDuration`, `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Compostable


@fieldwise_init
struct MelonSlice(Compostable, Equatable, ImplicitlyCopyable, Item):
    """A food item dropped by melon blocks."""

    comptime BASE_HASH: UInt64 = item_hash("MelonSlice")
    """`item_hash("MelonSlice")`."""

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:melon_slice", 0)

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
