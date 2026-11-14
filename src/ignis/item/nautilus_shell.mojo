"""NautilusShell, ported from Dragonfly `server/item/nautilus_shell.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import OffHand


@fieldwise_init
struct NautilusShell(Equatable, ImplicitlyCopyable, Item, OffHand):
    """An item that is used for crafting conduits."""

    comptime BASE_HASH: UInt64 = item_hash("NautilusShell")
    """`item_hash("NautilusShell")`."""

    def off_hand(self) -> Bool:
        """Reports that the item may be held in the off hand (Go `OffHand`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:nautilus_shell", 0)

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
