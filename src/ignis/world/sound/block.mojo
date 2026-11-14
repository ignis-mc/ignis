"""The block sounds, ported from Dragonfly `server/world/sound/block.go`."""

from ...block.hash import AnyBlock
from ..block_registry import UNKNOWN_KIND
from . import Sound
from .disc_type import DiscType
from .instrument import Instrument


struct BlockPlace(ImplicitlyCopyable, Sound):
    """A sound sent when a block is placed (Go `sound.BlockPlace`)."""

    comptime SOUND_ID: Int = 1
    """The sound ID of `BlockPlace`."""

    var block: AnyBlock
    """Block is the block which is placed, for which a sound should be
    played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct BlockBreaking(ImplicitlyCopyable, Sound):
    """A sound sent continuously while a player is breaking a block (Go
    `sound.BlockBreaking`)."""

    comptime SOUND_ID: Int = 2
    """The sound ID of `BlockBreaking`."""

    var block: AnyBlock
    """Block is the block which is being broken, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


@fieldwise_init
struct GlassBreak(ImplicitlyCopyable, Sound):
    """A sound played when a glass block or item is broken (Go
    `sound.GlassBreak`)."""

    comptime SOUND_ID: Int = 3
    """The sound ID of `GlassBreak`."""


@fieldwise_init
struct Fizz(ImplicitlyCopyable, Sound):
    """A sound sent when a lava block and a water block interact with each
    other in a way that one of them turns into a solid block (Go
    `sound.Fizz`)."""

    comptime SOUND_ID: Int = 4
    """The sound ID of `Fizz`."""


@fieldwise_init
struct AnvilLand(ImplicitlyCopyable, Sound):
    """Played when an anvil lands on the ground (Go `sound.AnvilLand`)."""

    comptime SOUND_ID: Int = 5
    """The sound ID of `AnvilLand`."""


@fieldwise_init
struct AnvilUse(ImplicitlyCopyable, Sound):
    """Played when an anvil is used (Go `sound.AnvilUse`)."""

    comptime SOUND_ID: Int = 6
    """The sound ID of `AnvilUse`."""


@fieldwise_init
struct AnvilBreak(ImplicitlyCopyable, Sound):
    """Played when an anvil is broken (Go `sound.AnvilBreak`)."""

    comptime SOUND_ID: Int = 7
    """The sound ID of `AnvilBreak`."""


@fieldwise_init
struct ChestOpen(ImplicitlyCopyable, Sound):
    """Played when a chest is opened (Go `sound.ChestOpen`)."""

    comptime SOUND_ID: Int = 8
    """The sound ID of `ChestOpen`."""


@fieldwise_init
struct ChestClose(ImplicitlyCopyable, Sound):
    """Played when a chest is closed (Go `sound.ChestClose`)."""

    comptime SOUND_ID: Int = 9
    """The sound ID of `ChestClose`."""


@fieldwise_init
struct EnderChestOpen(ImplicitlyCopyable, Sound):
    """Played when a ender chest is opened (Go `sound.EnderChestOpen`)."""

    comptime SOUND_ID: Int = 10
    """The sound ID of `EnderChestOpen`."""


@fieldwise_init
struct EnderChestClose(ImplicitlyCopyable, Sound):
    """Played when a ender chest is closed (Go `sound.EnderChestClose`)."""

    comptime SOUND_ID: Int = 11
    """The sound ID of `EnderChestClose`."""


@fieldwise_init
struct BarrelOpen(ImplicitlyCopyable, Sound):
    """Played when a barrel is opened (Go `sound.BarrelOpen`)."""

    comptime SOUND_ID: Int = 12
    """The sound ID of `BarrelOpen`."""


@fieldwise_init
struct BarrelClose(ImplicitlyCopyable, Sound):
    """Played when a barrel is closed (Go `sound.BarrelClose`)."""

    comptime SOUND_ID: Int = 13
    """The sound ID of `BarrelClose`."""


@fieldwise_init
struct Deny(ImplicitlyCopyable, Sound):
    """A sound played when a block is placed or broken above a 'Deny' block
    from Education edition (Go `sound.Deny`)."""

    comptime SOUND_ID: Int = 14
    """The sound ID of `Deny`."""


