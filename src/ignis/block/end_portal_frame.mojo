"""`EndPortalFrame`, ported from Dragonfly
`server/block/end_portal_frame.go`.

TODO(world-runtime): Model, UseOnBlock, EncodeItem.
"""

from ..world.block import Block, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .cube.direction import Direction, directions
from .hash import HASH_END_PORTAL_FRAME
from .model.end_portal_frame import EndPortalFrame as EndPortalFrameModel


struct EndPortalFrame(
    Block, Equatable, ImplicitlyCopyable, LightEmitter, ModelledBlock
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
        """Creates the block; omitted fields take Go zero values.

        Args:
            eye: Whether the frame has an eye of ender inserted.
            facing: The direction the frame faces.
        """
        self.eye = eye
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:end_portal_frame",
            Properties()
            .with_bool("end_portal_eye_bit", self.eye)
            .with_string("minecraft:cardinal_direction", String(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (UInt64(1) if self.eye else UInt64(0)) | UInt64(
            Int(self.facing)
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return EndPortalFrame(
            eye=hash & 0x1 != 0, facing=Direction(Int((hash >> 1) & 0x3))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for dir in directions():
            for eye in [False, True]:
                out.append(EndPortalFrame(eye=eye, facing=dir))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 1

    def model(self) -> EndPortalFrameModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EndPortalFrameModel()
