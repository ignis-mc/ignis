"""RawCopper, ported from Dragonfly `server/item/raw_copper.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .copper_ingot import CopperIngot
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


@fieldwise_init
struct RawCopper(Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A raw metal resource obtained from mining copper ore."""

    comptime BASE_HASH: UInt64 = item_hash("RawCopper")
    """`item_hash("RawCopper")`."""

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(CopperIngot(), 1), 0.7, ores=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:raw_copper", 0)

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
