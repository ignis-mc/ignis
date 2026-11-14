"""PrismarineShard, ported from Dragonfly `server/item/prismarine_shard.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct PrismarineShard(Equatable, ImplicitlyCopyable, Item):
    """An item obtained by defeating guardians or elder guardians."""

    comptime BASE_HASH: UInt64 = item_hash("PrismarineShard")
    """`item_hash("PrismarineShard")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:prismarine_shard", 0)

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
