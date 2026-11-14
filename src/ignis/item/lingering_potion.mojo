"""LingeringPotion, ported from Dragonfly `server/item/lingering_potion.go`.

`Use` is `server.use.use_item` with `entity.throw`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter
from .potion.potion import Potion, all_potions


struct LingeringPotion(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A variant of a splash potion that can be thrown to leave clouds with
    status effects that linger on the ground in an area."""

    comptime BASE_HASH: UInt64 = item_hash("LingeringPotion")
    """`item_hash("LingeringPotion")`."""

    var type: Potion
    """The type of the potion."""

    def __init__(out self, *, type: Potion = Potion()):
        """Creates the item; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two potions by type."""
        return self.type == other.type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): the type's ID is the meta."""
        return EncodedItem(
            "minecraft:lingering_potion", Int16(self.type.uint8())
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the potion ID."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(type=Potion(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every type."""
        var out = List[Self]()
        for p in all_potions():
            out.append(Self(type=p))
        return out^
