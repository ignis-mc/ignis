"""Using items in the air and attacking, ported from Dragonfly
`server/player/player.go` (`UseItem`, `ReleaseItem`, `canRelease`,
`handleUseContext`, `useContext`, `useDuration`, `addNewItem`,
`subtractItem`, `HasCooldown`, `SetCooldown`, `AttackEntity`, the eating
particles of `Tick`) with the `Use`, `Release` and `Consume` methods of the
items that have them: snowballs, eggs, ender pearls, splash and lingering
potions, bottles o' enchanting, armour, bows, food, potions and milk.

Go's use durations and cooldowns are wall-clock time; here they are the
loop's monotonic clock. Dragonfly has no attack cooldown and no sweeping.
Crossbows (`Chargeable`) are not ported yet.
"""

from minecraft.protocol.packet.animate import (
    ANIMATE_ACTION_CRITICAL_HIT,
    ANIMATE_ACTION_MAGIC_CRITICAL_HIT,
)
from nethernet.os.time import monotonic_ms

from ..entity.arrow import ArrowSpawnConfig, spawn_arrow
from ..entity.damage import DAMAGE_ATTACK, AnyDamageSource
from ..block.cube.rotation import Rotation
from ..entity.effect.absorption import Absorption
from ..entity.effect.blindness import Blindness
from ..entity.effect.slow_falling import SlowFalling
from ..entity.effect.strength import Strength
from ..entity.effect.weakness import Weakness
from ..entity.throw import (
    throw_bottle_of_enchanting,
    throw_egg,
    throw_ender_pearl,
    throw_lingering_potion,
    throw_snowball,
    throw_splash_potion,
)
from ..item.arrow import Arrow as ArrowItem
from ..item.bottle_of_enchanting import BottleOfEnchanting
from ..item.bow import Bow
from ..item.bucket import Bucket
from ..item.egg import Egg
from ..item.enchantment import (
    FIRE_ASPECT_ID,
    FLAME_ID,
    INFINITY_ID,
    KNOCKBACK_ID,
    POWER_ID,
    PUNCH_ID,
    SHARPNESS_ID,
)
from ..item.enchantment.fire_aspect import FireAspect
from ..item.enchantment.knockback import Knockback
from ..item.enchantment.power import Power
from ..item.enchantment.sharpness import Sharpness
from ..item.ender_pearl import EnderPearl
from ..item.golden_apple import GoldenApple
from ..item.item import ConsumeInfo
from ..item.lingering_potion import LingeringPotion
from ..item.register import VanillaItems
from ..item.snowball import Snowball
from ..item.splash_potion import SplashPotion
from ..item.stack import Stack
from ..mgl64 import Vec3, float_equal
from ..player.player import EYE_HEIGHT
from ..world.game_mode import GAME_MODE_SPECTATOR
from ..world.sound.entity import Attack, Burp
from ..world.sound.item import BowShoot, EquipItem, ItemThrow
from .interact import swing_arm
from .server import Server
from .survival import (
    add_player_effect,
    damage_item,
    flush_living,
    hurt_player,
    knock_back_player,
    play_sound_to,
    set_player_on_fire,
    survival_context,
)


def _name(s: Stack) -> String:
    # Go `item.EncodeItem()` name.
    if case .Some(it) = s.item():
        if case .Some(e) = VanillaItems.encode_item(it.kind, it.hash):
            return e.name
    return String()


def has_cooldown(srv: Server, i: Int, s: Stack) -> Bool:
    """Go `HasCooldown`."""
    var name = _name(s)
    var now = monotonic_ms()
    for c in srv.sessions[i].player.cooldowns:
        if c[0] == name:
            return now < c[1]
    return False


