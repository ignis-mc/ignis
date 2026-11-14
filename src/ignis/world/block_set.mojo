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

from ..block.block import Replaceable
from ..block.break_info import BreakInfo, Breakable, Dropper
from ..item.stack import Stack
from ..item.tool import ToolInfo
from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.hash import AnyBlock
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
        """Registers every state of every type.

        Args:
            br: An unfinalized registry holding the vanilla states.

        Raises:
            If a state is not in the registry or is registered twice.
        """
        ...

    @staticmethod
    def contains(kind: UInt64) -> Bool:
        """Reports whether a type with the base hash passed is in the set.

        Args:
            kind: A base hash.

        Returns:
            True if a type has that base hash.
        """
        ...

    @staticmethod
    def scheduled_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `ScheduledTicker.scheduled_tick` of the block, if its type
        has it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            tx: The world.

        Returns:
            True if the type is a `ScheduledTicker`.
        """
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
        block, if its type has it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            changed_neighbour: The position of the block that changed.
            tx: The world.

        Returns:
            True if the type is a `NeighbourUpdateTicker`.
        """
        ...

    @staticmethod
    def random_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `RandomTicker.random_tick` of the block, if its type has
        it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            tx: The world.

        Returns:
            True if the type is a `RandomTicker`.
        """
        ...

    @staticmethod
    def face_solid[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face of a block's model is solid (Go
        `b.Model().FaceSolid(pos, face, src)`).

        Parameters:
            S: The block source type.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            face: The face.
            src: The blocks around it.

        Returns:
            True if the face is solid; always for types without a model.
        """
        ...

    @staticmethod
    def model_bbox[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of a block's model, relative to `pos` (Go
        `b.Model().BBox(pos, src)`); a full cube for types without a model.
        """
        ...

    @staticmethod
    def break_info(kind: UInt64, hash: UInt64) -> Optional[BreakInfo]:
        """Returns a block's break info, or None if it is not `Breakable`."""
        ...

    @staticmethod
    def replaceable_by(kind: UInt64, hash: UInt64, by: AnyBlock) -> Bool:
        """Reports whether `by` may replace a block (Go
        `b.(Replaceable).ReplaceableBy(by)`); False if it is not
        `Replaceable`."""
        ...

    @staticmethod
    def drops(
        kind: UInt64, hash: UInt64, tool: ToolInfo, silk_touch: Bool
    ) -> Optional[List[Stack]]:
        """Returns a `Dropper` block's drops, or None for other blocks,
        which drop themselves (Go `BreakInfo.Drops`)."""
        ...

    @staticmethod
    def block_item(kind: UInt64, hash: UInt64) -> Optional[RegisteredItem]:
        """Returns a block as an item, if its type is an item.

        Args:
            kind: The block type's base hash.
            hash: The block's state hash.

        Returns:
            The item and its stack info, or None.
        """
        ...

    @staticmethod
    def encode_block_item(kind: UInt64, hash: UInt64) -> Optional[EncodedItem]:
        """Encodes a block as an item.

        Args:
            kind: The block type's base hash.
            hash: The block's state hash.

        Returns:
            The item name and metadata, or None if the type is not an item.
        """
        ...


struct BlockSet[*Ts: Block](BlockTypes):
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
    def face_solid[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face of a block's model is solid (Go
        `b.Model().FaceSolid(pos, face, src)`).

        Parameters:
            S: The block source type.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            face: The face.
            src: The blocks around it.

        Returns:
            True if the face is solid; always for types without a model.
        """
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, ModelledBlock):
                if kind == B.BASE_HASH:
                    return _face_solid(B.from_hash(hash), pos, face, src)
        return UnknownModel().face_solid(pos, face, src)

    @staticmethod
    def model_bbox[
        S: BlockSource
    ](kind: UInt64, hash: UInt64, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of a block's model, relative to `pos`."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, ModelledBlock):
                if kind == B.BASE_HASH:
                    return _model_bbox(B.from_hash(hash), pos, src)
        return UnknownModel().bbox(pos, src)

    @staticmethod
    def break_info(kind: UInt64, hash: UInt64) -> Optional[BreakInfo]:
        """Returns a block's break info, or None if it is not `Breakable`."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Breakable):
                if kind == B.BASE_HASH:
                    return _break_info(B.from_hash(hash))
        return None

    @staticmethod
    def replaceable_by(kind: UInt64, hash: UInt64, by: AnyBlock) -> Bool:
        """Reports whether `by` may replace a block."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Replaceable):
                if kind == B.BASE_HASH:
                    return _replaceable_by(B.from_hash(hash), by)
        return False

    @staticmethod
    def drops(
        kind: UInt64, hash: UInt64, tool: ToolInfo, silk_touch: Bool
    ) -> Optional[List[Stack]]:
        """Returns a `Dropper` block's drops, or None for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Dropper):
                if kind == B.BASE_HASH:
                    return _drops(B.from_hash(hash), tool, silk_touch)
        return None

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

    @staticmethod
    def scheduled_tick[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `ScheduledTicker.scheduled_tick` of the block, if its type
        has it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            tx: The world.

        Returns:
            True if the type is a `ScheduledTicker`.
        """
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
        block, if its type has it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            changed_neighbour: The position of the block that changed.
            tx: The world.

        Returns:
            True if the type is a `NeighbourUpdateTicker`.
        """
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
        it.

        Parameters:
            T: The world's types.

        Args:
            kind: The block's type base hash.
            hash: The block's state hash.
            pos: The position of the block.
            tx: The world.

        Returns:
            True if the type is a `RandomTicker`.
        """
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


def _model_bbox[
    B: ModelledBlock, S: BlockSource
](b: B, pos: Pos, src: S) -> List[BBox]:
    return b.model().bbox(pos, src)


def _break_info[B: Breakable](b: B) -> BreakInfo:
    return b.break_info()


def _replaceable_by[B: Replaceable](b: B, by: AnyBlock) -> Bool:
    return b.replaceable_by(by)


def _drops[B: Dropper](b: B, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
    return b.drops(tool, silk_touch)


def _block_item[T: Item](b: T) -> RegisteredItem:
    return RegisteredItem(AnyItem.of(b), item_info(b))


def _encode_item[T: Item](b: T) -> EncodedItem:
    return b.encode_item()
