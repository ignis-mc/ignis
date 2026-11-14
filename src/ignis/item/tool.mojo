"""Tools, ported from Dragonfly `server/item/tool.go`.

Go's `Tool.BaseMiningEfficiency(b world.Block)` receives the block mined;
here it receives the block's type (`BASE_HASH`), which is all swords and
shears look at. The tool items (pickaxes, axes, ...) follow with the bulk
item port.
"""


@fieldwise_init
struct ToolType(Equatable, ImplicitlyCopyable, Writable):
    """The type of a tool, which decides the blocks it is used for (Go
    `ToolType`)."""

    var t: Int
    """Go's unexported value: -1 for none, then pickaxe 0 to sword 5."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes the tool type's name.

        Args:
            writer: The destination.
        """
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


trait Tool:
    """An item that may be used as a tool (Go `Tool`)."""

    def tool_type(self) -> ToolType:
        """Returns the type of the tool.

        Returns:
            The tool type.
        """
        ...

    def harvest_level(self) -> Int:
        """Returns the highest harvest level of blocks the tool harvests.

        Returns:
            The level.
        """
        ...

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns the base speed at which the tool mines a block.

        Args:
            block_kind: The `BASE_HASH` of the block's type.

        Returns:
            The efficiency.
        """
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
        """Returns `TYPE_NONE`.

        Returns:
            The tool type.
        """
        return TYPE_NONE

    def harvest_level(self) -> Int:
        """Returns 0.

        Returns:
            The level.
        """
        return 0

    def base_mining_efficiency(self, block_kind: UInt64) -> Float64:
        """Returns 1.

        Args:
            block_kind: The block's type.

        Returns:
            The efficiency.
        """
        return 1