def set_cooldown(mut srv: Server, i: Int, s: Stack, ms: Int):
    """Go `SetCooldown`: remembered and shown to the player."""
    var name = _name(s)
    var until = monotonic_ms() + ms
    ref cds = srv.sessions[i].player.cooldowns
    var found = False
    for k in range(len(cds)):
        if cds[k][0] == name:
            cds[k] = (name, until)
            found = True
    if not found:
        cds.append((name, until))
    var parts = name.split(":")
    var category = String(parts[len(parts) - 1])
    srv.sessions[i].send_item_cooldown(category, ms // 50)


def use_duration_ms(srv: Server, i: Int) -> Int:
    """Go `useDuration`: how long the item has been used, plus a tick."""
    return monotonic_ms() - srv.sessions[i].player.using_since_ms + 50


def _update_state(mut srv: Server, i: Int):
    # Go `updateState`.
    var p = srv.sessions[i].player.copy()
    for j in range(len(srv.sessions)):
        srv.sessions[j].view_entity_state(p)


def _start_using(mut srv: Server, i: Int):
    srv.sessions[i].player.using_item = True
    srv.sessions[i].player.using_since_ms = monotonic_ms()
    _update_state(srv, i)


def _subtract(srv: Server, i: Int, s: Stack, n: Int) -> Stack:
    # Go `subtractItem`.
    if not srv.sessions[i].player.game_mode().creative_inventory() and n != 0:
        return s.grow(-n)
    return s.copy()


def add_new_item(mut srv: Server, i: Int, s: Stack):
    """Go `addNewItem`: into the empty hand, else the inventory, dropping
    what does not fit."""
    if s.empty():
        return
    var held = srv.sessions[i].invs.held_item()
    if held.empty():
        srv.sessions[i].invs.set_held_item(s)
        return
    var n = srv.sessions[i].invs.inv.add_item(s.copy())
    if n < s.count():
        srv.drop_item(i, s.grow(-n))


def _handle_use_context(
    mut srv: Server,
    i: Int,
    damage: Int,
    count_sub: Int,
    new_item: Stack,
    consumed: List[Stack],
):
    # Go `handleUseContext`.
    var held = srv.sessions[i].invs.held_item()
    var damaged = damage_item(srv, i, held, damage)
    srv.sessions[i].invs.set_held_item(_subtract(srv, i, damaged, count_sub))
    add_new_item(srv, i, new_item)
    for it in consumed:
        var off = srv.sessions[i].invs.off_hand_item()
        if off.comparable(it):
            try:
                srv.sessions[i].invs.off_hand.remove_item(it)
                continue
            except:
                pass
        try:
            srv.sessions[i].invs.inv.remove_item(it)
        except:
            pass


def _first_arrow(srv: Server, i: Int) -> Optional[Stack]:
    # Go `useContext().FirstFunc` for arrows: the off hand first.
    var off = srv.sessions[i].invs.off_hand_item()
    if not off.empty() and off.item_as[ArrowItem]():
        return off^
    for it in srv.sessions[i].invs.inv.slots():
        if not it.empty() and it.item_as[ArrowItem]():
            return it.copy()
    return None


def can_release(srv: Server, i: Int) -> Bool:
    """Go `canRelease`: a bow with an arrow somewhere, or creative."""
    var held = srv.sessions[i].invs.held_item()
    if not held.item_as[Bow]():
        return False
    if srv.sessions[i].player.game_mode().creative_inventory():
        return True
    return Bool(_first_arrow(srv, i))


# ===----------------------------------------------------------------------=== #
# Using
# ===----------------------------------------------------------------------=== #


def use_item(mut srv: Server, i: Int):
    """Go `UseItem`: the held item is used in the air."""
    if srv.sessions[i].player.game_mode() == GAME_MODE_SPECTATOR:
        return
    var held = srv.sessions[i].invs.held_item()
    if has_cooldown(srv, i, held):
        return
    if case .Some(it) = held.item():
        if case .Some(cd) = VanillaItems.cooldown(it.kind, it.hash):
            set_cooldown(srv, i, held, cd)
    if held.item_as[Bow]():
        # Go's `Releasable`: drawing starts.
        if not can_release(srv, i):
            return
        _start_using(srv, i)
        return
    if _use(srv, i, held):
        return
    if case .Some(it) = held.item():
        if case .Some(info) = VanillaItems.consume_info(it.kind, it.hash):
            _use_consumable(srv, i, held, info)


def _use(mut srv: Server, i: Int, held: Stack) -> Bool:
    # Go's `item.Usable` case; returns whether the item is usable.
    ref p = srv.sessions[i].player
    var id = p.uuid()
    var pos = p.position()
    var rot = p.rotation()
    var thrown = True
    if held.item_as[Snowball]():
        throw_snowball(srv.world, id, pos, EYE_HEIGHT, rot)
    elif held.item_as[Egg]():
        throw_egg(srv.world, id, pos, EYE_HEIGHT, rot)
    elif held.item_as[EnderPearl]():
        throw_ender_pearl(srv.world, id, pos, EYE_HEIGHT, rot)
    elif case .Some(s) = held.item_as[SplashPotion]():
        throw_splash_potion(srv.world, id, pos, EYE_HEIGHT, rot, s.type)
    elif case .Some(l) = held.item_as[LingeringPotion]():
        throw_lingering_potion(srv.world, id, pos, EYE_HEIGHT, rot, l.type)
    elif held.item_as[BottleOfEnchanting]():
        throw_bottle_of_enchanting(srv.world, id, pos, EYE_HEIGHT, rot)
    else:
        thrown = False
    if thrown:
        srv.world.play_sound(pos, ItemThrow())
        swing_arm(srv, i)
        _handle_use_context(srv, i, 0, 1, Stack(), List[Stack]())
        return True
    if case .Some(it) = held.item():
        if case .Some(slot) = VanillaItems.armour_slot(it.kind, it.hash):
            if slot >= 0:
                # Go `SwapHeldWithArmour`; `Use` returns false.
                _swap_held_with_armour(srv, i, slot)
                return True
    return False


def _swap_held_with_armour(mut srv: Server, i: Int, slot: Int):
    var held = srv.sessions[i].invs.held_item()
    var worn = srv.sessions[i].invs.armour._get(slot)
    srv.sessions[i].invs.set_held_item(worn)
    try:
        srv.sessions[i].invs.armour.inv.set_item(slot, held)
    except:
        pass
    play_sound_to(srv, i, EquipItem())


def _use_consumable(mut srv: Server, i: Int, held: Stack, info: ConsumeInfo):
    # Go's `item.Consumable` case.
    if case .Some(b) = held.item_as[Bucket]():
        if not b.content.milk:
            # Go `CanConsume`: only milk.
            release_item(srv, i)
            return
    var it = held.item().value()
    var always = VanillaItems.always_consumable(it.kind, it.hash).or_else(False)
    ref p = srv.sessions[i].player
    if (
        not always
        and p.game_mode().allows_taking_damage()
        and p.living.hunger.food_level >= 20
    ):
        release_item(srv, i)
        return
    if not p.using_item:
        _start_using(srv, i)
        return
    var duration = VanillaItems.consume_duration(it.kind, it.hash).or_else(0)
    if use_duration_ms(srv, i) < duration:
        return
    srv.sessions[i].player.using_since_ms = monotonic_ms()
    consume(srv, i, info, Bool(held.item_as[GoldenApple]()))
    _handle_use_context(srv, i, 0, 1, info.residue, List[Stack]())
    var at = srv.sessions[i].player.position().add(Vec3(0, 1.5, 0))
    srv.world.play_sound(at, Burp())


def consume(
    mut srv: Server, i: Int, info: ConsumeInfo, golden_apple: Bool = False
):
    """Applies what consuming an item does (Go's `Consume` methods, which
    `consume_info` describes): food, effects (some by chance, from Go's
    global source) and removed effects. A golden apple also raises the
    absorption to `max(prev, min(prev + 4, 16))` after its Absorption."""
    var ctx = survival_context(srv, i)
    if info.food != 0 or info.saturation != 0:
        srv.sessions[i].player.living.saturate(info.food, info.saturation)
    var prev = srv.sessions[i].player.living.absorption
    for ce in info.effects:
        if ce.chance < 1 and srv.world.global_rand().float64() >= ce.chance:
            continue
        srv.sessions[i].player.living.add_effect(ce.effect, ctx)
        if golden_apple and ce.effect.type_id() == Absorption.ID:
            srv.sessions[i].player.living.set_absorption(
                max(prev, min(prev + 4, 16))
            )
    for id in info.removed_effects:
        srv.sessions[i].player.living.remove_effect(id)
    if info.removes_all_effects:
        var ids = List[Int]()
        for e in srv.sessions[i].player.living.effects:
            ids.append(e.type_id())
        for id in ids:
            srv.sessions[i].player.living.remove_effect(id)
    flush_living(srv, i)


def release_item(mut srv: Server, i: Int):
    """Go `ReleaseItem`: a drawn bow shoots."""
    ref p = srv.sessions[i].player
    if (
        not p.using_item
        or not can_release(srv, i)
        or not p.game_mode().allows_interaction()
    ):
        srv.sessions[i].player.using_item = False
        return
    srv.sessions[i].player.using_item = False
    var dur = use_duration_ms(srv, i)
    _release_bow(srv, i, dur)
    _update_state(srv, i)


def _release_bow(mut srv: Server, i: Int, dur_ms: Int):
    # Go `Bow.Release`, then `handleUseContext`.
    var creative = srv.sessions[i].player.game_mode().creative_inventory()
    var ticks = dur_ms // 50
    if ticks < 3:
        return
    var d = Float64(ticks) / 20
    var force = min((d * d + d * 2) / 3, 1.0)
    if force < 0.1:
        return
    var arrow = _first_arrow(srv, i)
    if not arrow and not creative:
        return
    var conf = ArrowSpawnConfig()
    if case .Some(a) = arrow:
        conf.tip = a.item_as[ArrowItem]().value().tip
    var held = srv.sessions[i].invs.held_item()
    var damage = 2.0
    var burn_ms = 0
    var consume = not creative
    if held.enchantment(Int16(FLAME_ID)):
        burn_ms = 5000
    if case .Some(e) = held.enchantment(Int16(PUNCH_ID)):
        conf.punch_level = e.level
    if case .Some(e) = held.enchantment(Int16(POWER_ID)):
        damage += Power().power_damage(e.level)
    if held.enchantment(Int16(INFINITY_ID)):
        consume = False
    ref p = srv.sessions[i].player
    var rot = p.rotation()
    conf.damage = damage
    conf.owner = p.uuid()
    conf.critical = force >= 1
    conf.obtain_arrow_on_pickup = not creative and consume
    spawn_arrow(
        srv.world,
        p.eye_position(),
        rot.vec3().mul(force * 5),
        conf,
        rot.neg(),
        burn_ms,
    )
    var consumed = List[Stack]()
    if consume:
        var a = arrow.value().copy()
        consumed.append(a.grow(-a.count() + 1))
    _handle_use_context(srv, i, 1, 0, Stack(), consumed)
    srv.world.play_sound(srv.sessions[i].player.position(), BowShoot())


def tick_using(mut srv: Server, i: Int, current: Int):
    """Go `Tick`: eating particles about every 4 ticks."""
    if current % 4 != 0 or not srv.sessions[i].player.using_item:
        return
    var held = srv.sessions[i].invs.held_item()
    if case .Some(it) = held.item():
        if not VanillaItems.consume_info(it.kind, it.hash):
            return
        var p = srv.sessions[i].player.copy()
        for j in range(len(srv.sessions)):
            srv.sessions[j].view_entity_eat(p, held)


# ===----------------------------------------------------------------------=== #
# Attacking
# ===----------------------------------------------------------------------=== #


def target_session(srv: Server, i: Int, runtime_id: UInt64) -> Optional[Int]:
    """Returns the session of the player that session `i` knows by a
    runtime ID."""
    if case .Some(key) = srv.sessions[i].entity_key(runtime_id):
        for j in range(len(srv.sessions)):
            if String(srv.sessions[j].player.uuid()) == key:
                return j
    return None


def attack_entity(mut srv: Server, i: Int, runtime_id: UInt64) -> Bool:
    """Go `AttackEntity` on another player: held item damage with
    Strength, Weakness and Sharpness, critical hits while falling, knock-back
    (Knockback adds to it), Fire Aspect and the weapon's durability.
    Returns False if the attack was not valid."""
    var found = target_session(srv, i, runtime_id)
    if not found:
        # Go: the entity is gone; latency allows this.
        return True
    var j = found.value()
    ref p = srv.sessions[i].player
    var target_pos = srv.sessions[j].player.position()
    if not p.can_reach(target_pos):
        return False
    if srv.sessions[j].player.living.dead():
        return False
    var force = 0.45
    var height = 0.3608
    ref l = p.living
    var critical = (
        not p.sprinting()
        and not p.flying()
        and l.fall_distance > 0
        and not l.effect(SlowFalling.ID)
        and not l.effect(Blindness.ID)
    )
    var held = srv.sessions[i].invs.held_item()
    if case .Some(k) = held.enchantment(Int16(KNOCKBACK_ID)):
        var inc = Knockback().force(k.level)
        force += inc
        height += inc
    swing_arm(srv, i)
    # Go `Stack.AttackDamage`: a weapon's damage plus 1, else 1.
    var dmg = 1.0
    if case .Some(it) = held.item():
        if case .Some(a) = VanillaItems.attack_damage(it.kind, it.hash):
            dmg = a + 1
    if case .Some(s) = srv.sessions[i].player.living.effect(Strength.ID):
        dmg += dmg * Strength().multiplier(s.level())
    if case .Some(w) = srv.sessions[i].player.living.effect(Weakness.ID):
        dmg -= dmg * Weakness().multiplier(w.level())
    var target = srv.sessions[j].player.copy()
    if case .Some(s) = held.enchantment(Int16(SHARPNESS_ID)):
        dmg += Sharpness().addend(s.level)
        for k in range(len(srv.sessions)):
            srv.sessions[k].view_entity_animate(
                target, ANIMATE_ACTION_MAGIC_CRITICAL_HIT, 15
            )
    if critical:
        dmg *= 1.5
    var attacker = srv.sessions[i].player.uuid()
    var res = hurt_player(srv, j, dmg, AnyDamageSource(DAMAGE_ATTACK, attacker))
    var now_held = srv.sessions[i].invs.held_item()
    if case .Some(it) = now_held.item():
        if case .Some(d) = VanillaItems.durability_info(it.kind, it.hash):
            var damaged = damage_item(srv, i, now_held, d.attack_durability)
            srv.sessions[i].invs.set_held_item(damaged)
    var eye = srv.sessions[j].player.eye_position()
    srv.world.play_sound(eye, Attack(damage=not float_equal(res[0], 0)))
    if not res[1]:
        return True
    if critical:
        for k in range(len(srv.sessions)):
            srv.sessions[k].view_entity_animate(
                target, ANIMATE_ACTION_CRITICAL_HIT, 55
            )
    var ctx = survival_context(srv, i)
    srv.sessions[i].player.living.exhaust(0.1, ctx)
    flush_living(srv, i)
    knock_back_player(srv, j, srv.sessions[i].player.position(), force, height)
    if case .Some(f) = held.enchantment(Int16(FIRE_ASPECT_ID)):
        set_player_on_fire(srv, j, FireAspect().duration(f.level) // 1_000_000)
    return True
