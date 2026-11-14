"""`BannerPatternType`, ported from Dragonfly `server/block/banner_pattern_type.go`
and `banner_pattern_type_register.go`.
"""

from ..internal.enum import enum_name


struct BannerPatternType(Equatable, ImplicitlyCopyable, Writable):
    """A pattern that can be applied to a banner (Go `BannerPatternType`)."""

    var _v: UInt8

    comptime BORDER = BannerPatternType(0)
    """Go `BorderBannerPattern()`."""
    comptime BRICKS = BannerPatternType(1)
    """Go `BricksBannerPattern()`."""
    comptime CIRCLE = BannerPatternType(2)
    """Go `CircleBannerPattern()`."""
    comptime CREEPER = BannerPatternType(3)
    """Go `CreeperBannerPattern()`."""
    comptime CROSS = BannerPatternType(4)
    """Go `CrossBannerPattern()`."""
    comptime CURLY_BORDER = BannerPatternType(5)
    """Go `CurlyBorderBannerPattern()`."""
    comptime DIAGONAL_LEFT = BannerPatternType(6)
    """Go `DiagonalLeftBannerPattern()`."""
    comptime DIAGONAL_RIGHT = BannerPatternType(7)
    """Go `DiagonalRightBannerPattern()`."""
    comptime DIAGONAL_UP_LEFT = BannerPatternType(8)
    """Go `DiagonalUpLeftBannerPattern()`."""
    comptime DIAGONAL_UP_RIGHT = BannerPatternType(9)
    """Go `DiagonalUpRightBannerPattern()`."""
    comptime FLOWER = BannerPatternType(10)
    """Go `FlowerBannerPattern()`."""
    comptime GRADIENT = BannerPatternType(11)
    """Go `GradientBannerPattern()`."""
    comptime GRADIENT_UP = BannerPatternType(12)
    """Go `GradientUpBannerPattern()`."""
    comptime HALF_HORIZONTAL = BannerPatternType(13)
    """Go `HalfHorizontalBannerPattern()`."""
    comptime HALF_HORIZONTAL_BOTTOM = BannerPatternType(14)
    """Go `HalfHorizontalBottomBannerPattern()`."""
    comptime HALF_VERTICAL = BannerPatternType(15)
    """Go `HalfVerticalBannerPattern()`."""
    comptime HALF_VERTICAL_RIGHT = BannerPatternType(16)
    """Go `HalfVerticalRightBannerPattern()`."""
    comptime MOJANG = BannerPatternType(17)
    """Go `MojangBannerPattern()`."""
    comptime RHOMBUS = BannerPatternType(18)
    """Go `RhombusBannerPattern()`."""
    comptime SKULL = BannerPatternType(19)
    """Go `SkullBannerPattern()`."""
    comptime SMALL_STRIPES = BannerPatternType(20)
    """Go `SmallStripesBannerPattern()`."""
    comptime SQUARE_BOTTOM_LEFT = BannerPatternType(21)
    """Go `SquareBottomLeftBannerPattern()`."""
    comptime SQUARE_BOTTOM_RIGHT = BannerPatternType(22)
    """Go `SquareBottomRightBannerPattern()`."""
    comptime SQUARE_TOP_LEFT = BannerPatternType(23)
    """Go `SquareTopLeftBannerPattern()`."""
    comptime SQUARE_TOP_RIGHT = BannerPatternType(24)
    """Go `SquareTopRightBannerPattern()`."""
    comptime STRAIGHT_CROSS = BannerPatternType(25)
    """Go `StraightCrossBannerPattern()`."""
    comptime STRIPE_BOTTOM = BannerPatternType(26)
    """Go `StripeBottomBannerPattern()`."""
    comptime STRIPE_CENTRE = BannerPatternType(27)
    """Go `StripeCentreBannerPattern()`."""
    comptime STRIPE_DOWN_LEFT = BannerPatternType(28)
    """Go `StripeDownLeftBannerPattern()`."""
    comptime STRIPE_DOWN_RIGHT = BannerPatternType(29)
    """Go `StripeDownRightBannerPattern()`."""
    comptime STRIPE_LEFT = BannerPatternType(30)
    """Go `StripeLeftBannerPattern()`."""
    comptime STRIPE_MIDDLE = BannerPatternType(31)
    """Go `StripeMiddleBannerPattern()`."""
    comptime STRIPE_RIGHT = BannerPatternType(32)
    """Go `StripeRightBannerPattern()`."""
    comptime STRIPE_TOP = BannerPatternType(33)
    """Go `StripeTopBannerPattern()`."""
    comptime TRIANGLE_BOTTOM = BannerPatternType(34)
    """Go `TriangleBottomBannerPattern()`."""
    comptime TRIANGLE_TOP = BannerPatternType(35)
    """Go `TriangleTopBannerPattern()`."""
    comptime TRIANGLES_BOTTOM = BannerPatternType(36)
    """Go `TrianglesBottomBannerPattern()`."""
    comptime TRIANGLES_TOP = BannerPatternType(37)
    """Go `TrianglesTopBannerPattern()`."""
    comptime GLOBE = BannerPatternType(38)
    """Go `GlobeBannerPattern()`."""
    comptime PIGLIN = BannerPatternType(39)
    """Go `PiglinBannerPattern()`."""
    comptime FLOW = BannerPatternType(40)
    """Go `FlowBannerPattern()`."""
    comptime GUSTER = BannerPatternType(41)
    """Go `GusterBannerPattern()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `BannerPatternType{v}`).

        Args:
            v: 0 to 41.
        """
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both are the same.
        """
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 to 41.
        """
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "border,bricks,circle,creeper,cross,curly_border,"
                    "diagonal_left,diagonal_right,diagonal_up_left,"
                    "diagonal_up_right,flower,gradient,gradient_up,"
                    "half_horizontal,half_horizontal_bottom,half_vertical,"
                    "half_vertical_right,mojang,rhombus,skull,small_stripes,"
                    "square_bottom_left,square_bottom_right,square_top_left,"
                    "square_top_right,straight_cross,stripe_bottom,"
                    "stripe_center,stripe_downleft,stripe_downright,"
                    "stripe_left,stripe_middle,stripe_right,stripe_top,"
                    "triangle_bottom,triangle_top,triangles_bottom,"
                    "triangles_top,globe,piglin,flow,guster"
                ),
                Int(self._v),
            )
        )


