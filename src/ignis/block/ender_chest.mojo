"""`EnderChest`, ported from Dragonfly `server/block/ender_chest.go`.

The window shows the player's own ender chest inventory (the session's);
the world counts the viewers of the block for the lid (Go's `viewers`).
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.stack import Stack
from ..item.tool import ToolInfo
from ..mgl64 import Vec3
from ..world.block import Block, LightDiffuser, LightEmitter, NBTer
from ..world.sound.block import EnderChestClose, EnderChestOpen
from ..world.viewer import BLOCK_ACTION_CLOSE, BLOCK_ACTION_OPEN
from ..world.world import World, WorldTypes
from .block import (
    Activatable,
    Openable,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    first_replaceable,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    Dropper,
    new_break_info,
)
from .cube.face import Face
from .cube.pos import Pos
from .obsidian import Obsidian
from .cube.direction import Direction, directions
from .hash import HASH_ENDER_CHEST
from .model.chest import Chest as ChestModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct EnderChest(
    Activatable,
    Block,
    Breakable,
    Dropper,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
    Openable,
    UsableOnBlock,
):
    """A type of chest whose contents are exclusive to each player, and can be accessed from
    anywhere."""

    comptime BASE_HASH: UInt64 = HASH_ENDER_CHEST
    """Go `hashEnderChest`."""
    comptime ModelType = ChestModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the chest faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:ender_chest",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return EnderChest(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(EnderChest(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            22.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(600)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 7

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ChestModel:
        """Returns the model of the block (Go `Model`)."""
        return ChestModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:ender_chest", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops 8 obsidian, itself with silk touch (Go `silkTouchDrop`)."""
        if silk_touch:
            return [Stack(EnderChest(), 1)]
        return [Stack(Obsidian(), 8)]

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the user's ender chest window (Go `Activate`)."""
        ctx.open_container = True
        return True

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: User,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the chest facing the user (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var c = EnderChest(facing=user.direction().opposite())
        return [Placement(at.value()[0], AnyBlock(Self.BASE_HASH, c.hash()))]

    def opened[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Opens the lid (Go `open`)."""
        for v in tx.viewers(pos.vec3()):
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_OPEN)
        tx.play_sound(pos.vec3_centre(), EnderChestOpen())

    def closed[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Closes the lid (Go `close`)."""
        for v in tx.viewers(pos.vec3()):
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_CLOSE)
        tx.play_sound(pos.vec3_centre(), EnderChestClose())

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "EnderChest")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        return Self(facing=self.facing)

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
