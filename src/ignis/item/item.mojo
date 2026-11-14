"""Item behaviours, ported from Dragonfly `server/item/item.go`.

Go's optional item interfaces become traits. Only the ones a `Stack` needs
are ported so far (`MaxCounter`, and `Durable` and `Repairable` in `durability.mojo`); the
use, consume and weapon interfaces need `world.Tx` users (players) and come
with them.
"""

from ..world.item import Item, ItemInfo
from .durability import Durable, DurabilityInfo, Repairable


trait MaxCounter:
    """An item with a maximum count other than 64 (Go `MaxCounter`)."""

    def max_count(self) -> Int:
        """Returns the maximum count of a stack of the item.

        Returns:
            A positive count.
        """
        ...


def item_info[T: Item](it: T) -> ItemInfo:
    """Returns what a stack needs to know about an item (Go asks
    `MaxCounter` and `Durable` on every call).

    Parameters:
        T: The item type.

    Args:
        it: The item.

    Returns:
        The item's maximum count and durability.
    """
    var info = ItemInfo()
    info.air = it.encode_item().name == "minecraft:air"
    comptime if conforms_to(T, MaxCounter):
        info.max_count = _max_count(it)
    comptime if conforms_to(T, Durable):
        var d = _durability_info(it)
        info.max_durability = d.max_durability
        info.persistent = d.persistent
    comptime if conforms_to(T, Repairable):
        info.repairable = True
    return info


def _max_count[T: MaxCounter](it: T) -> Int:
    return it.max_count()


def _durability_info[T: Durable](it: T) -> DurabilityInfo:
    return it.durability_info()
