"""EnderEye, ported from Dragonfly `server/item/ender_eye.go`.

TODO(player): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct EnderEye(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """The item used to fill End portal frames."""

    comptime BASE_HASH: UInt64 = item_hash("EnderEye")
    """`item_hash("EnderEye")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 64

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:ender_eye", 0)

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
