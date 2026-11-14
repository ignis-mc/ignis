"""ClayBall, ported from Dragonfly `server/item/clay_ball.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .brick import Brick
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


@fieldwise_init
struct ClayBall(Equatable, ImplicitlyCopyable, Item, Smeltable):
    """Obtained from mining clay blocks."""

    comptime BASE_HASH: UInt64 = item_hash("ClayBall")
    """`item_hash("ClayBall")`."""

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Brick(), 1), 0.3)

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
