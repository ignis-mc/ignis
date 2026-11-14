"""IronNugget, ported from Dragonfly `server/item/iron_nugget.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct IronNugget(Equatable, ImplicitlyCopyable, Item):
    """A piece of iron that can be obtained by smelting iron tools/weapons or iron/chainmail armour.
    """

    comptime BASE_HASH: UInt64 = item_hash("IronNugget")
    """`item_hash("IronNugget")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:iron_nugget", 0)

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
