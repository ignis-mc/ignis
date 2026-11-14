"""Sound and particle packets, ported from Dragonfly `session/world.go`
(`playSound`, `ViewParticle`).

Go switches on the sound's type; here each sound type has a unique
`SOUND_ID` and `play_sound` compares it at compile time, then `rebind`s the
value to the matched type. Differences from Go:

- `SignWaxed`, `WaxRemoved`, `CopperScraped`, `LightningExplode` and
  `LightningThunder` send their `LevelEvent` or `PlaySound` only. Go falls
  through and also sends a `LevelSoundEvent` with an empty sound type, which
  plays nothing.
- `EquipItem` has no item yet (`world/sound/item.mojo`), so it always plays
  `equip.generic` (Go picks the armour tier's sound).
- `Splash` without a colour uses `effect.resulting_colour` of no effects, as
  Go does; `EggSmash` needs the egg's item runtime ID from the queue's item
  registry and sends nothing without one.
"""

from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.math import Vec3 as ProtocolVec3
from minecraft.protocol.packet import level_event as le
from minecraft.protocol.packet import level_sound_event as lse
from minecraft.protocol.packet.block_event import BlockEvent
from minecraft.protocol.packet.level_event import LevelEvent
from minecraft.protocol.packet.level_sound_event import LevelSoundEvent
from minecraft.protocol.packet.play_sound import PlaySound

from ..block.hash import AnyBlock
from ..block.water import Water
from ..entity.effect import Effect as EntityEffect, resulting_colour
from ..internal.color import RGBA
from ..item.egg import Egg
from ..item.item import int32_from_rgba
from ..mgl64 import Vec3
from ..world.particle import Particle
from ..world.particle.block import (
    BlockBreak,
    BlockForceField,
    BoneMeal,
    DragonEggTeleport,
    Dust,
    DustPlume,
    Evaporate,
    Flame,
    Lava,
    LavaDrip,
    Note as NoteParticle,
    PunchBlock,
    WaterDrip,
)
from ..world.particle.entity import (
    Effect,
    EggSmash,
    EndermanTeleport,
    EntityFlame,
    HugeExplosion,
    SnowballPoof,
    Splash,
)
from ..world.sound import Sound
from ..world.sound.ambient import LightningExplode, LightningThunder
from ..world.sound.block import (
    AnvilBreak,
    AnvilLand,
    AnvilUse,
    BarrelClose,
    BarrelOpen,
    BlastFurnaceCrackle,
    BlockBreaking,
    BlockPlace,
    CampfireCrackle,
    ChestClose,
    ChestOpen,
    Click,
    ComposterEmpty,
    ComposterFill,
    ComposterFillLayer,
    ComposterReady,
    CopperScraped,
    DecoratedPotInsertFailed,
    DecoratedPotInserted,
    Deny,
    DoorClose,
    DoorCrash,
    DoorOpen,
    EndPortalCreated,
    EnderChestClose,
    EnderChestOpen,
    EnderEyePlaced,
    FenceGateClose,
    FenceGateOpen,
    FireExtinguish,
    Fizz,
    FurnaceCrackle,
    GlassBreak,
    Ignite,
    ItemAdd,
    ItemFrameRemove,
    ItemFrameRotate,
    LecternBookPlace,
    MusicDiscEnd,
    MusicDiscPlay,
    Note,
    PotionBrewed,
    PowerOff,
    PowerOn,
    ShulkerBoxClose,
    ShulkerBoxOpen,
    SignWaxed,
    SmokerCrackle,
    TNT,
    TrapdoorClose,
    TrapdoorOpen,
    WaxRemoved,
    WaxedSignFailedInteraction,
)
from ..world.sound.custom import Custom
from ..world.sound.entity import (
    Attack,
    Burning,
    Burp,
    Drowning,
    Experience,
    Explosion,
    Fall,
    FireworkBlast,
    FireworkHugeBlast,
    FireworkLaunch,
    FireworkTwinkle,
    GhastShoot,
    GhastWarning,
    LevelUp,
    Pop,
    Thunder,
)
from ..world.sound.disc_type import DiscType
from ..world.sound.goat_horn import Horn
from ..world.sound.item import (
    ArrowHit,
    BowShoot,
    BucketEmpty,
    BucketFill,
    CrossbowLoad,
    CrossbowShoot,
    EquipItem,
    FireCharge,
    GoatHorn,
    ItemBreak,
    ItemThrow,
    ItemUseOn,
    StopUsingSpyglass,
    Teleport,
    Totem,
    UseSpyglass,
)
from .viewer import PacketQueue

