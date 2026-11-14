"""Bowl, ported from Dragonfly `server/item/bowl.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .smelting_info import Fuel, FuelInfo


@fieldwise_init
struct Bowl(Equatable, Fuel, ImplicitlyCopyable, Item):
    """A container that can hold certain foods."""

    comptime BASE_HASH: UInt64 = item_hash("Bowl")
    """`item_hash("Bowl")`."""

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 10 s."""
        return FuelInfo(10000)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bowl", 0)

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
