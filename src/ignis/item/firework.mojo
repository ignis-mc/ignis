"""Firework, ported from Dragonfly `server/item/firework.go`.

TODO(port): `Use`, `UseOnBlock`, `EncodeNBT`, `DecodeNBT`, `RandomisedDuration`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import OffHand


@fieldwise_init
struct Firework(Equatable, ImplicitlyCopyable, Item, OffHand):
    """An item (and entity) used for creating decorative explosions, boosting
    when flying with elytra, and loading into a crossbow as ammunition."""

    comptime BASE_HASH: UInt64 = item_hash("Firework")
    """`item_hash("Firework")`."""

    def off_hand(self) -> Bool:
        """Reports that the item may be held in the off hand (Go `OffHand`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:firework_rocket", 0)

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