comptime CROSSBOW_LOADING_START = 0
"""Go `sound.CrossbowLoadingStart`."""
comptime CROSSBOW_LOADING_MIDDLE = 1
"""Go `sound.CrossbowLoadingMiddle`."""
comptime CROSSBOW_LOADING_END = 2
"""Go `sound.CrossbowLoadingEnd`."""


def play_sound[
    S: Sound
](mut q: PacketQueue, pos: Vec3, s: S, disable_relative: Bool):
    """Queues the packet that plays a sound at a position (Go `playSound`)."""
    var pk = LevelSoundEvent()
    pk.position = _vec32(pos)
    pk.entity_type = ":"
    pk.extra_data = -1
    pk.disable_relative_volume = disable_relative
    comptime id = S.SOUND_ID
    comptime if id == EquipItem.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_EQUIP_GENERIC
    elif id == Note.SOUND_ID:
        var so = rebind[Note](s)
        pk.sound_type = lse.SOUND_EVENT_NOTE
        pk.extra_data = (so.instrument.int32() << 8) | Int32(so.pitch)
    elif id == DoorCrash.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ZOMBIE_DOOR_CRASH, pos)
        return
    elif id == Explosion.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_EXPLODE
    elif id == Thunder.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_THUNDER
        pk.entity_type = "minecraft:lightning_bolt"
    elif id == Click.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_CLICK, pos)
        return
    elif id == SignWaxed.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_WAX_ON, pos)
        return
    elif id == WaxedSignFailedInteraction.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_WAXED_SIGN_INTERACT_FAIL
    elif id == WaxRemoved.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_WAX_OFF, pos)
        return
    elif id == CopperScraped.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SCRAPE, pos)
        return
    elif id == Pop.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_INFINITY_ARROW_PICKUP, pos)
        return
    elif id == Teleport.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_TELEPORT
    elif id == ItemAdd.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ADD_ITEM, pos)
        return
    elif id == ItemFrameRemove.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ITEM_FRAME_REMOVE_ITEM, pos)
        return
    elif id == ItemFrameRotate.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ITEM_FRAME_ROTATE_ITEM, pos)
        return
    elif id == GhastWarning.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_GHAST_WARNING, pos)
        return
    elif id == GhastShoot.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_GHAST_FIREBALL, pos)
        return
    elif id == TNT.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_FUSE, pos)
        return
    elif id == FireworkLaunch.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_LAUNCH
    elif id == FireworkHugeBlast.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_LARGE_BLAST
    elif id == FireworkBlast.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BLAST
    elif id == FireworkTwinkle.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_TWINKLE
    elif id == FurnaceCrackle.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_FURNACE_USE
    elif id == CampfireCrackle.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_CAMPFIRE_CRACKLE
    elif id == BlastFurnaceCrackle.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BLAST_FURNACE_USE
    elif id == SmokerCrackle.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_SMOKER_USE
    elif id == PotionBrewed.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_POTION_BREWED
    elif id == UseSpyglass.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_USE_SPYGLASS
    elif id == StopUsingSpyglass.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_STOP_USING_SPYGLASS
    elif id == GoatHorn.SOUND_ID:
        pk.sound_type = _goat_call(rebind[GoatHorn](s).horn)
    elif id == FireExtinguish.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_EXTINGUISH_FIRE
    elif id == Ignite.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_IGNITE
    elif id == EnderEyePlaced.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_ENDER_EYE_PLACED
    elif id == EndPortalCreated.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_END_PORTAL_CREATED
    elif id == Burning.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_PLAYER_HURT_ON_FIRE
    elif id == Drowning.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_PLAYER_HURT_DROWN
    elif id == Fall.SOUND_ID:
        pk.entity_type = "minecraft:player"
        if rebind[Fall](s).distance > 4:
            pk.sound_type = lse.SOUND_EVENT_FALL_BIG
        else:
            pk.sound_type = lse.SOUND_EVENT_FALL_SMALL
    elif id == Burp.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BURP
    elif id == DoorOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_DOOR_OPEN
        pk.extra_data = _rid(q, rebind[DoorOpen](s).block)
    elif id == DoorClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_DOOR_CLOSE
        pk.extra_data = _rid(q, rebind[DoorClose](s).block)
    elif id == TrapdoorOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_TRAPDOOR_OPEN
        pk.extra_data = _rid(q, rebind[TrapdoorOpen](s).block)
    elif id == TrapdoorClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_TRAPDOOR_CLOSE
        pk.extra_data = _rid(q, rebind[TrapdoorClose](s).block)
    elif id == FenceGateOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_FENCE_GATE_OPEN
        pk.extra_data = _rid(q, rebind[FenceGateOpen](s).block)
    elif id == FenceGateClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_FENCE_GATE_CLOSE
        pk.extra_data = _rid(q, rebind[FenceGateClose](s).block)
    elif id == Deny.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_DENY
    elif id == BlockPlace.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_PLACE
        pk.extra_data = _rid(q, rebind[BlockPlace](s).block)
    elif id == AnvilLand.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ANVIL_LAND, pos)
        return
    elif id == AnvilUse.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ANVIL_USED, pos)
        return
    elif id == AnvilBreak.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_ANVIL_BROKEN, pos)
        return
    elif id == ChestClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_CHEST_CLOSED
    elif id == ChestOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_CHEST_OPEN
    elif id == EnderChestClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_ENDER_CHEST_CLOSED
    elif id == EnderChestOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_ENDER_CHEST_OPEN
    elif id == BarrelClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BARREL_CLOSE
    elif id == BarrelOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BARREL_OPEN
    elif id == BlockBreaking.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_HIT
        pk.extra_data = _rid(q, rebind[BlockBreaking](s).block)
    elif id == ItemBreak.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BREAK
    elif id == ItemUseOn.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_ITEM_USE_ON
        pk.extra_data = _rid(q, rebind[ItemUseOn](s).block)
    elif id == Fizz.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_FIZZ
    elif id == GlassBreak.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_GLASS
    elif id == Attack.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_ATTACK_STRONG
        pk.entity_type = "minecraft:player"
        if not rebind[Attack](s).damage:
            pk.sound_type = lse.SOUND_EVENT_ATTACK_NO_DAMAGE
    elif id == BucketFill.SOUND_ID:
        if rebind[BucketFill](s).liquid.kind == Water.BASE_HASH:
            pk.sound_type = lse.SOUND_EVENT_BUCKET_FILL_WATER
        else:
            pk.sound_type = lse.SOUND_EVENT_BUCKET_FILL_LAVA
    elif id == BucketEmpty.SOUND_ID:
        if rebind[BucketEmpty](s).liquid.kind == Water.BASE_HASH:
            pk.sound_type = lse.SOUND_EVENT_BUCKET_EMPTY_WATER
        else:
            pk.sound_type = lse.SOUND_EVENT_BUCKET_EMPTY_LAVA
    elif id == BowShoot.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BOW
    elif id == CrossbowLoad.SOUND_ID:
        var so = rebind[CrossbowLoad](s)
        if so.stage == CROSSBOW_LOADING_START:
            pk.sound_type = lse.SOUND_EVENT_CROSSBOW_LOADING_START
            if so.quick_charge:
                pk.sound_type = lse.SOUND_EVENT_CROSSBOW_QUICK_CHARGE_START
        elif so.stage == CROSSBOW_LOADING_MIDDLE:
            pk.sound_type = lse.SOUND_EVENT_CROSSBOW_LOADING_MIDDLE
            if so.quick_charge:
                pk.sound_type = lse.SOUND_EVENT_CROSSBOW_QUICK_CHARGE_MIDDLE
        elif so.stage == CROSSBOW_LOADING_END:
            pk.sound_type = lse.SOUND_EVENT_CROSSBOW_LOADING_END
            if so.quick_charge:
                pk.sound_type = lse.SOUND_EVENT_CROSSBOW_QUICK_CHARGE_END
        else:
            # Go panics on an invalid stage.
            return
    elif id == CrossbowShoot.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_CROSSBOW_SHOOT
    elif id == ArrowHit.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_BOW_HIT
    elif id == ItemThrow.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_THROW
        pk.entity_type = "minecraft:player"
    elif id == LevelUp.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_LEVEL_UP
        pk.extra_data = 0x10000000
    elif id == Experience.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_EXPERIENCE_ORB_PICKUP, pos)
        return
    elif id == MusicDiscPlay.SOUND_ID:
        var record = _record(rebind[MusicDiscPlay](s).disc_type)
        if not record:
            # Go panics on a disc without a sound.
            return
        pk.sound_type = record.value()
    elif id == MusicDiscEnd.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_RECORD_NULL
    elif id == FireCharge.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_BLAZE_FIREBALL, pos)
        return
    elif id == ComposterEmpty.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_COMPOSTER_EMPTY
    elif id == ComposterFill.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_COMPOSTER_FILL
    elif id == ComposterFillLayer.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_COMPOSTER_FILL_LAYER
    elif id == ComposterReady.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_COMPOSTER_READY
    elif id == PowerOn.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_POWER_ON
    elif id == PowerOff.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_POWER_OFF
    elif id == LecternBookPlace.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_LECTERN_BOOK_PLACE
    elif id == Totem.SOUND_ID:
        _level_event(q, le.LEVEL_EVENT_SOUND_TOTEM_USED, pos)
        return
    elif id == ShulkerBoxClose.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_SHULKER_BOX_CLOSED
    elif id == ShulkerBoxOpen.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_SHULKER_BOX_OPEN
    elif id == DecoratedPotInserted.SOUND_ID:
        var progress = rebind[DecoratedPotInserted](s).progress
        _play(
            q,
            "block.decorated_pot.insert",
            pos,
            1,
            0.7 + 0.5 * Float32(progress),
        )
        return
    elif id == DecoratedPotInsertFailed.SOUND_ID:
        pk.sound_type = lse.SOUND_EVENT_DECORATED_POT_INSERT_FAIL
    elif id == Custom.SOUND_ID:
        var so = rebind[Custom](s)
        _play(q, so.name, pos, Float32(so.volume), Float32(so.pitch))
        return
    elif id == LightningExplode.SOUND_ID:
        _play(q, "ambient.weather.lightning.impact", pos, 1, 0.7)
        return
    elif id == LightningThunder.SOUND_ID:
        _play(q, "ambient.weather.thunder", pos, 1, 1.0)
        return
    q.push(pk)


