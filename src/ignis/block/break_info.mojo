"""Block breaking data, ported from Dragonfly `server/block/break_info.go`.

Go's `BreakInfo` holds closures over `item.Tool`. Here the `Harvestable`
and `Effective` closures are `ToolFilter` values: the `item.ToolType`s they
accept and the minimum harvest level, which is all any Dragonfly block
checks; `matches_tool` applies one to an `item.Tool`. `Drops`, `BreakHandler`, `BreakDuration` and the
drop helpers (`oneOf`, `silkTouchOneOf`, fortune) need items and `world.Tx`:
TODO(world-runtime) port them with `item.Tool`, `item.Stack` and `Tx`.
"""

from std.math import ceil

from ..item.enchantment.efficiency import Efficiency
from ..item.stack import Stack
from ..item.tool import (
    TYPE_AXE,
    TYPE_HOE,
    TYPE_PICKAXE,
    TYPE_SHEARS,
    TYPE_SHOVEL,
    TYPE_SWORD,
    Tool,
    ToolInfo,
    ToolType,
)

comptime HARVEST_LEVEL_WOOD = 1
"""Go `item.ToolTierWood.HarvestLevel` (gold is the same)."""
comptime HARVEST_LEVEL_STONE = 2
"""Go `item.ToolTierStone.HarvestLevel` (copper is the same)."""
comptime HARVEST_LEVEL_IRON = 3
"""Go `item.ToolTierIron.HarvestLevel`."""
comptime HARVEST_LEVEL_DIAMOND = 4
"""Go `item.ToolTierDiamond.HarvestLevel` (netherite is the same)."""


@fieldwise_init
struct ToolFilter(Equatable, ImplicitlyCopyable, Writable):
    """Which tools a `BreakInfo` predicate accepts (Go
    `func(item.Tool) bool`): a tool matches if its type is in the set and its
    harvest level is at least `min_level`."""

    var types: UInt8
    """Bit `type + 1` is set for each accepted tool type (bit 0: no tool)."""
    var min_level: Int
    """The minimum harvest level of an accepted tool."""

    def __init__(out self, *tool_types: ToolType, min_level: Int = 0):
        """Creates a filter accepting the tool types passed."""
        self.types = 0
        for t in tool_types:
            self.types |= UInt8(1) << UInt8(t.t + 1)
        self.min_level = min_level

    def __eq__(self, other: Self) -> Bool:
        """Compares two filters."""
        return self.types == other.types and self.min_level == other.min_level

    def __or__(self, other: Self) -> Self:
        """Combines two filters with the same minimum level (Go
        `f(t) || g(t)`)."""
        return ToolFilter(
            types=self.types | other.types,
            min_level=min(self.min_level, other.min_level),
        )

    def matches(self, tool_type: ToolType, harvest_level: Int) -> Bool:
        """Calls the predicate for a tool's type and harvest level."""
        return (
            (self.types >> UInt8(tool_type.t + 1)) & 1 != 0
        ) and harvest_level >= self.min_level

    def matches_tool[T: Tool](self, t: T) -> Bool:
        """Calls the predicate for a tool (Go `f(t)`)."""
        return self.matches(t.tool_type(), t.harvest_level())

    def write_to(self, mut writer: Some[Writer]):
        """Writes the filter as `types/min_level`."""
        writer.write(self.types, "/", self.min_level)


comptime ALWAYS_HARVESTABLE = ToolFilter(types=0x7F, min_level=0)
"""Go `alwaysHarvestable`: any item."""
comptime NEVER_HARVESTABLE = ToolFilter(types=0, min_level=0)
"""Go `neverHarvestable`: no item."""
comptime NOTHING_EFFECTIVE = ToolFilter(types=0, min_level=0)
"""Go `nothingEffective`: no tool mines faster than a hand."""
comptime PICKAXE_EFFECTIVE = ToolFilter(TYPE_PICKAXE)
"""Go `pickaxeEffective`."""
comptime PICKAXE_HARVESTABLE = PICKAXE_EFFECTIVE
"""Go `pickaxeHarvestable`: any pickaxe."""
comptime AXE_EFFECTIVE = ToolFilter(TYPE_AXE)
"""Go `axeEffective`."""
comptime SHEARS_EFFECTIVE = ToolFilter(TYPE_SHEARS)
"""Go `shearsEffective`."""
comptime SWORD_EFFECTIVE = ToolFilter(TYPE_SWORD)
"""Go `swordEffective`."""
comptime SHOVEL_EFFECTIVE = ToolFilter(TYPE_SHOVEL)
"""Go `shovelEffective`."""
comptime HOE_EFFECTIVE = ToolFilter(TYPE_HOE)
"""Go `hoeEffective`."""


def pickaxe_harvestable_from(level: Int) -> ToolFilter:
    """Returns the filter of Go's `t.ToolType() == item.TypePickaxe &&
    t.HarvestLevel() >= level` closures."""
    return ToolFilter(TYPE_PICKAXE, min_level=level)


