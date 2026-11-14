"""`BannerPatternType`, ported from Dragonfly
`server/item/banner_pattern_type.go`.
"""

from ..internal.enum import enum_name


struct BannerPatternType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a banner pattern item (Go `BannerPatternType`)."""

    var _v: UInt8

    comptime CREEPER = BannerPatternType(0)
    """Go `CreeperBannerPattern()`."""
    comptime SKULL = BannerPatternType(1)
    """Go `SkullBannerPattern()`."""
    comptime FLOWER = BannerPatternType(2)
    """Go `FlowerBannerPattern()`."""
    comptime MOJANG = BannerPatternType(3)
    """Go `MojangBannerPattern()`."""
    comptime FIELD_MASONED = BannerPatternType(4)
    """Go `FieldMasonedBannerPattern()`."""
    comptime BORDURE_INDENTED = BannerPatternType(5)
    """Go `BordureIndentedBannerPattern()`."""
    comptime PIGLIN = BannerPatternType(6)
    """Go `PiglinBannerPattern()`."""
    comptime GLOBE = BannerPatternType(7)
    """Go `GlobeBannerPattern()`."""
    comptime FLOW = BannerPatternType(8)
    """Go `FlowBannerPattern()`."""
    comptime GUSTER = BannerPatternType(9)
    """Go `GusterBannerPattern()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `BannerPatternType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the value's name (Go `String`)."""
        return enum_name(
            (
                "creeper,skull,flower,mojang,field_masoned,bordure_indented,"
                "piglin,globe,flow,guster"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's name (Go `String`)."""
        writer.write(self.name())


def banner_patterns() -> List[BannerPatternType]:
    """Returns every value (Go `BannerPatterns`)."""
    var out = List[BannerPatternType](capacity=10)
    for i in range(10):
        out.append(BannerPatternType(i))
    return out^
