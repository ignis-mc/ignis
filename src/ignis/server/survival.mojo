"""Health, hunger, effects, falling, death and respawning of the players,
ported from Dragonfly `server/player/player.go` (`Tick`, `Move`,
`checkOnGround`, `checkEntityInsiders`, `checkEntitySteppers`,
`insideOfWater`, `insideOfSolid`, `Hurt`, `KnockBack`, `damageItem`,
`kill`, `dropItems`, `finishDying`, `respawn`) and the `EntityInside` and
`EntityStepOn` methods of the blocks that hurt.

The survival state itself is `player.living.Living`; these functions give
it the world facts it needs and show its `LivingEvent`s: the player's own
session gets attributes, effects and its respawn, and every session sees
hurt and death animations, metadata and knock-back. Go's viewers include
the player itself, so the actor events go to its own session too.

Dragonfly has no death messages (servers add them in a handler); Ignis
broadcasts the vanilla `death.attack.*` translations.
"""

from std.math import floor

from minecraft.protocol.packet.actor_event import (
    ACTOR_EVENT_DEATH,
    ACTOR_EVENT_HURT,
    ACTOR_EVENT_TALISMAN_ACTIVATE,
)
from minecraft.protocol.uuid import UUID
from nethernet.os.time import monotonic_ms

from ..block.cactus import Cactus
from ..block.campfire import Campfire
from ..block.cobweb import Cobweb
from ..block.cube.bbox import BBox
from ..block.cube.pos import Pos, pos_from_vec3
from ..block.fire import Fire
from ..block.fire_type import FireType
from ..block.flower import Flower
from ..block.flower_type import FlowerType
from ..block.hash import AnyBlock
from ..block.lava import Lava
from ..block.magma import Magma
from ..block.model.solid import Solid
from ..block.register import block_model_as, block_model_bbox
from ..block.tinted_glass import TintedGlass
from ..block.water import Water
from ..entity.damage import (
    DAMAGE_ATTACK,
    DAMAGE_BLOCK,
    DAMAGE_DROWNING,
    DAMAGE_EXPLOSION,
    DAMAGE_FALL,
    DAMAGE_FIRE,
    DAMAGE_GLIDE,
    DAMAGE_INSTANT,
    DAMAGE_LAVA,
    DAMAGE_LIGHTNING,
    DAMAGE_MAGMA,
    DAMAGE_POISON,
    DAMAGE_PROJECTILE,
    DAMAGE_STARVATION,
    DAMAGE_SUFFOCATION,
    DAMAGE_THORNS,
    DAMAGE_VOID,
    DAMAGE_WITHER,
    AnyDamageSource,
)
from ..entity.effect import SECOND, Effect, new
from ..entity.effect.wither import Wither
from ..entity.experience_orb import spawn_experience_orbs
from ..item.enchantment import (
    CURSE_OF_VANISHING_ID,
    RESPIRATION_ID,
    UNBREAKING_ID,
)
from ..item.register import VanillaItems
from ..item.stack import Stack
from ..item.totem import Totem
from ..mgl64 import EPSILON, Vec3
from ..player.living import (
    EVENT_DEATH,
    EVENT_EFFECT,
    EVENT_EFFECT_REMOVED,
    EVENT_EXPERIENCE,
    EVENT_FOOD,
    EVENT_HEALTH,
    EVENT_HURT,
    EVENT_KNOCK_BACK,
    EVENT_SOUND_BURNING,
    EVENT_SOUND_DROWNING,
    EVENT_STATE,
    EVENT_STOP_SPRINTING,
    EVENT_TOTEM,
    SurvivalContext,
)
from ..player.player import BBOX_HEIGHT, BBOX_WIDTH, EYE_HEIGHT
from ..world.game_mode import GAME_MODE_SPECTATOR
from ..world.sound.entity import Burning, Drowning
from ..world.sound.item import ItemBreak
from ..world.sound.item import Totem as TotemSound
from .server import DyingPlayer, Server

comptime DEATH_DELAY_MS = 1100
"""How long a dead player lies before Go's `finishDying`."""

comptime _BREATHING_DISTANCE_BELOW_EYES = 0.11111111
"""Go `breathingDistanceBelowEyes`."""


