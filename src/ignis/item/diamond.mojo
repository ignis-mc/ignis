"""Diamond, ported from Dragonfly `server/item/diamond.go`.

`TrimMaterial` and `MaterialColour` come with `ArmourTrimMaterial`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import BeaconPayment


@fieldwise_init
struct Diamond(BeaconPayment, Equatable, ImplicitlyCopyable, Item):
    """A rare mineral obtained from diamond ore or loot chests."""

    comptime BASE_HASH: UInt64 = item_hash("Diamond")
    """`item_hash("Diamond")`."""

    def payable_for_beacon(self) -> Bool:
        """Reports that diamonds pay for beacons (Go `PayableForBeacon`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`).

        Returns:
            `minecraft:diamond`, metadata 0.
        """
        return EncodedItem("minecraft:diamond", 0)

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
