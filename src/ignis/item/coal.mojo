"""Coal, ported from Dragonfly `server/item/coal.go`.

`FuelInfo` follows with the furnace.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Coal(Equatable, ImplicitlyCopyable, Item):
    """An item used as fuel and for crafting torches."""

    comptime BASE_HASH: UInt64 = item_hash("Coal")
    """`item_hash("Coal")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`).

        Returns:
            `minecraft:coal`, metadata 0.
        """
        return EncodedItem("minecraft:coal", 0)

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