def view_particle[P: Particle](mut q: PacketQueue, pos: Vec3, p: P):
    """Queues the packet that shows a particle at a position (Go
    `ViewParticle`); particles Go does not send are ignored."""
    comptime id = P.PARTICLE_ID
    comptime if id == DragonEggTeleport.PARTICLE_ID:
        var d = rebind[DragonEggTeleport](p).diff
        var sign = 0
        if d.x() < 0:
            sign |= 1 << 24
        if d.y() < 0:
            sign |= 1 << 25
        if d.z() < 0:
            sign |= 1 << 26
        var data = (abs(d.x()) << 16) | (abs(d.y()) << 8) | abs(d.z()) | sign
        _level_event(q, le.LEVEL_EVENT_PARTICLES_DRAGON_EGG, pos, Int32(data))
    elif id == NoteParticle.PARTICLE_ID:
        var n = rebind[NoteParticle](p)
        var pk = BlockEvent()
        var bp = BlockPos()
        bp.x = Int32(pos.x())
        bp.y = Int32(pos.y())
        bp.z = Int32(pos.z())
        pk.position = bp
        pk.event_type = n.instrument.int32()
        pk.event_data = Int32(n.pitch)
        q.push(pk)
    elif id == HugeExplosion.PARTICLE_ID:
        _level_event(q, le.LEVEL_EVENT_PARTICLES_EXPLOSION, pos)
    elif id == BoneMeal.PARTICLE_ID:
        var area = Int32(1) if rebind[BoneMeal](p).area else Int32(0)
        _level_event(q, le.LEVEL_EVENT_PARTICLE_CROP_GROWTH, pos, area)
    elif id == BlockForceField.PARTICLE_ID:
        _level_event(q, le.LEVEL_EVENT_PARTICLE_DENY_BLOCK, pos)
    elif id == BlockBreak.PARTICLE_ID:
        var rid = _rid(q, rebind[BlockBreak](p).block)
        _level_event(q, le.LEVEL_EVENT_PARTICLES_DESTROY_BLOCK, pos, rid)
    elif id == PunchBlock.PARTICLE_ID:
        var pb = rebind[PunchBlock](p)
        var data = _rid(q, pb.block) | (Int32(Int(pb.face)) << 24)
        _level_event(q, le.LEVEL_EVENT_PARTICLES_CRACK_BLOCK, pos, data)
    elif id == EndermanTeleport.PARTICLE_ID:
        _level_event(q, le.LEVEL_EVENT_PARTICLES_TELEPORT, pos)
    elif id == Flame.PARTICLE_ID:
        var c = rebind[Flame](p).colour
        if c != RGBA():
            _level_event(q, _LEGACY | 57, pos, int32_from_rgba(c))
        else:
            _level_event(q, _LEGACY | 8, pos)
    elif id == Evaporate.PARTICLE_ID:
        _level_event(q, le.LEVEL_EVENT_PARTICLES_EVAPORATE_WATER, pos)
    elif id == SnowballPoof.PARTICLE_ID:
        _level_event(q, _LEGACY | 15, pos)
    elif id == EggSmash.PARTICLE_ID:
        if case .Some(r) = q.items[].item_runtime_id(Egg()):
            var data = (r.runtime_id << 16) | Int32(r.meta)
            _level_event(q, _LEGACY | 14, pos, data)
    elif id == Splash.PARTICLE_ID:
        var c = rebind[Splash](p).colour
        if c == RGBA():
            c = resulting_colour(List[EntityEffect]())[0]
        _level_event(q, le.LEVEL_EVENT_PARTICLES_POTION_SPLASH, pos, _argb(c))
    elif id == Effect.PARTICLE_ID:
        _level_event(q, _LEGACY | 34, pos, _argb(rebind[Effect](p).colour))
    elif id == EntityFlame.PARTICLE_ID:
        _level_event(q, _LEGACY | 19, pos)
    elif id == Dust.PARTICLE_ID:
        var c = rebind[Dust](p).colour
        _level_event(q, _LEGACY | 33, pos, int32_from_rgba(c))
    elif id == WaterDrip.PARTICLE_ID:
        _level_event(q, _LEGACY | 28, pos)
    elif id == LavaDrip.PARTICLE_ID:
        _level_event(q, _LEGACY | 29, pos)
    elif id == Lava.PARTICLE_ID:
        _level_event(q, _LEGACY | 10, pos)
    elif id == DustPlume.PARTICLE_ID:
        _level_event(q, _LEGACY | 88, pos)