def player_bbox(pos: Vec3) -> BBox:
    """Returns a player's box at a position (Go `Type.BBox` translated)."""
    return BBox.box(
        -BBOX_WIDTH / 2,
        0,
        -BBOX_WIDTH / 2,
        BBOX_WIDTH / 2,
        BBOX_HEIGHT,
        BBOX_WIDTH / 2,
    ).translate(pos)


# ===----------------------------------------------------------------------=== #
# World facts
# ===----------------------------------------------------------------------=== #


def _block(mut srv: Server, pos: Pos) -> AnyBlock:
    var rid = srv.world.block(pos)
    var br = srv.world.block_registry()
    return AnyBlock(kind=br[].kind(rid), state=br[].state_hash(rid))


def _block_boxes(mut srv: Server, pos: Pos) -> List[BBox]:
    var b = _block(srv, pos)
    return block_model_bbox(b, pos, srv.world.source())


def raining_at(mut srv: Server, pos: Pos) -> Bool:
    """Go `Tx.RainingAt`."""
    if not srv.world.raining():
        return False
    var b = srv.biomes.by_id(srv.world.biome(pos))
    if not b:
        return False
    # Go `temperature`: 1/600 colder per block above sea level.
    var t = b.value().temperature - Float64(max(pos.y() - 64, 0)) / 600
    if b.value().rainfall == 0 or t <= 0.15:
        return False
    return srv.world.highest_obstructing_block(pos.x(), pos.z()) < pos.y()


def inside_of_water(mut srv: Server, i: Int) -> Bool:
    """Go `insideOfWater`."""
    var feet = srv.sessions[i].player.position()
    var pos = pos_from_vec3(feet.add(Vec3(0, EYE_HEIGHT, 0)))
    var l = srv.world.liquid(pos)
    if not l:
        return False
    var br = srv.world.block_registry()
    if case .Some(w) = br[].block[Water](l.value()):
        var d = Float64(w.spread_decay()) + 1
        if w.liquid_falling():
            d = 1
        return feet.y() < Float64(pos.y() + 1) - (
            d / 9 - _BREATHING_DISTANCE_BELOW_EYES
        )
    return False


def eyes_in_liquid(mut srv: Server, i: Int) -> Bool:
    """Reports whether a liquid is at the eyes (the `submerged` of Go
    `Breathing` and `Move`)."""
    var eyes = srv.sessions[i].player.eye_position()
    return Bool(srv.world.liquid(pos_from_vec3(eyes)))


def inside_of_solid(mut srv: Server, i: Int) -> Bool:
    """Go `insideOfSolid`."""
    var feet = srv.sessions[i].player.position()
    var pos = pos_from_vec3(feet.add(Vec3(0, EYE_HEIGHT, 0)))
    var b = _block(srv, pos)
    if not block_model_as[Solid](b):
        return False
    var rid = srv.world.block(pos)
    var br = srv.world.block_registry()
    # Go's `LightDiffuser` with level 0: transparent.
    if br[].filtering_block(rid) == 0:
        return False
    if br[].is_block[TintedGlass](rid):
        return False  # Go `NonSuffocating`.
    var box = player_bbox(feet)
    for bb in _block_boxes(srv, pos):
        if bb.translate(pos.vec3()).intersects_with(box):
            return True
    return False


def check_on_ground(mut srv: Server, i: Int, delta: Vec3) -> Bool:
    """Go `checkOnGround`."""
    var box = (
        player_bbox(srv.sessions[i].player.position())
        .extend(Vec3(0, -0.05, 0))
        .extend(delta.mul(-1.0))
    )
    var b = box.grow(1)
    var eps = Vec3(EPSILON, EPSILON, EPSILON)
    var low = pos_from_vec3(b.min().add(eps))
    var high = pos_from_vec3(b.max().sub(eps))
    for x in range(low.x(), high.x() + 1):
        for z in range(low.z(), high.z() + 1):
            for y in range(low.y(), high.y()):
                var pos = Pos(x, y, z)
                for bb in _block_boxes(srv, pos):
                    if bb.translate(pos.vec3()).intersects_with(box):
                        return True
    return False


