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

from .block import Block
from .block_registry import BasicBlockRegistry
from .block_state import BlockState


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
    def encode(kind: UInt64, hash: UInt64) -> Optional[BlockState]:
        """Encodes a block of any type in the set (Go `b.EncodeBlock()` on a
        `world.Block`).

        Args:
            kind: The `BASE_HASH` of the block's type.
            hash: The block's state hash.

        Returns:
            The state, or None if no type in the set has that base hash.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if kind == T.BASE_HASH:
                return T.from_hash(hash).encode_block()
        return None
