"""`Jukebox`, ported from Dragonfly `server/block/jukebox.go`.

`RecordItem` is written and read without the item registry (block NBT
callbacks get none): a disc's name follows from its `DiscType`.

TODO(world-runtime): the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..item.music_disc import MusicDisc
from ..item.nbt import read_nbt, write_nbt
from ..item.stack import Stack
from ..world.sound.block import MusicDiscEnd, MusicDiscPlay
from ..world.sound.disc_type import DiscType, music_discs
from ..world.world import World, WorldTypes
from ..item.inventory.inventory import Inventory
from .block import (
    Activatable,
    BreakHandler,
    HopperExtractable,
    HopperInsertable,
    UseContext,
)
from .cube.face import Face
from .cube.pos import Pos

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_JUKEBOX
from .model.solid import Solid as SolidModel


struct Jukebox(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Equatable,
    Fuel,
    HopperExtractable,
    HopperInsertable,
    Instrumented,
    Item,
    ModelledBlock,
    NBTer,
):
    """A block used to play music discs."""

    comptime BASE_HASH: UInt64 = HASH_JUKEBOX
    """Go `hashJukebox`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var item: Stack
    """The music disc played by the jukebox."""

    def __init__(out self, *, var item: Stack = Stack()):
        """Creates the block; omitted fields take Go zero values."""
        self.item = item^

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks, disc included."""
        return self.item == other.item

    def insert_item[
        T: WorldTypes
    ](
        self, mut hopper: Inventory, facing: Face, pos: Pos, mut tx: World[T]
    ) -> Bool:
        """Takes a music disc from a hopper into an empty jukebox (Go
        `InsertItem`)."""
        if not self.item.empty():
            return False
        for slot in range(hopper.size()):
            var source: Stack
            try:
                source = hopper.item(slot)
            except:
                return False
            if source.empty():
                continue
            if case .Some(m) = source.item_as[MusicDisc]():
                var j = self.copy()
                # Go stores the whole source stack (discs stack to one).
                j.item = source.copy()
                tx.set_block(pos, j)
                try:
                    hopper.set_item(slot, source.grow(-1))
                except:
                    pass
                tx.play_sound(
                    pos.vec3_centre(), MusicDiscPlay(disc_type=m.disc_type)
                )
                return True
        return False

    def extract_item[
        T: WorldTypes
    ](self, mut hopper: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
        """Never gives its disc to a hopper (Go `ExtractItem`, which waits for
        redstone)."""
        return False

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the disc and stops the music (Go's break handler)."""
        if self.disc():
            tx.drop_item(pos.vec3(), self.item)
            tx.play_sound(pos.vec3_centre(), MusicDiscEnd())

    def disc(self) -> Optional[DiscType]:
        """Returns the disc being played (Go `Disc`)."""
        if case .Some(m) = self.item.item_as[MusicDisc]():
            return m.disc_type
        return None

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Ejects the disc, or inserts the held one and starts playing it (Go
        `Activate`)."""
        var j = self.copy()
        if self.disc():
            tx.drop_item(pos.side(Face.UP).vec3_middle(), j.item)
            j.item = Stack()
            tx.set_block(pos, j)
            tx.play_sound(pos.vec3_centre(), MusicDiscEnd())
        elif not ctx.held.empty():
            if case .Some(m) = ctx.held.item_as[MusicDisc]():
                j.item = ctx.held.copy()
                tx.set_block(pos, j)
                tx.play_sound(pos.vec3_centre(), MusicDiscEnd())
                ctx.subtract_from_count(1)
                tx.play_sound(
                    pos.vec3_centre(), MusicDiscPlay(disc_type=m.disc_type)
                )
                ctx.popup = String(
                    t"Now playing: {m.disc_type.author()} -"
                    t" {m.disc_type.display_name()}"
                )
        return True

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:jukebox")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Jukebox()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Jukebox()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:jukebox", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Jukebox")
        if case .Some(d) = self.disc():
            var rec = tag.put_compound(root, "RecordItem")
            _ = tag.put_string(
                rec, "Name", MusicDisc(disc_type=d).encode_item().name
            )
            _ = tag.put_short(rec, "Damage", 0)
            _ = tag.put_byte(rec, "Count", UInt8(self.item.count()))
            var data = write_nbt(self.item)
            if len(data.children(data.root())) > 0:
                _ = tag.put_tree(rec, "tag", data, data.root())

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var j = self.copy()
        j.item = Stack()
        var rec = tag.get(root, "RecordItem")
        if not rec or tag.type_of(rec.value()) != TAG_COMPOUND:
            return j^
        var r = rec.value()
        var name = String()
        var count = 0
        if case .Some(n) = tag.get(r, "Name"):
            if tag.type_of(n) == TAG_STRING:
                name = tag.as_string(n)
        if case .Some(c) = tag.get(r, "Count"):
            if tag.type_of(c) == TAG_BYTE:
                count = Int(tag.as_byte(c))
        for d in music_discs():
            var disc = MusicDisc(disc_type=d)
            if disc.encode_item().name != name:
                continue
            var st = Stack(disc, count)
            if case .Some(t) = tag.get(r, "tag"):
                if tag.type_of(t) == TAG_COMPOUND:
                    var sub = Tree(TAG_COMPOUND)
                    for c in tag.children(t):
                        _ = sub.put_tree(sub.root(), tag.name(c), tag, c)
                    st = read_nbt(sub, st)
            j.item = st^
        return j^
