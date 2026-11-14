"""EnchantedBook, ported from Dragonfly `server/item/enchanted_book.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct EnchantedBook(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item that lets players add enchantments to certain items using an anvil.
    """

    comptime BASE_HASH: UInt64 = item_hash("EnchantedBook")
    """`item_hash("EnchantedBook")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:enchanted_book", 0)

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