def survival_context(mut srv: Server, i: Int) -> SurvivalContext:
    """Collects what a player's survival code needs to know about its
    world."""
    var ctx = SurvivalContext()
    ref p = srv.sessions[i].player
    var pos = p.position()
    var mode = p.game_mode()
    var d = srv.world.difficulty()
    ctx.now_ms = monotonic_ms()
    ctx.takes_damage = mode.allows_taking_damage()
    ctx.food_regenerates = d.food_regenerates()
    ctx.starvation_health_limit = d.starvation_health_limit()
    ctx.below_world = pos.y() < Float64(srv.world.range().min())
    var held = srv.sessions[i].invs.held_item()
    var off = srv.sessions[i].invs.off_hand_item()
    ctx.totem_held = Bool(held.item_as[Totem]()) or Bool(off.item_as[Totem]())
    var solid = inside_of_solid(srv, i)
    ctx.inside_solid = solid
    ctx.can_breathe = not inside_of_water(srv, i) and not solid
    ctx.raining = raining_at(srv, pos_from_vec3(pos))
    if not ctx.can_breathe:
        var helmet = srv.sessions[i].invs.armour.helmet()
        if case .Some(r) = helmet.enchantment(Int16(RESPIRATION_ID)):
            var chance = Float64(r.level) / Float64(r.level + 1)
            ctx.respiration_saves = srv.world.global_rand().float64() < chance
    return ctx^


# ===----------------------------------------------------------------------=== #
# Ticking and moving
# ===----------------------------------------------------------------------=== #


def tick_survival(mut srv: Server, i: Int):
    """The survival part of Go `Player.Tick`: blocks the player is in or
    stands on, then effects, food, air, the void, suffocation and fire."""
    if srv.sessions[i].player.living.dead():
        return
    check_entity_insiders(srv, i)
    flush_living(srv, i)
    if srv.sessions[i].player.living.dead():
        return
    var on_ground = check_on_ground(srv, i, Vec3())
    srv.sessions[i].player.set_on_ground(on_ground)
    check_entity_steppers(srv, i)
    var ctx = survival_context(srv, i)
    srv.sessions[i].player.living.eyes_in_liquid = eyes_in_liquid(srv, i)
    srv.sessions[i].player.living.tick(srv.sessions[i].invs.armour, ctx)
    after_hurt(srv, i, ctx)
    flush_living(srv, i)


def handle_movement(mut srv: Server, i: Int, delta: Vec3, moved: Bool):
    """The parts of Go `Move` after the position changed: block contacts,
    breathing, the ground and the fall, and sprint exhaustion. `moved` is
    False if the player was dead or did not move."""
    if not moved:
        var ctx = survival_context(srv, i)
        srv.sessions[i].player.living.update_fall_state(
            delta.y(), True, srv.sessions[i].invs.armour, ctx
        )
        after_hurt(srv, i, ctx)
        flush_living(srv, i)
        return
    if delta.len() <= 3:
        check_entity_insiders(srv, i)
    var was = srv.sessions[i].player.living.eyes_in_liquid
    var now = eyes_in_liquid(srv, i)
    srv.sessions[i].player.living.eyes_in_liquid = now
    if was != now:
        srv.sessions[i].view_entity_state(srv.sessions[i].player.copy())
    var on_ground = check_on_ground(srv, i, delta)
    srv.sessions[i].player.set_on_ground(on_ground)
    var ctx = survival_context(srv, i)
    srv.sessions[i].player.living.update_fall_state(
        delta.y(), on_ground, srv.sessions[i].invs.armour, ctx
    )
    var horizontal = Vec3(delta.x(), 0, delta.z())
    if srv.sessions[i].player.sprinting():
        srv.sessions[i].player.living.exhaust(0.1 * horizontal.len(), ctx)
    after_hurt(srv, i, ctx)
    flush_living(srv, i)


def check_entity_insiders(mut srv: Server, i: Int):
    """Go `checkEntityInsiders` with the `EntityInside` methods of fire,
    soul fire, campfires, lava, water, cobwebs, cactus and wither roses."""
    ref p = srv.sessions[i].player
    if p.game_mode() == GAME_MODE_SPECTATOR:
        return
    var box = player_bbox(p.position()).grow(-0.0001)
    var low = pos_from_vec3(box.min())
    var high = pos_from_vec3(box.max())
    for y in range(low.y(), high.y() + 1):
        for x in range(low.x(), high.x() + 1):
            for z in range(low.z(), high.z() + 1):
                var pos = Pos(x, y, z)
                var rid = srv.world.block(pos)
                var br = srv.world.block_registry()
                var is_liquid = br[].liquid_block(rid)
                _entity_inside(srv, i, pos, rid)
                if is_liquid:
                    continue
                if case .Some(l) = srv.world.liquid(pos):
                    if l != rid:
                        _entity_inside(srv, i, pos, l)