@fieldwise_init
struct ShulkerBoxOpen(ImplicitlyCopyable, Sound):
    """A sound played when a shulker box is opened (Go `sound.ShulkerBoxOpen`).
    """

    comptime SOUND_ID: Int = 15
    """The sound ID of `ShulkerBoxOpen`."""


@fieldwise_init
struct ShulkerBoxClose(ImplicitlyCopyable, Sound):
    """A sound played when a shulker box is closed (Go
    `sound.ShulkerBoxClose`)."""

    comptime SOUND_ID: Int = 16
    """The sound ID of `ShulkerBoxClose`."""


struct DoorOpen(ImplicitlyCopyable, Sound):
    """A sound played when a door is opened (Go `sound.DoorOpen`)."""

    comptime SOUND_ID: Int = 17
    """The sound ID of `DoorOpen`."""

    var block: AnyBlock
    """Block is the block which is being opened, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct DoorClose(ImplicitlyCopyable, Sound):
    """A sound played when a door is closed (Go `sound.DoorClose`)."""

    comptime SOUND_ID: Int = 18
    """The sound ID of `DoorClose`."""

    var block: AnyBlock
    """Block is the block which is being closed, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct TrapdoorOpen(ImplicitlyCopyable, Sound):
    """A sound played when a trapdoor is opened (Go `sound.TrapdoorOpen`)."""

    comptime SOUND_ID: Int = 19
    """The sound ID of `TrapdoorOpen`."""

    var block: AnyBlock
    """Block is the block which is being opened, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct TrapdoorClose(ImplicitlyCopyable, Sound):
    """A sound played when a trapdoor is closed (Go `sound.TrapdoorClose`)."""

    comptime SOUND_ID: Int = 20
    """The sound ID of `TrapdoorClose`."""

    var block: AnyBlock
    """Block is the block which is being closed, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct FenceGateOpen(ImplicitlyCopyable, Sound):
    """A sound played when a fence gate is opened (Go `sound.FenceGateOpen`)."""

    comptime SOUND_ID: Int = 21
    """The sound ID of `FenceGateOpen`."""

    var block: AnyBlock
    """Block is the block which is being opened, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct FenceGateClose(ImplicitlyCopyable, Sound):
    """A sound played when a fence gate is closed (Go `sound.FenceGateClose`).
    """

    comptime SOUND_ID: Int = 22
    """The sound ID of `FenceGateClose`."""

    var block: AnyBlock
    """Block is the block which is being closed, for which a sound should
    be played. The sound played depends on the block type."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


@fieldwise_init
struct DoorCrash(ImplicitlyCopyable, Sound):
    """A sound played when a door is forced open (Go `sound.DoorCrash`)."""

    comptime SOUND_ID: Int = 23
    """The sound ID of `DoorCrash`."""


@fieldwise_init
struct Click(ImplicitlyCopyable, Sound):
    """A clicking sound (Go `sound.Click`)."""

    comptime SOUND_ID: Int = 24
    """The sound ID of `Click`."""


@fieldwise_init
struct Ignite(ImplicitlyCopyable, Sound):
    """A sound played when using a flint & steel (Go `sound.Ignite`)."""

    comptime SOUND_ID: Int = 25
    """The sound ID of `Ignite`."""


@fieldwise_init
struct TNT(ImplicitlyCopyable, Sound):
    """A sound played when ignited (Go `sound.TNT`)."""

    comptime SOUND_ID: Int = 26
    """The sound ID of `TNT`."""


@fieldwise_init
struct FireExtinguish(ImplicitlyCopyable, Sound):
    """A sound played when a fire is extinguished (Go `sound.FireExtinguish`).
    """

    comptime SOUND_ID: Int = 27
    """The sound ID of `FireExtinguish`."""


