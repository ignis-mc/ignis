"""BannerPattern, ported from Dragonfly `server/item/banner_pattern.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .banner_pattern_type import BannerPatternType, banner_patterns
from .item import MaxCounter


struct BannerPattern(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item used to customise banners inside looms."""

    comptime BASE_HASH: UInt64 = item_hash("BannerPattern")
    """`item_hash("BannerPattern")`."""

    var type: BannerPatternType
    """The pattern type."""

    def __init__(out self, *, type: BannerPatternType = BannerPatternType(0)):
        """Creates the item; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two items."""
        return self.type == other.type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`): 1."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(
            String("minecraft:", self.type.name(), "_banner_pattern"), 0
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the pattern type's index."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(type=BannerPatternType(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every pattern type.
        """
        var out = List[Self]()
        for t in banner_patterns():
            out.append(Self(type=t))
        return out^
