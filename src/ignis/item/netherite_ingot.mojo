"""NetheriteIngot, ported from Dragonfly `server/item/netherite_ingot.go`.

TODO(port): `TrimMaterial`, `MaterialColour`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import BeaconPayment


@fieldwise_init
struct NetheriteIngot(BeaconPayment, Equatable, ImplicitlyCopyable, Item):
    """A rare mineral crafted with 4 pieces of netherite scrap and 4 gold ingots.
    """

    comptime BASE_HASH: UInt64 = item_hash("NetheriteIngot")
    """`item_hash("NetheriteIngot")`."""

    def payable_for_beacon(self) -> Bool:
        """Reports that the item pays for beacons (Go `PayableForBeacon`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:netherite_ingot", 0)

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
