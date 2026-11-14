"""Container windows a session opens, from Dragonfly `server/session`: the
type switches of `OpenBlockContainer` and `openNormalContainer`
(`world.go`) and the cases of `invByID` (`player.go`) that need an opened
block. Go switches on block types; Ignis compares the block's `kind`.
"""

from minecraft.protocol.container import (
    CONTAINER_TYPE_ANVIL,
    CONTAINER_TYPE_BEACON,
    CONTAINER_TYPE_BLAST_FURNACE,
    CONTAINER_TYPE_BREWING_STAND,
    CONTAINER_TYPE_CONTAINER,
    CONTAINER_TYPE_ENCHANTMENT,
    CONTAINER_TYPE_FURNACE,
    CONTAINER_TYPE_GRINDSTONE,
    CONTAINER_TYPE_HOPPER,
    CONTAINER_TYPE_LECTERN,
    CONTAINER_TYPE_LOOM,
    CONTAINER_TYPE_SMITHING_TABLE,
    CONTAINER_TYPE_SMOKER,
    CONTAINER_TYPE_STONECUTTER,
    CONTAINER_TYPE_WORKBENCH,
)

from ..block.hash import (
    HASH_ANVIL,
    HASH_BARREL,
    HASH_BEACON,
    HASH_BLAST_FURNACE,
    HASH_BREWING_STAND,
    HASH_CRAFTING_TABLE,
    HASH_ENCHANTING_TABLE,
    HASH_ENDER_CHEST,
    HASH_FURNACE,
    HASH_GRINDSTONE,
    HASH_HOPPER,
    HASH_LECTERN,
    HASH_LOOM,
    HASH_SHULKER_BOX,
    HASH_SMITHING_TABLE,
    HASH_SMOKER,
    HASH_STONECUTTER,
)

comptime WINDOW_NONE = 0
"""No block window is open."""
comptime WINDOW_STORED = 1
"""The window shows the inventory the block keeps (Go `block.Container`)."""
comptime WINDOW_ENDER_CHEST = 2
"""The window shows the player's ender chest inventory."""
comptime WINDOW_UI = 3
"""The window works on the UI inventory (crafting table, anvil, ...)."""


@fieldwise_init
struct Window(Copyable, ImplicitlyCopyable):
    """What the open window shows, for `invByID`."""

    var kind: Int
    """A `WINDOW_*` value."""
    var block: UInt64
    """The `kind` of the opened block."""

    @staticmethod
    def none() -> Self:
        """Returns the window of a session with no block window open."""
        return Self(WINDOW_NONE, 0)


def window_container_type(block: UInt64) -> UInt8:
    """Returns the container type a block's window opens with (Go's type
    switches); chests, barrels, shulker boxes and ender chests use
    `CONTAINER_TYPE_CONTAINER`."""
    if block == HASH_FURNACE:
        return CONTAINER_TYPE_FURNACE
    if block == HASH_BLAST_FURNACE:
        return CONTAINER_TYPE_BLAST_FURNACE
    if block == HASH_SMOKER:
        return CONTAINER_TYPE_SMOKER
    if block == HASH_BREWING_STAND:
        return CONTAINER_TYPE_BREWING_STAND
    if block == HASH_HOPPER:
        return CONTAINER_TYPE_HOPPER
    if block == HASH_CRAFTING_TABLE:
        return CONTAINER_TYPE_WORKBENCH
    if block == HASH_ENCHANTING_TABLE:
        return CONTAINER_TYPE_ENCHANTMENT
    if block == HASH_ANVIL:
        return CONTAINER_TYPE_ANVIL
    if block == HASH_BEACON:
        return CONTAINER_TYPE_BEACON
    if block == HASH_LECTERN:
        return CONTAINER_TYPE_LECTERN
    if block == HASH_LOOM:
        return CONTAINER_TYPE_LOOM
    if block == HASH_GRINDSTONE:
        return CONTAINER_TYPE_GRINDSTONE
    if block == HASH_STONECUTTER:
        return CONTAINER_TYPE_STONECUTTER
    if block == HASH_SMITHING_TABLE:
        return CONTAINER_TYPE_SMITHING_TABLE
    return CONTAINER_TYPE_CONTAINER


def window_kind(block: UInt64, stored: Bool) -> Int:
    """Returns what the window of a block shows."""
    if stored:
        return WINDOW_STORED
    if block == HASH_ENDER_CHEST:
        return WINDOW_ENDER_CHEST
    return WINDOW_UI
