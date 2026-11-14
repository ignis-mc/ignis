"""InkSac, ported from Dragonfly `server/item/ink_sac.go`.

TODO(player): `UseOnBlock` (inking signs, Go `inkable`).
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct InkSac(Equatable, ImplicitlyCopyable, Item):
    """An item dropped by squids, used to make black dye, dark prismarine and
    book and quills. The glowing variant makes sign text light up."""

    comptime BASE_HASH: UInt64 = item_hash("InkSac")
    """`item_hash("InkSac")`."""

    var glowing: Bool
    """Whether the ink sac is the glowing variant of a glow squid."""

    def __init__(out self):
        """Creates a plain ink sac (Go `InkSac{}`)."""
        self.glowing = False

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.glowing:
            return EncodedItem("minecraft:glow_ink_sac", 0)
        return EncodedItem("minecraft:ink_sac", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: 1 if glowing."""
        return UInt64(1) if self.glowing else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return InkSac(glowing=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [InkSac(glowing=True), InkSac()]
