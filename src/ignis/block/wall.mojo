"""`Wall`, ported from Dragonfly `server/block/wall.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Model, NeighbourUpdateTick, UseOnBlock, ConnectionType,
WithConnectionType, calculateConnections, calculatePost and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import AnyBlock, HASH_WALL, hash_block, unhash_block
from .model.wall import Wall as WallModel
from .register import break_info
from .wall_connection_type import WallConnectionType, wall_connection_types
from .wall_type import encode_wall_block, wall_blocks
from ..world.block import LiquidDisplacer
from .liquid import source_water_can_displace


struct Wall(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
):
    """A block similar to fences that prevents players from jumping over it and connects to more
    blocks."""

    comptime BASE_HASH: UInt64 = HASH_WALL
    """Go `hashWall`."""
    comptime ModelType = WallModel
    """The model type (Go `Model`)."""

    var block: AnyBlock
    """The block the wall is made of."""
    var north_connection: WallConnectionType
    """The connection to the north of the post."""
    var east_connection: WallConnectionType
    """The connection to the east of the post."""
    var south_connection: WallConnectionType
    """The connection to the south of the post."""
    var west_connection: WallConnectionType
    """The connection to the west of the post."""
    var post: Bool
    """Whether the wall extends to the full height of a block."""

    def __init__(
        out self,
        *,
        block: AnyBlock,
        north_connection: WallConnectionType = WallConnectionType.NONE,
        east_connection: WallConnectionType = WallConnectionType.NONE,
        south_connection: WallConnectionType = WallConnectionType.NONE,
        west_connection: WallConnectionType = WallConnectionType.NONE,
        post: Bool = False,
    ):
        """Creates the block; `block` is required, the other fields default to Go zero values.
        """
        self.block = block
        self.north_connection = north_connection
        self.east_connection = east_connection
        self.south_connection = south_connection
        self.west_connection = west_connection
        self.post = post

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{encode_wall_block(self.block)}_wall"),
            Properties()
            .with_string(
                "wall_connection_type_north", String(self.north_connection)
            )
            .with_string(
                "wall_connection_type_east", String(self.east_connection)
            )
            .with_string(
                "wall_connection_type_south", String(self.south_connection)
            )
            .with_string(
                "wall_connection_type_west", String(self.west_connection)
            )
            .with_byte("wall_post_bit", UInt8(self.post)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            hash_block(self.block)
            | UInt64(self.north_connection.uint8()) << 32
            | UInt64(self.east_connection.uint8()) << 34
            | UInt64(self.south_connection.uint8()) << 36
            | UInt64(self.west_connection.uint8()) << 38
            | (UInt64(1) if self.post else UInt64(0)) << 40
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Wall(
            block=unhash_block(hash & 0xFFFFFFFF),
            north_connection=WallConnectionType(Int((hash >> 32) & 0x3)),
            east_connection=WallConnectionType(Int((hash >> 34) & 0x3)),
            south_connection=WallConnectionType(Int((hash >> 36) & 0x3)),
            west_connection=WallConnectionType(Int((hash >> 38) & 0x3)),
            post=(hash >> 40) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for b in wall_blocks():
            for north in wall_connection_types():
                for east in wall_connection_types():
                    for south in wall_connection_types():
                        for west in wall_connection_types():
                            for post in [False, True]:
                                out.append(
                                    Wall(
                                        block=b,
                                        north_connection=north,
                                        east_connection=east,
                                        south_connection=south,
                                        west_connection=west,
                                        post=post,
                                    )
                                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        var info = break_info(self.block.kind, self.block.state).value()
        return new_break_info(
            info.hardness, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(info.blast_resistance)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> WallModel:
        """Returns the model of the block (Go `Model`)."""
        return WallModel(
            north_connection=self.north_connection.height(),
            east_connection=self.east_connection.height(),
            south_connection=self.south_connection.height(),
            west_connection=self.west_connection.height(),
            post=self.post,
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(t"minecraft:{encode_wall_block(self.block)}_wall"), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wall_blocks():
            out.append(Wall(block=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
