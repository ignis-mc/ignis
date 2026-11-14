"""Stick, ported from Dragonfly `server/item/stick.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .smelting_info import Fuel, FuelInfo


@fieldwise_init
struct Stick(Equatable, Fuel, ImplicitlyCopyable, Item):
    """One of the most abundant resources used for crafting many tools and items.
    """

    comptime BASE_HASH: UInt64 = item_hash("Stick")
    """`item_hash("Stick")`."""

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 5 s."""
        return FuelInfo(5000)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`).

        Returns:
            `minecraft:stick`, metadata 0.
        """
        return EncodedItem("minecraft:stick", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the type has one value.

        Returns:
            0.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash.

        Args:
            hash: The hash.

        Returns:
            The item.
        """
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            The one value.
        """
        return [Self()]
