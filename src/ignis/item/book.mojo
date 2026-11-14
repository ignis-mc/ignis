"""Book, ported from Dragonfly `server/item/book.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .enchantment import Enchantable


@fieldwise_init
struct Book(Enchantable, Equatable, ImplicitlyCopyable, Item):
    """An item used in enchanting and crafting."""

    comptime BASE_HASH: UInt64 = item_hash("Book")
    """`item_hash("Book")`."""

    def enchantment_value(self) -> Int:
        """Returns the enchantability (Go `EnchantmentValue`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:book", 0)

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
