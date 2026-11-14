"""ClayBall, ported from Dragonfly `server/item/clay_ball.go`.

TODO(port): `SmeltInfo`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct ClayBall(Equatable, ImplicitlyCopyable, Item):
    """Obtained from mining clay blocks"""

    comptime BASE_HASH: UInt64 = item_hash("ClayBall")
    """`item_hash("ClayBall")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:clay_ball", 0)

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