def _entity_inside(mut srv: Server, i: Int, pos: Pos, rid: UInt32):
    var br = srv.world.block_registry()
    if case .Some(f) = br[].block[Fire](rid):
        _ = hurt_player(
            srv, i, _fire_damage(f.type), AnyDamageSource(DAMAGE_FIRE)
        )
        if srv.sessions[i].player.living.fire_ticks * 50 < 8000:
            set_player_on_fire(srv, i, 8000)
    elif case .Some(c) = br[].block[Campfire](rid):
        var camp = c.copy()
        if srv.sessions[i].player.living.fire_ticks > 0 and camp.extinguished:
            camp.extinguished = False
            srv.world.set_block(pos, camp)
        if not camp.extinguished:
            _ = hurt_player(
                srv, i, _fire_damage(camp.type), AnyDamageSource(DAMAGE_FIRE)
            )
    elif br[].is_block[Lava](rid):
        srv.sessions[i].player.living.fall_distance = 0
        _ = hurt_player(srv, i, 4, AnyDamageSource(DAMAGE_LAVA))
        set_player_on_fire(srv, i, 15000)
    elif br[].is_block[Water](rid):
        srv.sessions[i].player.living.fall_distance = 0
        set_player_on_fire(srv, i, 0)
    elif br[].is_block[Cobweb](rid):
        # Go also slows the velocity, which a client moves itself.
        srv.sessions[i].player.living.fall_distance = 0
    elif br[].is_block[Cactus](rid):
        var src = AnyDamageSource(DAMAGE_BLOCK)
        src.block = AnyBlock(kind=br[].kind(rid), state=br[].state_hash(rid))
        _ = hurt_player(srv, i, 0.5, src)
    elif case .Some(f) = br[].block[Flower](rid):
        if f.type == FlowerType.WITHER_ROSE:
            add_player_effect(srv, i, new(Wither(), 1, 2 * SECOND))


def _fire_damage(t: FireType) -> Float64:
    # Go `FireType.Damage`.
    if t == FireType.SOUL:
        return 2
    return 1


def check_entity_steppers(mut srv: Server, i: Int):
    """Go `checkEntitySteppers` with magma's `EntityStepOn`."""
    ref p = srv.sessions[i].player
    if not p.on_ground() or p.game_mode() == GAME_MODE_SPECTATOR:
        return
    # Go `blocksUnder`.
    var box = player_bbox(p.position())
    var y = Int(floor(box.min().y() - 0.0001))
    var horizontal = box.grow(-0.0001)
    var low = pos_from_vec3(horizontal.min())
    var high = pos_from_vec3(horizontal.max())
    var sneaking = p.sneaking()
    for x in range(low.x(), high.x() + 1):
        for z in range(low.z(), high.z() + 1):
            var pos = Pos(x, y, z)
            var rid = srv.world.block(pos)
            var br = srv.world.block_registry()
            if br[].is_block[Magma](rid):
                if not sneaking:
                    _ = hurt_player(srv, i, 1, AnyDamageSource(DAMAGE_MAGMA))
                return
            # Other Dragonfly steppers (redstone ore) do not hurt.


# ===----------------------------------------------------------------------=== #
# Hurting
# ===----------------------------------------------------------------------=== #


def hurt_player(
    mut srv: Server, i: Int, dmg: Float64, src: AnyDamageSource
) -> Tuple[Float64, Bool]:
    """Hurts a player (Go `Player.Hurt`), damaging its armour, taking a
    totem that saves it and showing the result. Returns the damage dealt
    and whether the player was vulnerable."""
    var ctx = survival_context(srv, i)
    var res = srv.sessions[i].player.living.hurt(
        dmg, src, srv.sessions[i].invs.armour, ctx
    )
    if res[1] and src.reduced_by_armour():
        # Go `Armour().Damage(dmg, p.damageItem)`.
        var d = Int(max(floor(dmg / 4), 1))
        for slot in range(4):
            var it = srv.sessions[i].invs.armour._get(slot)
            var damaged = damage_item(srv, i, it, d)
            try:
                srv.sessions[i].invs.armour.inv.set_item(slot, damaged)
            except:
                pass
        # Thorns needs a living attacker: see `combat.mojo`.
    after_hurt(srv, i, ctx)
    flush_living(srv, i)
    return res