comptime _LEGACY = le.LEVEL_EVENT_PARTICLE_LEGACY_EVENT


def _record(d: DiscType) -> Optional[String]:
    if d == DiscType.DISC_13:
        return String(lse.SOUND_EVENT_RECORD13)
    if d == DiscType.CAT:
        return String(lse.SOUND_EVENT_RECORD_CAT)
    if d == DiscType.BLOCKS:
        return String(lse.SOUND_EVENT_RECORD_BLOCKS)
    if d == DiscType.CHIRP:
        return String(lse.SOUND_EVENT_RECORD_CHIRP)
    if d == DiscType.FAR:
        return String(lse.SOUND_EVENT_RECORD_FAR)
    if d == DiscType.MALL:
        return String(lse.SOUND_EVENT_RECORD_MALL)
    if d == DiscType.MELLOHI:
        return String(lse.SOUND_EVENT_RECORD_MELLOHI)
    if d == DiscType.STAL:
        return String(lse.SOUND_EVENT_RECORD_STAL)
    if d == DiscType.STRAD:
        return String(lse.SOUND_EVENT_RECORD_STRAD)
    if d == DiscType.WARD:
        return String(lse.SOUND_EVENT_RECORD_WARD)
    if d == DiscType.DISC_11:
        return String(lse.SOUND_EVENT_RECORD11)
    if d == DiscType.WAIT:
        return String(lse.SOUND_EVENT_RECORD_WAIT)
    if d == DiscType.OTHERSIDE:
        return String(lse.SOUND_EVENT_RECORD_OTHERSIDE)
    if d == DiscType.PIGSTEP:
        return String(lse.SOUND_EVENT_RECORD_PIGSTEP)
    if d == DiscType.DISC_5:
        return String(lse.SOUND_EVENT_RECORD5)
    if d == DiscType.RELIC:
        return String(lse.SOUND_EVENT_RECORD_RELIC)
    if d == DiscType.CREATOR:
        return String(lse.SOUND_EVENT_RECORD_CREATOR)
    if d == DiscType.CREATOR_MUSIC_BOX:
        return String(lse.SOUND_EVENT_RECORD_CREATOR_MUSIC_BOX)
    if d == DiscType.PRECIPICE:
        return String(lse.SOUND_EVENT_RECORD_PRECIPICE)
    if d == DiscType.TEARS:
        return String(lse.SOUND_EVENT_RECORD_TEARS)
    if d == DiscType.LAVA_CHICKEN:
        return String(lse.SOUND_EVENT_RECORD_LAVA_CHICKEN)
    return None


