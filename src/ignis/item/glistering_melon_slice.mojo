"""GlisteringMelonSlice, ported from Dragonfly
`server/item/glistering_melon_slice.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GlisteringMelonSlice(Equatable, ImplicitlyCopyable, Item):
    """An inedible item used for brewing potions of healing."""

    comptime BASE_HASH: UInt64 = item_hash("GlisteringMelonSlice")
    """`item_hash("GlisteringMelonSlice")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:glistering_melon_slice", 0)

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
