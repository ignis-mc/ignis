"""Emerald, ported from Dragonfly `server/item/emerald.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .armour_trim import ArmourTrimMaterial
from .item import BeaconPayment


@fieldwise_init
struct Emerald(
    ArmourTrimMaterial, BeaconPayment, Equatable, ImplicitlyCopyable, Item
):
    """A rare mineral obtained from emerald ore or from villagers."""

    comptime BASE_HASH: UInt64 = item_hash("Emerald")
    """`item_hash("Emerald")`."""

    def payable_for_beacon(self) -> Bool:
        """Reports that the item pays for beacons (Go `PayableForBeacon`)."""
        return True

    def trim_material(self) -> StaticString:
        """Returns the trim material identifier (Go `TrimMaterial`)."""
        return "emerald"

    def material_colour(self) -> StaticString:
        """Returns the trim text colour (Go `MaterialColour`, `text.Emerald`).
        """
        return "§q"

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:emerald", 0)

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
