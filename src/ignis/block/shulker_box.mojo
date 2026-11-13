"""`ShulkerBox`, ported from Dragonfly `server/block/shulker_box.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the inventory, viewer and animation fields,
NewShulkerBox, Inventory, WithName, AddViewer, RemoveViewer, Activate,
UseOnBlock, Tick, open/close, Model, SideClosed, DecodeNBT, EncodeNBT,
EncodeItem and the drops.
"""

from ..item.optional_colour import OptionalColour, optional_colours
from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face
from .hash import HASH_SHULKER_BOX


struct ShulkerBox(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A dye-able block that stores items; unlike other containers it keeps them when broken.
    """

    comptime BASE_HASH: UInt64 = HASH_SHULKER_BOX
    """Go `hashShulkerBox`."""

    var colour: OptionalColour
    """The colour of the shulker box, or none."""
    var facing: Face
    """The direction the shulker box opens to, kept in NBT."""
    var custom_name: String
    """The custom name of the shulker box."""

    def __init__(
        out self,
        *,
        colour: OptionalColour = OptionalColour.NONE,
        facing: Face = Face.DOWN,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the shulker box, or none.
            facing: The direction the shulker box opens to, kept in NBT.
            custom_name: The custom name of the shulker box.
        """
        self.colour = colour
        self.facing = facing
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.facing == other.facing
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        if case .Some(c) = self.colour.colour():
            return BlockState(String(t"minecraft:{c}_shulker_box"))
        return BlockState("minecraft:undyed_shulker_box")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return ShulkerBox(colour=OptionalColour(Int(hash & 0x1F)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for colour in optional_colours():
            out.append(ShulkerBox(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
