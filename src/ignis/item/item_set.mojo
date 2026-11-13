"""A compile-time list of item types, as `world.BlockSet` is for blocks. No
Dragonfly counterpart: it replaces calling methods on a `world.Item`
interface value.

An item of unknown type is an `AnyItem`, whose `kind` is the `BASE_HASH` of
its type. Behaviours only some items have (Go: `Usable`, `Consumable`, ...)
become traits, and their dispatchers loop over `Ts` with
`comptime if conforms_to(T, Trait)` exactly like `BlockSet` does.
"""

from ..world.item import AnyItem, Item, ItemRegistry
from .item import item_info


struct ItemSet[*Ts: Item]:
    """Static dispatch over the item types `Ts`.

    Parameters:
        Ts: The item types, each with a distinct `BASE_HASH`.
    """

    @staticmethod
    def register_all(mut reg: ItemRegistry) raises:
        """Registers every item value of every type (Go `RegisterItem` calls
        in `register.go`).

        Args:
            reg: The registry.

        Raises:
            If an item is registered twice or its name has no runtime ID.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            for it in T.all_items():
                reg.register_item(it, item_info(it))

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set.

        Args:
            kind: A base hash, as `AnyItem.kind`.

        Returns:
            True if one of `Ts` has that `BASE_HASH`.
        """
        comptime for i in range(len(Self.Ts)):
            if kind == Self.Ts[i].BASE_HASH:
                return True
        return False
