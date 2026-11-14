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

from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..item.item import item_info
from .block import Block, NeighbourUpdateTicker, RandomTicker, ScheduledTicker
from .block_model import ModelledBlock, UnknownModel
from .block_registry import BasicBlockRegistry
from .block_source import BlockSource
from .block_state import BlockState
from .item import AnyItem, EncodedItem, Item, RegisteredItem
from .world import World, WorldTypes


trait BlockTypes:
    """The block types a world knows, with dispatch of their behaviours.
    `BlockSet` is the implementation; a world names its set in
    `WorldTypes.Blocks`."""

    @staticmethod
    def register_all(mut br: BasicBlockRegistry) raises:
        """Registers every state of every type."""
        ...

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set."""
        ...

    @staticmethod
    def scheduled_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `ScheduledTicker.scheduled_tick` of the block, if its type
        has it."""
        ...

    @staticmethod
    def neighbour_update_tick[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        changed_neighbour: Pos,
        mut tx: World[T],
    ) -> Bool:
        """Calls `NeighbourUpdateTicker.neighbour_update_tick` of the
        block, if its type has it."""
        ...

    @staticmethod
    def random_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `RandomTicker.random_tick` of the block, if its type has
        it."""
        ...

    @staticmethod
    def face_solid[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face of a block's model is solid (Go
        `b.Model().FaceSolid(pos, face, src)`)."""
        ...

    @staticmethod
    def block_item(kind: UInt64, hash: UInt64) -> Optional[RegisteredItem]:
        """Returns a block as an item, if its type is an item."""
        ...

    @staticmethod
    def encode_block_item(kind: UInt64, hash: UInt64) -> Optional[EncodedItem]:
        """Encodes a block as an item."""
        ...


struct BlockSet[*Ts: Block](BlockTypes):
    """Static dispatch over the block types `Ts`."""

    @staticmethod
    def register_all(mut br: BasicBlockRegistry) raises:
        """Registers every state of every type (Go `block/register.go`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            for b in T.all_states():
                br.register_block(b)

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set."""
        comptime for i in range(len(Self.Ts)):
            if kind == Self.Ts[i].BASE_HASH:
                return True
        return False

    @staticmethod
    def face_solid[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face of a block's model is solid (Go
        `b.Model().FaceSolid(pos, face, src)`)."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, ModelledBlock):
                if kind == B.BASE_HASH:
                    return _face_solid(B.from_hash(hash), pos, face, src)
        return UnknownModel().face_solid(pos, face, src)

    @staticmethod
    def block_item(kind: UInt64, hash: UInt64) -> Optional[RegisteredItem]:
        """Returns a block as an item, if its type is an item (Go
        `b.(world.Item)`), whether or not the value is registered as one."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Item):
                if kind == T.BASE_HASH:
                    return _block_item(T.from_hash(hash))
        return None

    @staticmethod
    def encode_block_item(kind: UInt64, hash: UInt64) -> Optional[EncodedItem]:
        """Encodes a block as an item (Go `b.(world.Item).EncodeItem()`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            comptime if conforms_to(T, Item):
                if kind == T.BASE_HASH:
                    return _encode_item(T.from_hash(hash))
        return None

    @staticmethod
    def scheduled_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `ScheduledTicker.scheduled_tick` of the block, if its type
        has it."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, ScheduledTicker):
                if kind == B.BASE_HASH:
                    _scheduled_tick(B.from_hash(hash), pos, tx)
                    return True
        return False

    @staticmethod
    def neighbour_update_tick[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        changed_neighbour: Pos,
        mut tx: World[T],
    ) -> Bool:
        """Calls `NeighbourUpdateTicker.neighbour_update_tick` of the
        block, if its type has it."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, NeighbourUpdateTicker):
                if kind == B.BASE_HASH:
                    _neighbour_update_tick(
                        B.from_hash(hash), pos, changed_neighbour, tx
                    )
                    return True
        return False

    @staticmethod
    def random_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `RandomTicker.random_tick` of the block, if its type has
        it."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, RandomTicker):
                if kind == B.BASE_HASH:
                    _random_tick(B.from_hash(hash), pos, tx)
                    return True
        return False

    @staticmethod
    def encode(kind: UInt64, hash: UInt64) -> Optional[BlockState]:
        """Encodes a block of any type in the set (Go `b.EncodeBlock()` on a
        `world.Block`)."""
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if kind == T.BASE_HASH:
                return T.from_hash(hash).encode_block()
        return None


def _scheduled_tick[
    B: ScheduledTicker, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T]):
    b.scheduled_tick(pos, tx)


def _neighbour_update_tick[
    B: NeighbourUpdateTicker, T: WorldTypes
](b: B, pos: Pos, changed: Pos, mut tx: World[T]):
    b.neighbour_update_tick(pos, changed, tx)


def _random_tick[
    B: RandomTicker, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T]):
    b.random_tick(pos, tx)


def _face_solid[
    B: ModelledBlock, S: BlockSource
](b: B, pos: Pos, face: Face, src: S) -> Bool:
    return b.model().face_solid(pos, face, src)


def _block_item[T: Item](b: T) -> RegisteredItem:
    return RegisteredItem(AnyItem.of(b), item_info(b))


def _encode_item[T: Item](b: T) -> EncodedItem:
    return b.encode_item()
