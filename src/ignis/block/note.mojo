"""`Note`, ported from Dragonfly `server/block/note.go`.

The note particle carries the note block's own instrument (bass), as in
Go's `playNote`; the sound uses the instrument of the block below.

TODO(world-runtime): Punch, RedstonePowerUpdate, RedstonePowerPostUpdate
(no redstone yet) and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Activatable, Instrumented, UseContext, is_air
from .cube.face import Face
from .cube.pos import Pos
from ..world.particle.block import Note as NoteParticle
from ..world.sound.block import Note as NoteSound
from ..world.tx import SetOpts
from ..world.world import World, WorldTypes

from minecraft.nbt.tree import Tag, Tree

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item, ItemHasher
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_NOTE
from .model.solid import Solid as SolidModel


struct Note(
    Activatable,
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ItemHasher,
    ModelledBlock,
    NBTer,
):
    """A musical block that emits sounds when powered or punched."""

    comptime BASE_HASH: UInt64 = HASH_NOTE
    """Go `hashNote`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var pitch: Int
    """The current pitch the note block is set to, 0 to 24."""
    var powered: Bool
    """Whether the note block was powered during its last redstone update."""

    def __init__(out self, *, pitch: Int = 0, powered: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.pitch = pitch
        self.powered = powered

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.pitch == other.pitch
            and self.powered == other.powered
        )

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:noteblock")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Note()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Note()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.8, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:noteblock", 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`)."""
        return FuelInfo(15000)

    def play_note[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Plays the note's sound and particle (Go `playNote`)."""
        tx.play_sound(
            pos.vec3(),
            NoteSound(instrument=self.instrument_at(pos, tx), pitch=self.pitch),
        )
        tx.add_particle(
            pos.vec3(),
            NoteParticle(instrument=self.instrument(), pitch=self.pitch),
        )

    def instrument_at[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T]) -> Instrument:
        """Returns the instrument the block below selects, or the piano (Go
        `instrument`)."""
        var below = tx.block(pos.side(Face.DOWN))
        var br = tx.block_registry()
        return T.Blocks.instrument(
            br[].kind(below), br[].state_hash(below)
        ).or_else(Instrument.PIANO)

    def can_play[T: WorldTypes](self, pos: Pos, mut tx: World[T]) -> Bool:
        """Reports whether the block above is air (Go `canPlay`)."""
        return is_air(tx, pos.side(Face.UP))

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Raises the pitch by one and plays the note (Go `Activate`)."""
        if not self.can_play(pos, tx):
            return False
        var n = self
        n.pitch = (n.pitch + 1) % 25
        n.play_note(pos, tx)
        var opts = SetOpts()
        opts.disable_block_updates = True
        tx.set_block(pos, n, opts)
        return True

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        _ = tag.put_byte(root, "note", UInt8(self.pitch))
        _ = tag.put_byte(root, "powered", UInt8(1) if self.powered else 0)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`)."""
        var n = self
        n.pitch = 0
        if case .Some(t) = tag.get(root, "note"):
            n.pitch = Int(tag.as_byte(t))
        n.powered = False
        if case .Some(t) = tag.get(root, "powered"):
            n.powered = tag.as_byte(t) != 0
        return n

    def item_hash(self) -> UInt64:
        """Returns the item hash: the pitch, which Go keeps in the block
        entity (Go registers the item with pitch 24)."""
        return UInt64(self.pitch) & 0xFF

    @staticmethod
    def from_item_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its `item_hash`."""
        return Note(pitch=Int(hash & 0xFF))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Note(pitch=24)]
