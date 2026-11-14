"""RawGold, ported from Dragonfly `server/item/raw_gold.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .gold_ingot import GoldIngot
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


@fieldwise_init
struct RawGold(Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A raw metal resource obtained from mining gold ore."""

    comptime BASE_HASH: UInt64 = item_hash("RawGold")
    """`item_hash("RawGold")`."""

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(GoldIngot(), 1), 1, ores=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:raw_gold", 0)

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
