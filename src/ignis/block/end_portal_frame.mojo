"""`EndPortalFrame`, ported from Dragonfly
`server/block/end_portal_frame.go`.

TODO(world-runtime): Model, UseOnBlock.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .cube.direction import Direction, directions
from .hash import HASH_END_PORTAL_FRAME
from .model.end_portal_frame import EndPortalFrame as EndPortalFrameModel


struct EndPortalFrame(
    Block,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightEmitter,
    ModelledBlock,
    NBTer,
):
    """A block that makes up an end portal."""

    comptime BASE_HASH: UInt64 = HASH_END_PORTAL_FRAME
    """Go `hashEndPortalFrame`."""
    comptime ModelType = EndPortalFrameModel
    """The model type (Go `Model`)."""

    var eye: Bool
    """Whether the frame has an eye of ender inserted."""
    var facing: Direction
    """The direction the frame faces."""

    def __init__(
        out self, *, eye: Bool = False, facing: Direction = Direction.NORTH
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.eye = eye
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:end_portal_frame",
            Properties()
            .with_bool("end_portal_eye_bit", self.eye)
            .with_string("minecraft:cardinal_direction", String(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (UInt64(1) if self.eye else UInt64(0)) | UInt64(
            Int(self.facing)
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return EndPortalFrame(
            eye=hash & 0x1 != 0, facing=Direction(Int((hash >> 1) & 0x3))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for dir in directions():
            for eye in [False, True]:
                out.append(EndPortalFrame(eye=eye, facing=dir))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 1

    def model(self) -> EndPortalFrameModel:
        """Returns the model of the block (Go `Model`)."""
        return EndPortalFrameModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:end_portal_frame", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the End portal block actor stored with the frame (Go
        `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "EndPortal")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the frame; eye and facing are block state (Go `DecodeNBT`).
        """
        return self.copy()
