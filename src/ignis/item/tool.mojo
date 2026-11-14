"""Tools, ported from Dragonfly `server/item/tool.go`.

Go's `Tool.BaseMiningEfficiency(b world.Block)` receives the block mined;
here it receives the block's type (`BASE_HASH`), which is all swords and
shears look at. Go's `toolTierRepairable` asks the item for
`RepairsWoodTools`/`RepairsStoneTools`; here those are planks, bamboo
mosaic and non-mossy cobblestone, the blocks that implement them.
"""

from ..block.cobblestone import Cobblestone
from ..block.hash import HASH_BAMBOO_MOSAIC, HASH_COBBLESTONE, HASH_PLANKS
from ..world.item import item_hash
from .smelting_info import SmeltInfo
from .stack import Stack


@fieldwise_init
struct ToolType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a tool, which decides the blocks it is used for (Go
    `ToolType`)."""

    var t: Int
    """Go's unexported value: -1 for none, then pickaxe 0 to sword 5."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes the tool type's name."""
        if self.t == 0:
            writer.write("pickaxe")
        elif self.t == 1:
            writer.write("axe")
        elif self.t == 2:
            writer.write("hoe")
        elif self.t == 3:
            writer.write("shovel")
        elif self.t == 4:
            writer.write("shears")
        elif self.t == 5:
            writer.write("sword")
        else:
            writer.write("none")


comptime TYPE_NONE = ToolType(-1)
"""The tool type of items that are not tools (Go `TypeNone`)."""
comptime TYPE_PICKAXE = ToolType(0)
"""Pickaxes (Go `TypePickaxe`)."""
comptime TYPE_AXE = ToolType(1)
"""Axes (Go `TypeAxe`)."""
comptime TYPE_HOE = ToolType(2)
"""Hoes (Go `TypeHoe`)."""
comptime TYPE_SHOVEL = ToolType(3)
"""Shovels (Go `TypeShovel`)."""
comptime TYPE_SHEARS = ToolType(4)
"""Shears (Go `TypeShears`)."""
comptime TYPE_SWORD = ToolType(5)
"""Swords (Go `TypeSword`)."""


@fieldwise_init
struct ToolTier(Equatable, ImplicitlyCopyable, Writable):
    """The material a tool is made of (Go `ToolTier`)."""

    var harvest_level: Int
    """The highest harvest level of blocks the tier can harvest."""
    var base_mining_efficiency: Float64
    """The base mining speed of the tier."""
    var base_attack_damage: Float64
    """The base attack damage of tools of the tier."""
    var enchantment_value: Int
    """The tier's enchantability."""
    var durability: Int
    """The maximum durability of tools of the tier."""
    var name: StaticString
    """The tier's name, as in item names (`wooden`, `golden`, ...)."""


comptime TOOL_TIER_WOOD = ToolTier(1, 2, 1, 15, 59, "wooden")
"""The lowest tier (Go `ToolTierWood`)."""
comptime TOOL_TIER_GOLD = ToolTier(1, 12, 1, 22, 32, "golden")
"""Go `ToolTierGold`."""
comptime TOOL_TIER_STONE = ToolTier(2, 4, 2, 5, 131, "stone")
"""Go `ToolTierStone`."""
comptime TOOL_TIER_COPPER = ToolTier(2, 5, 2, 13, 190, "copper")
"""Go `ToolTierCopper`."""
comptime TOOL_TIER_IRON = ToolTier(3, 6, 3, 14, 250, "iron")
"""Go `ToolTierIron`."""
comptime TOOL_TIER_DIAMOND = ToolTier(4, 8, 4, 10, 1561, "diamond")
"""Go `ToolTierDiamond`."""
comptime TOOL_TIER_NETHERITE = ToolTier(4, 9, 5, 15, 2031, "netherite")
"""The highest tier (Go `ToolTierNetherite`)."""


def tool_tiers() -> List[ToolTier]:
    """Returns every tool tier (Go `ToolTiers`)."""
    return [
        TOOL_TIER_WOOD,
        TOOL_TIER_GOLD,
        TOOL_TIER_STONE,
        TOOL_TIER_COPPER,
        TOOL_TIER_IRON,
        TOOL_TIER_DIAMOND,
        TOOL_TIER_NETHERITE,
    ]


