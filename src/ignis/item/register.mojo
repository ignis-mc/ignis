"""Registration of the vanilla items, ported from Dragonfly
`server/item/register.go` and the `world.RegisterItem` calls of
`server/block/register.go`.

Each type lists its values in `all_items`; `VanillaItems` lists the item
types and `VanillaBlockItems` the block types that are items.
`vanilla_item_registry` builds the registry a server uses.
"""

from ..block.air import Air
from ..block.bedrock import Bedrock
from ..block.dirt import Dirt
from ..block.grass import Grass
from ..block.stone import Stone
from ..world.item import ItemRegistry
from .beef import Beef
from .coal import Coal
from .diamond import Diamond
from .item_set import ItemSet
from .shears import Shears
from .stick import Stick

comptime VanillaItems = ItemSet[Beef, Coal, Diamond, Shears, Stick]
"""Every item type Ignis implements, in Go's `register.go` order."""

comptime VanillaBlockItems = ItemSet[Air, Bedrock, Dirt, Grass, Stone]
"""Every block type registered as an item, in Go's `block/register.go`
order."""

comptime VANILLA_ITEMS_PATH = "resources/vanilla_items.nbt"
"""Where `vanilla_items.nbt` lives, relative to the repository root."""


def vanilla_item_registry(
    path: String = VANILLA_ITEMS_PATH,
) raises -> ItemRegistry:
    """Builds the vanilla item registry: the runtime IDs of
    `vanilla_items.nbt` with every item and block item registered.

    Args:
        path: The path of `vanilla_items.nbt`.

    Returns:
        The registry.

    Raises:
        If the file cannot be read or an item has no runtime ID.
    """
    var reg = ItemRegistry.load(path)
    VanillaBlockItems.register_all(reg)
    VanillaItems.register_all(reg)
    return reg^
