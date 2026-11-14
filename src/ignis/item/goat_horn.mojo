"""GoatHorn, ported from Dragonfly `server/item/goat_horn.go`.

TODO(player): `Use`, `releaseItem` and the `nopReleasable` release.
"""

from ..world.item import EncodedItem, Item, item_hash
from ..world.sound.goat_horn import Horn, goat_horns
from .item import Cooldown, MaxCounter


struct GoatHorn(Cooldown, Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item dropped by goats. Each of its eight variants plays a unique
    sound when used, heard by players in a large radius."""

    comptime BASE_HASH: UInt64 = item_hash("GoatHorn")
    """`item_hash("GoatHorn")`."""

    var type: Horn
    """The type of the horn, which decides its sound."""

    def __init__(out self, *, type: Horn = Horn.PONDER):
        """Creates the item; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two horns by type."""
        return self.type == other.type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def cooldown(self) -> Int:
        """Returns the cooldown (Go `Cooldown`): 7 s."""
        return 7000

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): meta is the horn type."""
        return EncodedItem("minecraft:goat_horn", Int16(self.type.uint8()))

    def hash(self) -> UInt64:
        """Returns the item hash: the horn type."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(type=Horn(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every horn."""
        var out = List[Self]()
        for h in goat_horns():
            out.append(Self(type=h))
        return out^