def tool_tier_index(tier: ToolTier) -> Int:
    """Returns the index of a tier in `tool_tiers()`, or -1 for a custom tier.
    """
    var tiers = tool_tiers()
    for i in range(len(tiers)):
        if tiers[i] == tier:
            return i
    return -1


def tool_tier_repairable(tier: ToolTier, stack: Stack) -> Bool:
    """Reports whether a stack repairs tools of a tier (Go
    `toolTierRepairable`)."""
    var it = stack.item()
    if not it:
        return False
    var kind = it.value().kind
    if tier == TOOL_TIER_WOOD:
        return kind == HASH_PLANKS or kind == HASH_BAMBOO_MOSAIC
    if tier == TOOL_TIER_STONE:
        if kind != HASH_COBBLESTONE:
            return False
        return not Cobblestone.from_hash(it.value().hash).mossy
    if tier == TOOL_TIER_GOLD:
        return kind == item_hash("GoldIngot")
    if tier == TOOL_TIER_COPPER:
        return kind == item_hash("CopperIngot")
    if tier == TOOL_TIER_IRON:
        return kind == item_hash("IronIngot")
    if tier == TOOL_TIER_DIAMOND:
        return kind == item_hash("Diamond")
    if tier == TOOL_TIER_NETHERITE:
        return kind == item_hash("NetheriteIngot")
    return False


def tool_tier_smelt_info(tier: ToolTier) -> SmeltInfo:
    """Returns what smelting a tool of a tier gives (the `SmeltInfo` switch
    every Go tool repeats): a nugget for iron, gold and copper."""
    from .copper_nugget import CopperNugget
    from .gold_nugget import GoldNugget
    from .iron_nugget import IronNugget

    if tier == TOOL_TIER_IRON:
        return SmeltInfo(Stack(IronNugget(), 1), 0.1, ores=True)
    if tier == TOOL_TIER_GOLD:
        return SmeltInfo(Stack(GoldNugget(), 1), 0.1, ores=True)
    if tier == TOOL_TIER_COPPER:
        return SmeltInfo(Stack(CopperNugget(), 1), 0.1, ores=True)
    return SmeltInfo()


trait Tool:
    """An item that may be used as a tool (Go `Tool`)."""

    def tool_type(self) -> ToolType:
        """Returns the type of the tool."""
        ...

    def harvest_level(self) -> Int:
        """Returns the highest harvest level of blocks the tool harvests."""
        ...

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns the base speed at which the tool mines a block."""
        ...


@fieldwise_init
struct ToolInfo(Equatable, ImplicitlyCopyable, Writable):
    """What breaking a block needs to know about the held item: Go asks the
    `item.Tool` it holds; Ignis dispatches once (`ItemSet.tool`)."""

    var tool_type: ToolType
    """Go `ToolType`."""
    var harvest_level: Int
    """Go `HarvestLevel`."""
    var efficiency: Float64
    """Go `BaseMiningEfficiency` for the block being broken."""

    @staticmethod
    def none() -> ToolInfo:
        """Returns Go's `ToolNone`."""
        return ToolInfo(TYPE_NONE, 0, 1)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the fields, for debugging."""
        writer.write(
            "ToolInfo(",
            self.tool_type,
            ", ",
            self.harvest_level,
            ", ",
            self.efficiency,
            ")",
        )


def tool_info[T: Tool](t: T, block_kind: UInt64) -> ToolInfo:
    """Returns a tool's info for breaking a block of a type."""
    return ToolInfo(
        t.tool_type(), t.harvest_level(), t.base_mining_efficiency(block_kind)
    )


struct ToolNone(Defaultable, ImplicitlyCopyable, Tool):
    """The tool used when nothing that is a tool is held (Go `ToolNone`)."""

    def __init__(out self):
        """Creates the value."""
        pass

    def tool_type(self) -> ToolType:
        """Returns `TYPE_NONE`."""
        return TYPE_NONE

    def harvest_level(self) -> Int:
        """Returns 0."""
        return 0

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns 1."""
        return 1