def after_hurt(mut srv: Server, i: Int, ctx: SurvivalContext):
    """Takes the totem a hurt used (Go `SetHeldItems` in `Hurt`): the one
    in the off hand first."""
    var used = False
    for e in srv.sessions[i].player.living.events:
        if e.kind == EVENT_TOTEM:
            used = True
    if not used:
        return
    var off = srv.sessions[i].invs.off_hand_item()
    if off.item_as[Totem]():
        try:
            srv.sessions[i].invs.off_hand.set_item(0, off.grow(-1))
        except:
            pass
        return
    var held = srv.sessions[i].invs.held_item()
    if held.item_as[Totem]():
        srv.sessions[i].invs.set_held_item(held.grow(-1))


def damage_item(mut srv: Server, i: Int, s: Stack, d_in: Int) -> Stack:
    """Go `damageItem`: Unbreaking may spare the damage; breaking plays a
    sound. Creative players' items are not damaged."""
    var mode = srv.sessions[i].player.game_mode()
    if mode.creative_inventory() or d_in == 0 or s.durability() == -1:
        return s.copy()
    var d = d_in
    if case .Some(e) = s.enchantment(Int16(UNBREAKING_ID)):
        # Go `Unbreaking.Reduce`, on its global source.
        var armour = False
        if case .Some(it) = s.item():
            armour = Bool(VanillaItems.armour_slot(it.kind, it.hash))
        var after = d
        for _ in range(d):
            ref r = srv.world.global_rand()
            if (not armour or r.float64() >= 0.6) and r.int_n(e.level + 1) > 0:
                after -= 1
        d = after
    var out = s.damage(d)
    if out.empty():
        srv.world.play_sound(srv.sessions[i].player.position(), ItemBreak())
    return out^


def knock_back_player(
    mut srv: Server, i: Int, src: Vec3, force: Float64, height: Float64
):
    """Go `Player.KnockBack`."""
    ref p = srv.sessions[i].player
    if p.living.dead() or not p.game_mode().allows_taking_damage():
        return
    var pos = p.position()
    var res = srv.sessions[i].invs.armour.knock_back_resistance()
    srv.sessions[i].player.living.knock_back(pos, src, force, height, res)
    flush_living(srv, i)


def explode_player(
    mut srv: Server, i: Int, pos: Vec3, size: Float64, impact: Float64
):
    """Go `Player.Explode`: damage from the impact, then knock-back without
    the game mode check."""
    var diff = srv.sessions[i].player.position().sub(pos)
    _ = hurt_player(
        srv,
        i,
        floor((impact * impact + impact) * 3.5 * size * 2 + 1),
        AnyDamageSource.explosion(pos, size),
    )
    var res = srv.sessions[i].invs.armour.knock_back_resistance()
    var p = srv.sessions[i].player.position()
    srv.sessions[i].player.living.knock_back(
        p, pos, impact, diff.y() / diff.len() * impact, res
    )
    flush_living(srv, i)


def set_player_on_fire(mut srv: Server, i: Int, duration_ms: Int):
    """Go `SetOnFire`."""
    srv.sessions[i].player.living.set_on_fire(duration_ms)
    flush_living(srv, i)


def add_player_effect(mut srv: Server, i: Int, e: Effect):
    """Go `AddEffect`."""
    var ctx = survival_context(srv, i)
    srv.sessions[i].player.living.add_effect(e, ctx)
    after_hurt(srv, i, ctx)
    flush_living(srv, i)


# ===----------------------------------------------------------------------=== #
# Showing what happened
# ===----------------------------------------------------------------------=== #


