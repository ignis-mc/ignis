"""GoldIngot, ported from Dragonfly `server/item/gold_ingot.go`.

TODO(port): `TrimMaterial`, `MaterialColour`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import BeaconPayment


@fieldwise_init
struct GoldIngot(BeaconPayment, Equatable, ImplicitlyCopyable, Item):
    """A metal ingot melted from raw gold or obtained from loot chests."""

    comptime BASE_HASH: UInt64 = item_hash("GoldIngot")
    """`item_hash("GoldIngot")`."""

    def payable_for_beacon(self) -> Bool:
        """Reports that the item pays for beacons (Go `PayableForBeacon`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:gold_ingot", 0)

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
