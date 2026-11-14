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

from ..block.block import Placement, Replaceable, UsableOnBlock
from ..block.cube.rotation import Rotation
from ..mgl64 import Vec3
from ..block.break_info import BreakInfo, Breakable, Dropper
from ..item.stack import Stack
from ..item.tool import ToolInfo
from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.hash import AnyBlock
from ..block.cube.pos import Pos
from ..item.item import item_info
from ..block.block import FlammabilityInfo, Flammable, Solidifiable
from ..block.crop import Crop
from ..block.dirt import Soil
from ..block.liquid import LiquidRemovable
from ..block.oxidation_type import OxidationType
from ..block.oxidizable import Oxidisable
from .block import (
    Block,
    LightDiffuser,
    Liquid,
    LiquidDisplacer,
    LiquidInfo,
    NeighbourUpdateTicker,
    RandomTicker,
    ScheduledTicker,
    liquid_info,
)
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
    def use_on_block[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> Optional[List[Placement]]:
        """Returns what a `UsableOnBlock` block item places (possibly
        nothing), or None for other blocks, which the placer puts on the
        clicked face (Go: `UseOnBlock` before the `world.Block` case)."""
        ...

    @staticmethod
    def liquid_info(kind: UInt64, hash: UInt64) -> Optional[LiquidInfo]:
        """Returns the `Liquid` methods of a block, if it is a liquid."""
        ...

    @staticmethod
    def harden_liquid[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        mut tx: World[T],
        flown_into_by: Optional[Pos],
    ) -> Bool:
        """Calls `Liquid.harden` of a liquid; False for other blocks."""
        ...

    @staticmethod
    def can_displace(kind: UInt64, hash: UInt64, liquid: AnyBlock) -> Bool:
        """Calls `LiquidDisplacer.can_displace`; False for other blocks."""
        ...

    @staticmethod
    def side_closed[
        T: WorldTypes
    ](
        kind: UInt64, hash: UInt64, pos: Pos, side: Pos, mut tx: World[T]
    ) -> Bool:
        """Calls `LiquidDisplacer.side_closed`; False for other blocks."""
        ...

    @staticmethod
    def is_liquid_displacer(kind: UInt64) -> Bool:
        """Reports whether the type with the base hash passed is a
        `LiquidDisplacer`."""
        ...

    @staticmethod
    def soil_for(kind: UInt64, hash: UInt64, vegetation: AnyBlock) -> Bool:
        """Calls `Soil.soil_for`; False for other blocks."""
        ...

    @staticmethod
    def is_crop(kind: UInt64, hash: UInt64) -> Bool:
        """Reports whether a block is a `Crop`."""
        ...

    @staticmethod
    def flammability(kind: UInt64, hash: UInt64) -> Optional[FlammabilityInfo]:
        """Returns `Flammable.flammability_info`, or None."""
        ...

    @staticmethod
    def oxidation(
        kind: UInt64, hash: UInt64
    ) -> Optional[Tuple[Bool, OxidationType]]:
        """Returns `Oxidisable.can_oxidate` and `oxidation_level`, or None."""
        ...

    @staticmethod
    def solidifies[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `Solidifiable.solidifies`; False for other blocks."""
        ...

    @staticmethod
    def is_light_diffuser(kind: UInt64, hash: UInt64) -> Bool:
        """Reports whether a block is a `LightDiffuser`."""
        ...

    @staticmethod
    def liquid_removable(kind: UInt64, hash: UInt64) -> Optional[Bool]:
        """Returns `LiquidRemovable.has_liquid_drops` of a block, or None if
        a liquid cannot remove it."""
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
    def use_on_block[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> Optional[List[Placement]]:
        """Returns what a `UsableOnBlock` block item places, or None."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, UsableOnBlock):
                if kind == B.BASE_HASH:
                    return _use_on_block(
                        B.from_hash(hash), pos, face, click, user, tx
                    )
        return None

    @staticmethod
    def liquid_info(kind: UInt64, hash: UInt64) -> Optional[LiquidInfo]:
        """Returns the `Liquid` methods of a block, if it is a liquid."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Liquid):
                if kind == B.BASE_HASH:
                    return _liquid_info(B.from_hash(hash))
        return None

    @staticmethod
    def harden_liquid[
        T: WorldTypes
    ](
        kind: UInt64,
        hash: UInt64,
        pos: Pos,
        mut tx: World[T],
        flown_into_by: Optional[Pos],
    ) -> Bool:
        """Calls `Liquid.harden` of a liquid; False for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Liquid):
                if kind == B.BASE_HASH:
                    return _harden(B.from_hash(hash), pos, tx, flown_into_by)
        return False

    @staticmethod
    def can_displace(kind: UInt64, hash: UInt64, liquid: AnyBlock) -> Bool:
        """Calls `LiquidDisplacer.can_displace`; False for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, LiquidDisplacer):
                if kind == B.BASE_HASH:
                    return _can_displace(B.from_hash(hash), liquid)
        return False

    @staticmethod
    def side_closed[
        T: WorldTypes
    ](
        kind: UInt64, hash: UInt64, pos: Pos, side: Pos, mut tx: World[T]
    ) -> Bool:
        """Calls `LiquidDisplacer.side_closed`; False for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, LiquidDisplacer):
                if kind == B.BASE_HASH:
                    return _side_closed(B.from_hash(hash), pos, side, tx)
        return False

    @staticmethod
    def is_liquid_displacer(kind: UInt64) -> Bool:
        """Reports whether the type with the base hash passed is a
        `LiquidDisplacer`."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, LiquidDisplacer):
                if kind == B.BASE_HASH:
                    return True
        return False

    @staticmethod
    def soil_for(kind: UInt64, hash: UInt64, vegetation: AnyBlock) -> Bool:
        """Calls `Soil.soil_for`; False for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Soil):
                if kind == B.BASE_HASH:
                    return _soil_for(B.from_hash(hash), vegetation)
        return False

    @staticmethod
    def is_crop(kind: UInt64, hash: UInt64) -> Bool:
        """Reports whether a block is a `Crop`."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Crop):
                if kind == B.BASE_HASH:
                    return True
        return False

    @staticmethod
    def flammability(kind: UInt64, hash: UInt64) -> Optional[FlammabilityInfo]:
        """Returns `Flammable.flammability_info`, or None."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Flammable):
                if kind == B.BASE_HASH:
                    return _flammability(B.from_hash(hash))
        return None

    @staticmethod
    def oxidation(
        kind: UInt64, hash: UInt64
    ) -> Optional[Tuple[Bool, OxidationType]]:
        """Returns `Oxidisable.can_oxidate` and `oxidation_level`, or None."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Oxidisable):
                if kind == B.BASE_HASH:
                    return _oxidation(B.from_hash(hash))
        return None

    @staticmethod
    def solidifies[
        T: WorldTypes
    ](kind: UInt64, hash: UInt64, pos: Pos, mut tx: World[T]) -> Bool:
        """Calls `Solidifiable.solidifies`; False for other blocks."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, Solidifiable):
                if kind == B.BASE_HASH:
                    return _solidifies(B.from_hash(hash), pos, tx)
        return False

    @staticmethod
    def is_light_diffuser(kind: UInt64, hash: UInt64) -> Bool:
        """Reports whether a block is a `LightDiffuser`."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, LightDiffuser):
                if kind == B.BASE_HASH:
                    return True
        return False

    @staticmethod
    def liquid_removable(kind: UInt64, hash: UInt64) -> Optional[Bool]:
        """Returns `LiquidRemovable.has_liquid_drops` of a block, or None if
        a liquid cannot remove it."""
        comptime for i in range(len(Self.Ts)):
            comptime B = Self.Ts[i]
            comptime if conforms_to(B, LiquidRemovable):
                if kind == B.BASE_HASH:
                    return _has_liquid_drops(B.from_hash(hash))
        return None

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


def _use_on_block[
    B: UsableOnBlock, T: WorldTypes
](
    b: B, pos: Pos, face: Face, click: Vec3, user: Rotation, mut tx: World[T]
) -> List[Placement]:
    return b.use_on_block(pos, face, click, user, tx)


def _liquid_info[B: Liquid](b: B) -> LiquidInfo:
    return liquid_info(b)


def _harden[
    B: Liquid, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T], flown_into_by: Optional[Pos]) -> Bool:
    return b.harden(pos, tx, flown_into_by)


def _can_displace[B: LiquidDisplacer](b: B, liquid: AnyBlock) -> Bool:
    return b.can_displace(liquid)


def _side_closed[
    B: LiquidDisplacer, T: WorldTypes
](b: B, pos: Pos, side: Pos, mut tx: World[T]) -> Bool:
    return b.side_closed(pos, side, tx)


def _has_liquid_drops[B: LiquidRemovable](b: B) -> Bool:
    return b.has_liquid_drops()


def _soil_for[B: Soil](b: B, vegetation: AnyBlock) -> Bool:
    return b.soil_for(vegetation)


def _flammability[B: Flammable](b: B) -> FlammabilityInfo:
    return b.flammability_info()


def _oxidation[B: Oxidisable](b: B) -> Tuple[Bool, OxidationType]:
    return (b.can_oxidate(), b.oxidation_level())


def _solidifies[
    B: Solidifiable, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T]) -> Bool:
    return b.solidifies(pos, tx)


def _block_item[T: Item](b: T) -> RegisteredItem:
    return RegisteredItem(AnyItem.of(b), item_info(b))


def _encode_item[T: Item](b: T) -> EncodedItem:
    return b.encode_item()
