"""GlowstoneDust, ported from Dragonfly `server/item/glowstone_dust.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GlowstoneDust(Equatable, ImplicitlyCopyable, Item):
    """Dropped when breaking the glowstone block."""

    comptime BASE_HASH: UInt64 = item_hash("GlowstoneDust")
    """`item_hash("GlowstoneDust")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:glowstone_dust", 0)

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