def flush_living(mut srv: Server, i: Int):
    """Shows a player's `LivingEvent`s: attributes and effects to its own
    session, animations, state, sounds and knock-back to every session,
    and runs the death if it died."""
    var health = False
    var food = False
    var experience = False
    var state = False
    var died = False
    while True:
        var events = srv.sessions[i].player.living.take_events()
        if len(events) == 0:
            break
        var p = srv.sessions[i].player.copy()
        var pos = p.position()
        for e in events:
            if e.kind == EVENT_HEALTH:
                health = True
            elif e.kind == EVENT_FOOD:
                food = True
            elif e.kind == EVENT_EXPERIENCE:
                experience = True
            elif e.kind == EVENT_STATE:
                state = True
            elif e.kind == EVENT_EFFECT:
                srv.sessions[i].send_effect(e.effect.value())
            elif e.kind == EVENT_EFFECT_REMOVED:
                srv.sessions[i].send_effect_removal(e.effect.value().type_id())
            elif e.kind == EVENT_HURT:
                for j in range(len(srv.sessions)):
                    srv.sessions[j].view_entity_event(p, ACTOR_EVENT_HURT)
            elif e.kind == EVENT_DEATH:
                died = True
            elif e.kind == EVENT_SOUND_BURNING:
                srv.world.play_sound(pos, Burning())
            elif e.kind == EVENT_SOUND_DROWNING:
                srv.world.play_sound(pos, Drowning())
            elif e.kind == EVENT_STOP_SPRINTING:
                if srv.sessions[i].player.sprinting():
                    srv.sessions[i].player.set_sprinting(False)
                    state = True
            elif e.kind == EVENT_KNOCK_BACK:
                for j in range(len(srv.sessions)):
                    srv.sessions[j].view_entity_velocity(p, e.vel)
            elif e.kind == EVENT_TOTEM:
                srv.world.play_sound(pos, TotemSound())
                for j in range(len(srv.sessions)):
                    srv.sessions[j].view_entity_event(
                        p, ACTOR_EVENT_TALISMAN_ACTIVATE
                    )
        if died:
            died = False
            kill_player(srv, i)
    ref l = srv.sessions[i].player.living
    if health:
        var h = l.health.health
        var m = l.health.max
        var a = l.absorption
        srv.sessions[i].send_health(h, m, a)
    if food:
        var f = l.hunger.food_level
        var s = l.hunger.saturation_level
        var x = l.hunger.exhaustion_level
        srv.sessions[i].send_food(f, s, x)
    if experience:
        var lvl = l.experience.level()
        var prog = l.experience.progress()
        srv.sessions[i].send_experience(lvl, prog)
    if state:
        var p = srv.sessions[i].player.copy()
        for j in range(len(srv.sessions)):
            srv.sessions[j].view_entity_state(p)


# ===----------------------------------------------------------------------=== #
# Death and respawning
# ===----------------------------------------------------------------------=== #


def death_message_key(src: AnyDamageSource) -> StaticString:
    """Returns the vanilla death message of a damage source."""
    if src.kind == DAMAGE_ATTACK:
        return "death.attack.player"
    if src.kind == DAMAGE_PROJECTILE:
        return "death.attack.arrow"
    if src.kind == DAMAGE_VOID:
        return "death.attack.outOfWorld"
    if src.kind == DAMAGE_SUFFOCATION:
        return "death.attack.inWall"
    if src.kind == DAMAGE_DROWNING:
        return "death.attack.drown"
    if src.kind == DAMAGE_FALL:
        return "death.attack.fall"
    if src.kind == DAMAGE_GLIDE:
        return "death.attack.flyIntoWall"
    if src.kind == DAMAGE_LIGHTNING:
        return "death.attack.lightningBolt"
    if src.kind == DAMAGE_EXPLOSION:
        return "death.attack.explosion"
    if src.kind == DAMAGE_STARVATION:
        return "death.attack.starve"
    if src.kind == DAMAGE_FIRE:
        return "death.attack.onFire"
    if src.kind == DAMAGE_LAVA:
        return "death.attack.lava"
    if src.kind == DAMAGE_MAGMA:
        return "death.attack.magma"
    if src.kind == DAMAGE_BLOCK:
        return "death.attack.cactus"
    if src.kind == DAMAGE_INSTANT or src.kind == DAMAGE_POISON:
        return "death.attack.magic"
    if src.kind == DAMAGE_WITHER:
        return "death.attack.wither"
    if src.kind == DAMAGE_THORNS:
        return "death.attack.thorns"
    return "death.attack.generic"