def banner_pattern_types() -> List[BannerPatternType]:
    """Returns every banner pattern (Go `BannerPatternTypes`).

    Returns:
        The values.
    """
    var out = List[BannerPatternType](capacity=42)
    for i in range(42):
        out.append(BannerPatternType(i))
    return out^


comptime _BANNER_PATTERN_IDS = (
    "bo,bri,mc,cre,cr,cbo,lud,rd,ld,rud,flo,gra,gru,hh,hhb,"
    "vh,vhr,moj,mr,sku,ss,bl,br,tl,tr,sc,bs,cs,dls,drs,ls,ms,"
    "rs,ts,bt,tt,bts,tts,glb,pig,flw,gus"
)
"""The NBT IDs of the patterns, in value order (Go `registerBannerPattern`)."""


def banner_pattern_by_id(id: StringSlice) -> Optional[BannerPatternType]:
    """Looks up a pattern by its NBT ID (Go `BannerPatternByID`).

    Args:
        id: The ID, such as `bo`.

    Returns:
        The pattern, or None for an unknown ID.
    """
    for i in range(42):
        if enum_name(_BANNER_PATTERN_IDS, i) == id:
            return BannerPatternType(i)
    return None


def banner_pattern_id(pattern: BannerPatternType) -> StaticString:
    """Returns the NBT ID of a pattern (Go `bannerPatternID`).

    Args:
        pattern: The pattern.

    Returns:
        The ID.
    """
    return enum_name(_BANNER_PATTERN_IDS, Int(pattern.uint8()))
