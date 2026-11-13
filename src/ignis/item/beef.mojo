"""Beef, ported from Dragonfly `server/item/beef.go`.

`Consume` and `SmeltInfo` follow with players (`Consumer`) and the furnace.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Beef(Equatable, ImplicitlyCopyable, Item):
    """A food item obtained from cows. It can be cooked in a furnace, smoker,
    or campfire."""

    comptime BASE_HASH: UInt64 = item_hash("Beef")
    """`item_hash("Beef")`."""

    var cooked: Bool
    """Whether the beef is cooked."""

    def __init__(out self):
        """Creates raw beef (Go `Beef{}`)."""
        self.cooked = False

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`).

        Returns:
            `minecraft:cooked_beef` or `minecraft:beef`, metadata 0.
        """
        if self.cooked:
            return EncodedItem("minecraft:cooked_beef", 0)
        return EncodedItem("minecraft:beef", 0)

    def hash(self) -> UInt64:
        """Returns the item hash.

        Returns:
            1 for cooked beef, 0 otherwise.
        """
        return UInt64(1) if self.cooked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash.

        Args:
            hash: The hash.

        Returns:
            The beef.
        """
        return Beef(cooked=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Cooked beef and beef.
        """
        return [Beef(cooked=True), Beef()]