struct Note(ImplicitlyCopyable, Sound):
    """A sound played by note blocks (Go `sound.Note`)."""

    comptime SOUND_ID: Int = 28
    """The sound ID of `Note`."""

    var instrument: Instrument
    """Instrument is the instrument of the note block."""
    var pitch: Int
    """Pitch is the pitch of the note."""

    def __init__(
        out self, *, instrument: Instrument = Instrument.PIANO, pitch: Int = 0
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.instrument = instrument
        self.pitch = pitch


struct MusicDiscPlay(ImplicitlyCopyable, Sound):
    """A sound played when a music disc has started playing in a jukebox (Go
    `sound.MusicDiscPlay`)."""

    comptime SOUND_ID: Int = 29
    """The sound ID of `MusicDiscPlay`."""

    var disc_type: DiscType
    """DiscType is the disc type of the music disc."""

    def __init__(out self, *, disc_type: DiscType = DiscType.DISC_13):
        """Creates the value; omitted fields take Go zero values."""
        self.disc_type = disc_type


@fieldwise_init
struct MusicDiscEnd(ImplicitlyCopyable, Sound):
    """A sound played when a music disc has stopped playing in a jukebox (Go
    `sound.MusicDiscEnd`)."""

    comptime SOUND_ID: Int = 30
    """The sound ID of `MusicDiscEnd`."""


@fieldwise_init
struct ItemAdd(ImplicitlyCopyable, Sound):
    """A sound played when an item is added to an item frame or campfire (Go
    `sound.ItemAdd`)."""

    comptime SOUND_ID: Int = 31
    """The sound ID of `ItemAdd`."""


@fieldwise_init
struct ItemFrameRemove(ImplicitlyCopyable, Sound):
    """A sound played when an item is removed from an item frame (Go
    `sound.ItemFrameRemove`)."""

    comptime SOUND_ID: Int = 32
    """The sound ID of `ItemFrameRemove`."""


@fieldwise_init
struct ItemFrameRotate(ImplicitlyCopyable, Sound):
    """A sound played when an item frame's item is rotated (Go
    `sound.ItemFrameRotate`)."""

    comptime SOUND_ID: Int = 33
    """The sound ID of `ItemFrameRotate`."""


@fieldwise_init
struct FurnaceCrackle(ImplicitlyCopyable, Sound):
    """A sound played every one to five seconds from a furnace (Go
    `sound.FurnaceCrackle`)."""

    comptime SOUND_ID: Int = 34
    """The sound ID of `FurnaceCrackle`."""


@fieldwise_init
struct CampfireCrackle(ImplicitlyCopyable, Sound):
    """A sound played every one to five seconds from a campfire (Go
    `sound.CampfireCrackle`)."""

    comptime SOUND_ID: Int = 35
    """The sound ID of `CampfireCrackle`."""


@fieldwise_init
struct BlastFurnaceCrackle(ImplicitlyCopyable, Sound):
    """A sound played every one to five seconds from a blast furnace (Go
    `sound.BlastFurnaceCrackle`)."""

    comptime SOUND_ID: Int = 36
    """The sound ID of `BlastFurnaceCrackle`."""


@fieldwise_init
struct SmokerCrackle(ImplicitlyCopyable, Sound):
    """A sound played every one to five seconds from a smoker (Go
    `sound.SmokerCrackle`)."""

    comptime SOUND_ID: Int = 37
    """The sound ID of `SmokerCrackle`."""


@fieldwise_init
struct ComposterEmpty(ImplicitlyCopyable, Sound):
    """A sound played when a composter has been emptied (Go
    `sound.ComposterEmpty`)."""

    comptime SOUND_ID: Int = 38
    """The sound ID of `ComposterEmpty`."""


@fieldwise_init
struct ComposterFill(ImplicitlyCopyable, Sound):
    """A sound played when a composter has been filled, but not gone up a layer
    (Go `sound.ComposterFill`)."""

    comptime SOUND_ID: Int = 39
    """The sound ID of `ComposterFill`."""


@fieldwise_init
struct ComposterFillLayer(ImplicitlyCopyable, Sound):
    """A sound played when a composter has been filled and gone up a layer (Go
    `sound.ComposterFillLayer`)."""

    comptime SOUND_ID: Int = 40
    """The sound ID of `ComposterFillLayer`."""


@fieldwise_init
struct ComposterReady(ImplicitlyCopyable, Sound):
    """A sound played when a composter has produced bone meal and is ready to
    be collected (Go `sound.ComposterReady`)."""

    comptime SOUND_ID: Int = 41
    """The sound ID of `ComposterReady`."""


@fieldwise_init
struct PotionBrewed(ImplicitlyCopyable, Sound):
    """A sound played when a potion is brewed (Go `sound.PotionBrewed`)."""

    comptime SOUND_ID: Int = 42
    """The sound ID of `PotionBrewed`."""


@fieldwise_init
struct PowerOn(ImplicitlyCopyable, Sound):
    """A sound played when a redstone component is powered on (Go
    `sound.PowerOn`)."""

    comptime SOUND_ID: Int = 43
    """The sound ID of `PowerOn`."""


@fieldwise_init
struct PowerOff(ImplicitlyCopyable, Sound):
    """A sound played when a redstone component is powered off (Go
    `sound.PowerOff`)."""

    comptime SOUND_ID: Int = 44
    """The sound ID of `PowerOff`."""


@fieldwise_init
struct LecternBookPlace(ImplicitlyCopyable, Sound):
    """A sound played when a book is placed in a lectern (Go
    `sound.LecternBookPlace`)."""

    comptime SOUND_ID: Int = 45
    """The sound ID of `LecternBookPlace`."""


@fieldwise_init
struct SignWaxed(ImplicitlyCopyable, Sound):
    """A sound played when a sign is waxed (Go `sound.SignWaxed`)."""

    comptime SOUND_ID: Int = 46
    """The sound ID of `SignWaxed`."""


@fieldwise_init
struct WaxedSignFailedInteraction(ImplicitlyCopyable, Sound):
    """A sound played when a player tries to interact with a waxed sign (Go
    `sound.WaxedSignFailedInteraction`)."""

    comptime SOUND_ID: Int = 47
    """The sound ID of `WaxedSignFailedInteraction`."""


@fieldwise_init
struct WaxRemoved(ImplicitlyCopyable, Sound):
    """A sound played when wax is removed from a block (Go `sound.WaxRemoved`).
    """

    comptime SOUND_ID: Int = 48
    """The sound ID of `WaxRemoved`."""


@fieldwise_init
struct CopperScraped(ImplicitlyCopyable, Sound):
    """A sound played when a player scrapes a copper block to reduce its
    oxidation level (Go `sound.CopperScraped`)."""

    comptime SOUND_ID: Int = 49
    """The sound ID of `CopperScraped`."""


struct DecoratedPotInserted(ImplicitlyCopyable, Sound):
    """A sound played when an item is successfully inserted into a decorated
    pot (Go `sound.DecoratedPotInserted`)."""

    comptime SOUND_ID: Int = 50
    """The sound ID of `DecoratedPotInserted`."""

    var progress: Float64
    """Progress is how much of the decorated pot has been filled."""

    def __init__(out self, *, progress: Float64 = 0):
        """Creates the value; omitted fields take Go zero values."""
        self.progress = progress


@fieldwise_init
struct DecoratedPotInsertFailed(ImplicitlyCopyable, Sound):
    """A sound played when an item fails to be inserted into a decorated pot
    (Go `sound.DecoratedPotInsertFailed`)."""

    comptime SOUND_ID: Int = 51
    """The sound ID of `DecoratedPotInsertFailed`."""


@fieldwise_init
struct EnderEyePlaced(ImplicitlyCopyable, Sound):
    """A sound played when an eye of ender is placed into an end portal frame
    (Go `sound.EnderEyePlaced`)."""

    comptime SOUND_ID: Int = 52
    """The sound ID of `EnderEyePlaced`."""


@fieldwise_init
struct EndPortalCreated(ImplicitlyCopyable, Sound):
    """A sound played when a complete end portal frame ring is activated (Go
    `sound.EndPortalCreated`)."""

    comptime SOUND_ID: Int = 53
    """The sound ID of `EndPortalCreated`."""
