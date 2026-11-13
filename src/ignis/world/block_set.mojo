"""A compile-time list of block types and dispatch over it. No Dragonfly
counterpart: it replaces calling methods on a `world.Block` interface value.

A block of unknown type is a runtime ID; `BasicBlockRegistry.kind` gives the
`BASE_HASH` of its type. A `BlockSet` lists every block type the server
knows, and its static methods find the type with that base hash and call
it. A behaviour that only some types have (Go: a separate interface such as
`RandomTicker`) is a separate trait, and its dispatcher only considers the
types that conform:

```mojo
def random_tick(kind: UInt64, hash: UInt64, ...):
    comptime for i in range(len(Self.Ts)):
        comptime T = Self.Ts[i]
        comptime if conforms_to(T, RandomTicker):
            if kind == T.BASE_HASH:
                _random_tick[T](T.from_hash(hash), ...)
                return
```

where `_random_tick[T: RandomTicker]` is a plain generic function. Inside the
`conforms_to` branch the compiler accepts `T` as a `RandomTicker`, so adding
a type to the set is all a new block needs.
"""

from ..item.item import item_info
from .block import Block
from .block_registry import BasicBlockRegistry
from .item import AnyItem, EncodedItem, Item, RegisteredItem


struct BlockSet[*Ts: Block]:
    """Static dispatch over the block types `Ts`.

    Parameters:
        Ts: The block types, each with a distinct `BASE_HASH`.
    """

    @staticmethod
    def register_all(mut br: BasicBlockRegistry) raises:
        """Registers every state of every type (Go `block/register.go`).

        Args:
            br: An unfinalized registry holding the vanilla states.

        Raises:
            If a state is not in the registry or is registered twice.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            for b in T.all_states():
                br.register_block(b)

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set.

        Args:
            kind: A base hash, as `BasicBlockRegistry.kind` returns.

        Returns:
            True if one of `Ts` has that `BASE_HASH`.
        """
        comptime for i in range(len(Self.Ts)):
            if kind == Self.Ts[i].BASE_HASH:
                return True
        return False

    @staticmethod
    def block_item(kind: UInt64, hash: UInt64) -> Optional[RegisteredItem]:
        """Returns a block as an item, if its type is an item (Go
        `b.(world.Item)`), whether or not the value is registered as one.

        Args:
            kind: The block type's base hash.
            hash: The block's state hash.

        Returns:
            The item and its stack info, or None.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Item):
                if kind == T.BASE_HASH:
                    return _block_item(T.from_hash(hash))
        return None

    @staticmethod
    def encode_block_item(kind: UInt64, hash: UInt64) -> Optional[EncodedItem]:
        """Encodes a block as an item (Go `b.(world.Item).EncodeItem()`).

        Args:
            kind: The block type's base hash.
            hash: The block's state hash.

        Returns:
            The item name and metadata, or None if the type is not an item.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Item):
                if kind == T.BASE_HASH:
                    return _encode_item(T.from_hash(hash))
        return None


def _block_item[T: Item](b: T) -> RegisteredItem:
    return RegisteredItem(AnyItem.of(b), item_info(b))


def _encode_item[T: Item](b: T) -> EncodedItem:
    return b.encode_item()
