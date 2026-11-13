"""The item sounds, ported from Dragonfly `server/world/sound/item.go`.
"""

from ...block.hash import AnyBlock
from ..block_registry import UNKNOWN_KIND
from . import Sound
from .goat_horn import Horn


@fieldwise_init
struct ItemBreak(ImplicitlyCopyable, Sound):
    """A sound played when an item in the inventory is broken, such as when a
    tool reaches 0 durability and breaks (Go `sound.ItemBreak`)."""

    comptime SOUND_ID: Int = 70
    """The sound ID of `ItemBreak`."""


@fieldwise_init
struct ItemThrow(ImplicitlyCopyable, Sound):
    """A sound played when a player throws an item, such as a snowball (Go
    `sound.ItemThrow`)."""

    comptime SOUND_ID: Int = 71
    """The sound ID of `ItemThrow`."""


struct ItemUseOn(ImplicitlyCopyable, Sound):
    """A sound played when a player uses its item on a block. An example of
    this is when a player uses a shovel to turn grass into dirt path.
    Note that in these cases, the Block is actually the new block, not
    the old one (Go `sound.ItemUseOn`)."""

    comptime SOUND_ID: Int = 72
    """The sound ID of `ItemUseOn`."""

    var block: AnyBlock
    """Block is generally the block that was created by using the item on a
    block. The sound played differs depending on this field."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values.

        Args:
            block: Block is generally the block that was created by using...
        """
        self.block = block


@fieldwise_init
struct EquipItem(ImplicitlyCopyable, Sound):
    """A sound played when the player fast equips an item by using it (Go
    `sound.EquipItem`).

    TODO(world-runtime): the `Item world.Item` field."""

    comptime SOUND_ID: Int = 73
    """The sound ID of `EquipItem`."""


struct BucketFill(ImplicitlyCopyable, Sound):
    """A sound played when a bucket is filled using a liquid source block from
    the world (Go `sound.BucketFill`)."""

    comptime SOUND_ID: Int = 74
    """The sound ID of `BucketFill`."""

    var liquid: AnyBlock
    """Liquid is the liquid that the bucket is filled up with."""

    def __init__(
        out self, *, liquid: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values.

        Args:
            liquid: Liquid is the liquid that the bucket is filled up with.
        """
        self.liquid = liquid


struct BucketEmpty(ImplicitlyCopyable, Sound):
    """A sound played when a bucket with a liquid in it is placed into the
    world (Go `sound.BucketEmpty`)."""

    comptime SOUND_ID: Int = 75
    """The sound ID of `BucketEmpty`."""

    var liquid: AnyBlock
    """Liquid is the liquid that the bucket places into the world."""

    def __init__(
        out self, *, liquid: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values.

        Args:
            liquid: Liquid is the liquid that the bucket places into the world.
        """
        self.liquid = liquid


@fieldwise_init
struct BowShoot(ImplicitlyCopyable, Sound):
    """A sound played when a bow is shot (Go `sound.BowShoot`)."""

    comptime SOUND_ID: Int = 76
    """The sound ID of `BowShoot`."""


struct CrossbowLoad(ImplicitlyCopyable, Sound):
    """A sound when a crossbow is being loaded (Go `sound.CrossbowLoad`)."""

    comptime SOUND_ID: Int = 77
    """The sound ID of `CrossbowLoad`."""

    var stage: Int
    """Stage is the stage of the crossbow."""
    var quick_charge: Bool
    """QuickCharge returns if the item being used has quick charge
    enchantment."""

    def __init__(out self, *, stage: Int = 0, quick_charge: Bool = False):
        """Creates the value; omitted fields take Go zero values.

        Args:
            stage: Stage is the stage of the crossbow.
            quick_charge: QuickCharge returns if the item being used has quick...
        """
        self.stage = stage
        self.quick_charge = quick_charge


@fieldwise_init
struct CrossbowShoot(ImplicitlyCopyable, Sound):
    """A sound played when a crossbow is shot (Go `sound.CrossbowShoot`)."""

    comptime SOUND_ID: Int = 78
    """The sound ID of `CrossbowShoot`."""


@fieldwise_init
struct ArrowHit(ImplicitlyCopyable, Sound):
    """A sound played when an arrow hits ground (Go `sound.ArrowHit`)."""

    comptime SOUND_ID: Int = 79
    """The sound ID of `ArrowHit`."""


@fieldwise_init
struct Teleport(ImplicitlyCopyable, Sound):
    """A sound played upon teleportation of an enderman, or teleportation of a
    player by an ender pearl or a chorus fruit (Go `sound.Teleport`)."""

    comptime SOUND_ID: Int = 80
    """The sound ID of `Teleport`."""


@fieldwise_init
struct UseSpyglass(ImplicitlyCopyable, Sound):
    """A sound played when a player uses a spyglass (Go `sound.UseSpyglass`)."""

    comptime SOUND_ID: Int = 81
    """The sound ID of `UseSpyglass`."""


@fieldwise_init
struct StopUsingSpyglass(ImplicitlyCopyable, Sound):
    """A sound played when a player stops using a spyglass (Go
    `sound.StopUsingSpyglass`)."""

    comptime SOUND_ID: Int = 82
    """The sound ID of `StopUsingSpyglass`."""


struct GoatHorn(ImplicitlyCopyable, Sound):
    """A sound played when a player uses a goat horn (Go `sound.GoatHorn`)."""

    comptime SOUND_ID: Int = 83
    """The sound ID of `GoatHorn`."""

    var horn: Horn
    """Horn is the type of the goat horn."""

    def __init__(out self, *, horn: Horn = Horn.PONDER):
        """Creates the value; omitted fields take Go zero values.

        Args:
            horn: Horn is the type of the goat horn.
        """
        self.horn = horn


@fieldwise_init
struct FireCharge(ImplicitlyCopyable, Sound):
    """A sound played when a player lights a block on fire with a fire charge,
    or when a dispenser or a blaze shoots a fireball (Go
    `sound.FireCharge`)."""

    comptime SOUND_ID: Int = 84
    """The sound ID of `FireCharge`."""


@fieldwise_init
struct Totem(ImplicitlyCopyable, Sound):
    """A sound played when a player uses a totem (Go `sound.Totem`)."""

    comptime SOUND_ID: Int = 85
    """The sound ID of `Totem`."""


comptime CROSSBOW_LOADING_START = 0
"""The stage where a crossbow starts to load (Go `CrossbowLoadingStart`)."""
comptime CROSSBOW_LOADING_MIDDLE = 1
"""The stage where a crossbow is loading but not finished (Go
`CrossbowLoadingMiddle`)."""
comptime CROSSBOW_LOADING_END = 2
"""The stage where a crossbow has finished loading (Go
`CrossbowLoadingEnd`)."""