def _goat_call(h: Horn) -> String:
    if h == Horn.PONDER:
        return lse.SOUND_EVENT_GOAT_CALL0
    if h == Horn.SING:
        return lse.SOUND_EVENT_GOAT_CALL1
    if h == Horn.SEEK:
        return lse.SOUND_EVENT_GOAT_CALL2
    if h == Horn.FEEL:
        return lse.SOUND_EVENT_GOAT_CALL3
    if h == Horn.ADMIRE:
        return lse.SOUND_EVENT_GOAT_CALL4
    if h == Horn.CALL:
        return lse.SOUND_EVENT_GOAT_CALL5
    if h == Horn.YEARN:
        return lse.SOUND_EVENT_GOAT_CALL6
    if h == Horn.DREAM:
        return lse.SOUND_EVENT_GOAT_CALL7
    return String()


def _rid(q: PacketQueue, b: AnyBlock) -> Int32:
    # Go `int32(s.br.BlockRuntimeID(b))`; unknown blocks are air.
    if case .Some(r) = q.blocks[].runtime_id_of(b.kind, b.state):
        return Int32(r)
    return Int32(q.blocks[].air_runtime_id())


def _argb(c: RGBA) -> Int32:
    return (
        (Int32(c.a) << 24) | (Int32(c.r) << 16) | (Int32(c.g) << 8) | Int32(c.b)
    )


def _level_event(mut q: PacketQueue, event: Int32, pos: Vec3, data: Int32 = 0):
    var pk = LevelEvent()
    pk.event_type = event
    pk.position = _vec32(pos)
    pk.event_data = data
    q.push(pk)


def _play(
    mut q: PacketQueue, name: String, pos: Vec3, volume: Float32, pitch: Float32
):
    var pk = PlaySound()
    pk.sound_name = name
    pk.position = _vec32(pos)
    pk.volume = volume
    pk.pitch = pitch
    q.push(pk)


def _vec32(v: Vec3) -> ProtocolVec3:
    return ProtocolVec3(Float32(v.x()), Float32(v.y()), Float32(v.z()))
