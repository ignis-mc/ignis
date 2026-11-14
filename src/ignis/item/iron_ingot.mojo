"""IronIngot, ported from Dragonfly `server/item/iron_ingot.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .armour_trim import ArmourTrimMaterial
from .item import BeaconPayment


@fieldwise_init
struct IronIngot(
    ArmourTrimMaterial, BeaconPayment, Equatable, ImplicitlyCopyable, Item
):
    """A metal ingot melted from raw iron or obtained from loot chests."""

    comptime BASE_HASH: UInt64 = item_hash("IronIngot")
    """`item_hash("IronIngot")`."""

    def payable_for_beacon(self) -> Bool:
        """Reports that the item pays for beacons (Go `PayableForBeacon`)."""
        return True

    def trim_material(self) -> StaticString:
        """Returns the trim material identifier (Go `TrimMaterial`)."""
        return "iron"

    def material_colour(self) -> StaticString:
        """Returns the trim text colour (Go `MaterialColour`, `text.Iron`)."""
        return "§i"

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:iron_ingot", 0)

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
