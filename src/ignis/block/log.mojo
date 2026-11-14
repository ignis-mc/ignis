"""`Log`, ported from Dragonfly `server/block/log.go`.

TODO(world-runtime): Strip, EncodeItem, FlammabilityInfo,
FuelInfo and the drops.
"""

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
from .hash import AnyBlock
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis
from .hash import HASH_LOG
from .model.solid import Solid as SolidModel
from .wood_type import WoodType, wood_types


struct Log(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    ModelledBlock,
    UsableOnBlock,
):
    """A naturally occurring block found in trees, used to craft other blocks.
    """

    comptime BASE_HASH: UInt64 = HASH_LOG
    """Go `hashLog`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood."""
    var stripped: Bool
    """Whether the bark has been stripped off."""
    var axis: Axis
    """The axis the block faces."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        stripped: Bool = False,
        axis: Axis = Axis.Y,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood.
            stripped: Whether the bark has been stripped off.
            axis: The axis the block faces.
        """
        self.wood = wood
        self.stripped = stripped
        self.axis = axis

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
        var prefix = "stripped_" if self.stripped else ""
        var suffix = "log"
        if self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED:
            suffix = "stem"
        return BlockState(
            String(t"minecraft:{prefix}{self.wood}_{suffix}"),
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.wood.uint8())
            | (UInt64(1) if self.stripped else UInt64(0)) << 4
            | UInt64(Int(self.axis)) << 5
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Log(
            wood=WoodType(Int(hash & 0xF)),
            stripped=(hash >> 4) & 0x1 != 0,
            axis=Axis(Int((hash >> 5) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for w in wood_types():
            if w == WoodType.BAMBOO:
                continue
            for axis in range(3):
                out.append(Log(wood=w, stripped=True, axis=Axis(axis)))
                out.append(Log(wood=w, stripped=False, axis=Axis(axis)))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        var info = new_break_info(2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
        if self.wood == WoodType.MANGROVE and not self.stripped:
            return info.with_blast_resistance(0.4)
        return info

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the log along the clicked face's axis (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var b = self
        b.axis = at.value()[1].axis()
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()), False)
        ]