def kill_player(mut srv: Server, i: Int):
    """Go `kill`: the death animation, the drops, the effects removed and
    the death position, then `finishDying` after 1.1 seconds."""
    var p = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        srv.sessions[j].view_entity_event(p, ACTOR_EVENT_DEATH)
    var src = srv.sessions[i].player.living.last_source
    var args = List[String]()
    args.append(p.name())
    if src.kind == DAMAGE_ATTACK or src.kind == DAMAGE_PROJECTILE:
        if case .Some(k) = srv.session_index(src.attacker):
            args.append(srv.sessions[k].player.name())
    var key = death_message_key(src)
    if len(args) == 1 and (
        src.kind == DAMAGE_ATTACK or src.kind == DAMAGE_PROJECTILE
    ):
        key = "death.attack.generic"
    print(t"{p.name()} died: {key}")
    for j in range(len(srv.sessions)):
        srv.sessions[j].send_translation(String(key), args.copy())
    var was_sprinting = p.sprinting()
    var was_sneaking = p.sneaking()
    srv.sessions[i].player.set_sneaking(False)
    srv.sessions[i].player.set_sprinting(False)
    var pos = p.position()
    if p.game_mode() != GAME_MODE_SPECTATOR:
        drop_player_items(srv, i)
    srv.sessions[i].player.living.kill(pos)
    if was_sprinting or was_sneaking:
        srv.sessions[i].player.living.push_event(EVENT_STATE)
    srv.dying.append(DyingPlayer(p.uuid(), monotonic_ms() + DEATH_DELAY_MS))


def drop_player_items(mut srv: Server, i: Int):
    """Go `dropItems`: experience orbs worth up to 100 points, then every
    item but those cursed with vanishing, thrown in random directions."""
    var pos = srv.sessions[i].player.position()
    var level = srv.sessions[i].player.living.experience.level()
    spawn_experience_orbs(srv.world, pos, min(level * 7, 100))
    srv.sessions[i].player.living.experience.reset()
    srv.sessions[i].player.living.push_event(EVENT_EXPERIENCE)
    # Go `MoveItemsToInventory`.
    for it in srv.sessions[i].invs.ui.clear():
        var n = srv.sessions[i].invs.inv.add_item(it.copy())
        if n < it.count():
            srv.drop_item(i, it.grow(-n))
    var items = srv.sessions[i].invs.inv.clear()
    items.extend(srv.sessions[i].invs.armour.inv.clear())
    items.extend(srv.sessions[i].invs.off_hand.clear())
    for it in items:
        if it.enchantment(Int16(CURSE_OF_VANISHING_ID)):
            continue
        ref r = srv.world.global_rand()
        var x = r.float64() * 0.2 - 0.1
        var z = r.float64() * 0.2 - 0.1
        srv.spawn_item(pos, Vec3(x, 0.2, z), it)


def finish_dying(mut srv: Server, now: Int):
    """Go `finishDying` for the players whose death delay ran out: still
    dead, they turn invisible and are moved to the spawn server-side, so
    that leaving does not save the death position."""
    var k = 0
    while k < len(srv.dying):
        if srv.dying[k].at_ms > now:
            k += 1
            continue
        var d = srv.dying.pop(k)
        if case .Some(i) = srv.session_index(d.uuid):
            if srv.sessions[i].player.living.dead():
                srv.sessions[i].player.living.set_invisible()
                var spawn = srv.world.spawn()
                srv.sessions[i].player.teleport(spawn.vec3())
                flush_living(srv, i)


def respawn_player(mut srv: Server, i: Int):
    """Go `respawn`: health, food and fire reset, the player back at the
    world spawn, shown to everyone again."""
    if not srv.sessions[i].player.living.dead():
        return
    var pos = srv.world.spawn().vec3_middle()
    srv.sessions[i].player.living.respawn()
    # Go removes the entity from the world and adds it again.
    var old = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        if j != i:
            srv.sessions[j].hide_entity(old)
    srv.sessions[i].player.teleport(pos)
    var p = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        srv.sessions[j].view_entity_teleport(p, pos)
    srv.sessions[i].send_respawn(pos)
    if srv.sessions[i].player.game_mode().visible():
        srv.sessions[i].player.living.set_visible()
    var held = srv.sessions[i].invs.held_item()
    var off = srv.sessions[i].invs.off_hand_item()
    var shown = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        if j != i:
            srv.sessions[j].view_entity(shown, held)
            srv.sessions[j].view_entity_items(shown, held, off)
    flush_living(srv, i)
