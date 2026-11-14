"""EchoShard, ported from Dragonfly `server/item/echo_shard.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct EchoShard(Equatable, ImplicitlyCopyable, Item):
    """An item found in ancient cities which can be used to craft recovery compasses.
    """

    comptime BASE_HASH: UInt64 = item_hash("EchoShard")
    """`item_hash("EchoShard")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:echo_shard", 0)

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