@fieldwise_init
struct XPDropRange(Equatable, ImplicitlyCopyable):
    """The minimum and maximum XP a block drops (Go `XPDropRange`)."""

    var min: Int
    """The minimum amount."""
    var max: Int
    """The maximum amount."""

    def __eq__(self, other: Self) -> Bool:
        """Compares two ranges."""
        return self.min == other.min and self.max == other.max


@fieldwise_init
struct BreakInfo(ImplicitlyCopyable):
    """Information related to breaking a block (Go `BreakInfo`)."""

    var hardness: Float64
    """The hardness, which decides how fast the block is mined."""
    var harvestable: ToolFilter
    """The tools that harvest the block (Go `Harvestable`)."""
    var effective: ToolFilter
    """The tools that mine the block faster than a hand (Go `Effective`)."""
    var xp_drops: XPDropRange
    """The range of XP the block drops."""
    var blast_resistance: Float64
    """How well the block withstands explosions."""

    def with_xp_drop_range(self, min: Int, max: Int) -> Self:
        """Returns the info with an XP drop range (Go `withXPDropRange`)."""
        var b = self
        b.xp_drops = XPDropRange(min, max)
        return b

    def with_blast_resistance(self, res: Float64) -> Self:
        """Returns the info with a blast resistance (Go
        `withBlastResistance`)."""
        var b = self
        b.blast_resistance = res
        return b


def new_break_info(
    hardness: Float64, harvestable: ToolFilter, effective: ToolFilter
) -> BreakInfo:
    """Creates a `BreakInfo` whose blast resistance equals its hardness and
    that drops no XP (Go `newBreakInfo`; the drops argument waits for items)."""
    return BreakInfo(
        hardness=hardness,
        harvestable=harvestable,
        effective=effective,
        xp_drops=XPDropRange(0, 0),
        blast_resistance=hardness,
    )


trait Breakable:
    """A block that may be broken by a player in survival mode (Go
    `Breakable`)."""

    def break_info(self) -> BreakInfo:
        """Returns information related to breaking the block (Go
        `BreakInfo`)."""
        ...


trait Dropper:
    """A block whose drops are not just itself (Go's `BreakInfo.Drops`
    function; blocks without it drop themselves, Go's `oneOf(b)`)."""

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Returns what breaking the block with a tool drops."""
        ...


@fieldwise_init
struct BreakContext(Defaultable, ImplicitlyCopyable):
    """The status effects and surroundings that change how fast a player
    breaks blocks (Go `BreakContext`)."""

    var haste_level: Int
    """The Haste level, 0 without the effect."""
    var conduit_power_level: Int
    """The Conduit Power level; does not stack with Haste."""
    var mining_fatigue_level: Int
    """The Mining Fatigue level."""
    var underwater: Bool
    """The player's head is in water (5x slower without Aqua Affinity)."""
    var aqua_affinity: Bool
    """The helmet has Aqua Affinity."""
    var flying: Bool
    """The player flies, which cancels the airborne penalty."""
    var airborne: Bool
    """The player is not on the ground (5x slower)."""

    def __init__(out self):
        """Creates the context of a player on the ground without effects."""
        self = Self(0, 0, 0, False, False, False, False)


comptime NEVER_BREAKS_MS = Int.MAX
"""The duration of a block that is not `Breakable` (Go `math.MaxInt64`)."""


def break_duration_ms(
    info: Optional[BreakInfo],
    tool: ToolInfo,
    efficiency_level: Int,
    ctx: BreakContext,
) -> Int:
    """Returns how long breaking a block takes with a tool, in milliseconds
    (Go `BreakDuration`); `info` is None for blocks that are not `Breakable`
    and `efficiency_level` is the held item's Efficiency level or 0. See
    https://minecraft.wiki/w/Breaking#Calculation."""
    if not info:
        return NEVER_BREAKS_MS
    var b = info.value()
    if b.hardness <= 0:
        return 0
    var can_harvest = b.harvestable.matches(tool.tool_type, tool.harvest_level)
    var speed = 1.0
    if b.effective.matches(tool.tool_type, tool.harvest_level):
        speed = tool.efficiency
        if not can_harvest:
            # A tool of the right type but too low a tier gives no bonus.
            speed = 1
        elif efficiency_level > 0:
            speed += Efficiency.addend(efficiency_level)
    var positive = max(ctx.haste_level, ctx.conduit_power_level)
    if positive > 0:
        speed *= 0.2 * Float64(positive) + 1
    if ctx.mining_fatigue_level > 0:
        speed *= pow(0.3, Float64(ctx.mining_fatigue_level))
    if ctx.underwater and not ctx.aqua_affinity:
        speed /= 5
    if ctx.airborne and not ctx.flying:
        speed /= 5
    var damage = speed / b.hardness
    if can_harvest:
        damage /= 30
    else:
        damage /= 100
    if positive > 0:
        damage *= pow(1.2, Float64(positive))
    if ctx.mining_fatigue_level > 0:
        damage *= pow(0.7, Float64(ctx.mining_fatigue_level))
    if damage >= 1:
        return 0
    return Int(ceil(1 / damage)) * 50


def breaks_instantly(info: Optional[BreakInfo]) -> Bool:
    """Reports whether a block has no hardness (Go `BreaksInstantly`)."""
    return Bool(info) and info.value().hardness <= 0
