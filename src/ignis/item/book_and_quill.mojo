"""BookAndQuill, ported from Dragonfly `server/item/book_and_quill.go`.

TODO(port): `TotalPages`, `Page`, `DeletePage`, `InsertPage`, `SetPage`, `SwapPages`, `DecodeNBT`, `EncodeNBT`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct BookAndQuill(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item used to write WrittenBook(s)."""

    comptime BASE_HASH: UInt64 = item_hash("BookAndQuill")
    """`item_hash("BookAndQuill")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:writable_book", 0)

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
