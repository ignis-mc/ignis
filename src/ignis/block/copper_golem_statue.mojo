"""`CopperGolemStatue`, ported from Dragonfly
`server/block/copper_golem_statue.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, Activate (pose changes), EncodeNBT,
DecodeNBT, Model, Wax, Strip, RandomTick (attemptOxidation), EncodeItem and
the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .copper_golem_pose import CopperGolemPose
from .cube.direction import Direction, directions
from .hash import HASH_COPPER_GOLEM_STATUE
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, copper_block_name


struct CopperGolemStatue(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser, Oxidisable
):
    """A decorative statue left behind by a copper golem."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_GOLEM_STATUE
    """Go `hashCopperGolemStatue`."""

    var facing: Direction
    """The direction the statue faces."""
    var pose: CopperGolemPose
    """The pose of the statue, kept in NBT."""
    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        pose: CopperGolemPose = CopperGolemPose.STANDING,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the statue faces.
            pose: The pose of the statue, kept in NBT.
            oxidation: The level of oxidation of the block.
            waxed: Whether the block is waxed, which stops it from oxidising.
        """
        self.facing = facing
        self.pose = pose
        self.oxidation = oxidation
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.pose == other.pose

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            copper_block_name(
                "copper_golem_statue", self.oxidation, self.waxed
            ),
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | UInt64(self.oxidation.uint8()) << 2
            | (UInt64(1) if self.waxed else UInt64(0)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return CopperGolemStatue(
            facing=Direction(Int(hash & 0x3)),
            oxidation=OxidationType(Int((hash >> 2) & 0x3)),
            waxed=(hash >> 4) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for waxed in [True, False]:
            for o in oxidation_types():
                for d in directions():
                    out.append(
                        CopperGolemStatue(facing=d, oxidation=o, waxed=waxed)
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            3, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def can_oxidate(self) -> Bool:
        """Reports whether the block can still oxidise (Go `CanOxidate`).

        Returns:
            True unless the block is waxed.
        """
        return not self.waxed

    def oxidation_level(self) -> OxidationType:
        """Returns the oxidation level (Go `OxidationLevel`).

        Returns:
            The oxidation level.
        """
        return self.oxidation

    def with_oxidation_level(self, o: OxidationType) -> Self:
        """Returns the block with another oxidation level (Go
        `WithOxidationLevel`).

        Args:
            o: The new oxidation level.

        Returns:
            The updated block.
        """
        var b = self
        b.oxidation = o
        return b
