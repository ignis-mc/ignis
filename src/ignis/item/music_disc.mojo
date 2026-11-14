"""MusicDisc, ported from Dragonfly `server/item/music_disc.go`."""

from ..world.item import EncodedItem, Item, item_hash
from ..world.sound.disc_type import DiscType, music_discs
from .item import MaxCounter


struct MusicDisc(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item that can be played in jukeboxes."""

    comptime BASE_HASH: UInt64 = item_hash("MusicDisc")
    """`item_hash("MusicDisc")`."""

    var disc_type: DiscType
    """The disc, which decides the music it plays."""

    def __init__(out self, *, disc_type: DiscType = DiscType.DISC_13):
        """Creates the item; omitted fields take Go zero values."""
        self.disc_type = disc_type

    def __eq__(self, other: Self) -> Bool:
        """Compares two discs by type."""
        return self.disc_type == other.disc_type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:music_disc_{self.disc_type}"), 0)

    def hash(self) -> UInt64:
        """Returns the item hash: the disc type."""
        return UInt64(self.disc_type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(disc_type=DiscType(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every disc."""
        var out = List[Self]()
        for d in music_discs():
            out.append(Self(disc_type=d))
        return out^
