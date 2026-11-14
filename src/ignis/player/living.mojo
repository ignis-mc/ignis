"""The survival state of a player, ported from the health, hunger, effect,
fall, fire, air and death parts of Dragonfly `server/player/player.go`,
with `entity/effect.go` (`EffectManager`) and the effects' `Apply`,
`Start` and `End`.

Go's player reaches the world, its session and its viewers directly; here
the world facts a tick needs come in a `SurvivalContext` and what viewers
or the client must see goes out as `LivingEvent`s, which the server turns
into packets. Go's attack immunity is wall-clock time; here it is the
world's `now_ms`. Go ticks effects in map order; here in the order they
were added.
"""

from std.math import ceil

from ..entity.damage import (
    DAMAGE_DROWNING,
    DAMAGE_FALL,
    DAMAGE_FIRE,
    DAMAGE_POISON,
    DAMAGE_STARVATION,
    DAMAGE_SUFFOCATION,
    DAMAGE_VOID,
    DAMAGE_WITHER,
    DAMAGE_INSTANT,
    AnyDamageSource,
)
from ..entity.effect import SECOND, Effect, new
from ..entity.effect.absorption import Absorption
from ..entity.effect.fatal_poison import FatalPoison
from ..entity.effect.fire_resistance import FireResistance
from ..entity.effect.health_boost import HealthBoost
from ..entity.effect.hunger import Hunger
from ..entity.effect.instant_damage import InstantDamage
from ..entity.effect.instant_health import InstantHealth
from ..entity.effect.jump_boost import JumpBoost
from ..entity.effect.poison import Poison
from ..entity.effect.regeneration import Regeneration
from ..entity.effect.resistance import Resistance
from ..entity.effect.saturation import Saturation
from ..entity.effect.wither import Wither
from ..entity.experience import ExperienceManager
from ..entity.health import HealthManager
from ..item.inventory.armour import Armour
from ..mgl64 import Vec3
from .hunger import HungerManager

comptime EPSILON = 1e-6
"""Go `mgl64.Epsilon`."""

comptime EVENT_HEALTH = 0
"""The health, maximum or absorption changed (Go `SendHealth`)."""
comptime EVENT_FOOD = 1
"""Food, saturation or exhaustion changed (Go `SendFood`)."""
comptime EVENT_EXPERIENCE = 2
"""The level or progress changed (Go `SendExperience`)."""
comptime EVENT_HURT = 3
"""Viewers see the hurt animation (Go `HurtAction`)."""
comptime EVENT_DEATH = 4
"""Viewers see the death animation (Go `DeathAction`)."""
comptime EVENT_EFFECT = 5
"""An effect was added or replaced (Go `SendEffect`); `effect` holds it."""
comptime EVENT_EFFECT_REMOVED = 6
"""An effect ended (Go `SendEffectRemoval`); `effect` holds it."""
comptime EVENT_STATE = 7
"""The entity state changed (Go `updateState`)."""
comptime EVENT_SOUND_BURNING = 8
"""Go `sound.Burning` at the player."""
comptime EVENT_SOUND_DROWNING = 9
"""Go `sound.Drowning` at the player."""
comptime EVENT_STOP_SPRINTING = 10
"""Go `StopSprinting`."""
comptime EVENT_KNOCK_BACK = 11
"""The player is knocked back; `vel` holds its new velocity."""
comptime EVENT_TOTEM = 12
"""A totem saved the player (Go `applyTotemEffects`)."""


@fieldwise_init
struct LivingEvent(Copyable):
    """Something about a player that the client or viewers must see."""

    var kind: Int
    """One of the `EVENT_*` kinds."""
    var effect: Optional[Effect]
    """The effect of `EVENT_EFFECT` and `EVENT_EFFECT_REMOVED`."""
    var vel: Vec3
    """The velocity of `EVENT_KNOCK_BACK`."""


struct SurvivalContext(Copyable, Defaultable):
    """What a player's survival tick needs to know about its world."""

    var now_ms: Int
    """The world's time, for attack immunity."""
    var takes_damage: Bool
    """Go `GameMode().AllowsTakingDamage()`."""
    var food_regenerates: Bool
    """Go `Difficulty().FoodRegenerates()` (peaceful)."""
    var starvation_health_limit: Float64
    """Go `Difficulty().StarvationHealthLimit()`."""
    var below_world: Bool
    """The player is below the world's range."""
    var inside_solid: Bool
    """Go `insideOfSolid`."""
    var can_breathe: Bool
    """Go `canBreathe`, apart from the effects this state knows."""
    var raining: Bool
    """Go `RainingAt` the player's position."""
    var totem_held: Bool
    """A totem of undying is in either hand (Go checks the held items)."""

    def __init__(out self):
        """Creates a context of survival in an easy world."""
        self.now_ms = 0
        self.takes_damage = True
        self.food_regenerates = False
        self.starvation_health_limit = 10
        self.below_world = False
        self.inside_solid = False
        self.can_breathe = True
        self.raining = False
        self.totem_held = False


struct Living(Copyable, Defaultable):
    """A player's health, hunger, experience and effects."""

    var health: HealthManager
    """Go `health`."""
    var absorption: Float64
    """Go `absorptionHealth`."""
    var hunger: HungerManager
    """Go `hunger`."""
    var experience: ExperienceManager
    """Go `experience`."""
    var effects: List[Effect]
    """The lasting effects (Go `effects`)."""
    var fall_distance: Float64
    """Go `fallDistance`."""
    var immune_until_ms: Int
    """Go `immuneUntil`."""
    var last_damage: Float64
    """Go `lastDamage`."""
    var fire_ticks: Int
    """Go `fireTicks`."""
    var air_supply_ticks: Int
    """Go `airSupplyTicks`."""
    var max_air_supply_ticks: Int
    """Go `maxAirSupplyTicks`."""
    var breathing: Bool
    """Go `breathing`."""
    var death_pos: Optional[Vec3]
    """Where the player last died (Go `deathPos`)."""
    var events: List[LivingEvent]
    """What happened since the server last took the events."""

    def __init__(out self):
        """Creates a healthy, fed player without effects."""
        self.health = HealthManager(20, 20)
        self.absorption = 0
        self.hunger = HungerManager()
        # A new Dragonfly player's food tick is its Config's zero value.
        self.hunger.food_tick = 0
        self.experience = ExperienceManager()
        self.effects = List[Effect]()
        self.fall_distance = 0
        self.immune_until_ms = 0
        self.last_damage = 0
        self.fire_ticks = 0
        self.air_supply_ticks = 300
        self.max_air_supply_ticks = 300
        self.breathing = True
        self.death_pos = None
        self.events = List[LivingEvent]()

    def _event(mut self, kind: Int):
        self.events.append(LivingEvent(kind, None, Vec3()))

    def take_events(mut self) -> List[LivingEvent]:
        """Returns and clears the events."""
        var out = self.events^
        self.events = List[LivingEvent]()
        return out^

    # Health

    def dead(self) -> Bool:
        """Go `Dead`."""
        return self.health.health <= EPSILON

    def add_health(mut self, h: Float64):
        """Go `addHealth`."""
        self.health.add_health(h)
        self._event(EVENT_HEALTH)

    def set_max_health(mut self, h: Float64):
        """Go `SetMaxHealth`."""
        self.health.set_max_health(h)
        self._event(EVENT_HEALTH)

    def set_absorption(mut self, h: Float64):
        """Go `SetAbsorption`."""
        self.absorption = max(h, 0)
        self._event(EVENT_HEALTH)

    def heal(mut self, h: Float64, ctx: SurvivalContext) -> Float64:
        """Heals and returns how much (Go `Heal`; the handler is not
        ported)."""
        if self.dead() or h < 0 or not ctx.takes_damage:
            return 0
        var old = self.health.health
        self.add_health(h)
        return self.health.health - old

    def final_damage_from(
        self, dmg_in: Float64, src: AnyDamageSource, armour: Armour
    ) -> Float64:
        """Returns the damage after armour and resistance (Go
        `FinalDamageFrom`)."""
        var dmg = max(dmg_in, 0)
        dmg -= armour.damage_reduction(dmg, src)
        if case .Some(res) = self.effect(Resistance.ID):
            dmg *= Resistance().multiplier(src, res.level())
        return dmg

    def hurt(
        mut self,
        dmg: Float64,
        src: AnyDamageSource,
        mut armour: Armour,
        ctx: SurvivalContext,
    ) -> Tuple[Float64, Bool]:
        """Hurts the player; returns the damage dealt and whether it was
        vulnerable (Go `Hurt`). Armour durability, thorns and the handler
        are the caller's (see `armour_damage`)."""
        if (
            (self.effect(FireResistance.ID) and src.fire())
            or self.dead()
            or not ctx.takes_damage
            or dmg < 0
        ):
            return (0.0, False)
        var total = self.final_damage_from(dmg, src, armour)
        var left = total
        var immune = ctx.now_ms < self.immune_until_ms
        if immune:
            left -= self.last_damage
            if left <= 0:
                return (0.0, False)
        self.immune_until_ms = ctx.now_ms + 500
        self.last_damage = total
        if self.absorption > 0:
            var a = self.absorption
            var remaining = a - left
            self.set_absorption(remaining)
            left = max(0.0, left - a)
            if self.effect(Absorption.ID) and remaining <= 0:
                self.remove_effect(Absorption.ID)
        if (
            self.health.health - left <= EPSILON
            and not src.ignore_totem()
            and ctx.totem_held
        ):
            self.apply_totem_effects(ctx)
            return (0.0, False)
        self.add_health(-left)
        if src.reduced_by_armour():
            self.exhaust(0.1, ctx)
        self._event(EVENT_HURT)
        if src.fire():
            self._event(EVENT_SOUND_BURNING)
        elif src.kind == DAMAGE_DROWNING:
            self._event(EVENT_SOUND_DROWNING)
        if self.dead():
            self._event(EVENT_DEATH)
        return (total, True)

    def apply_totem_effects(mut self, ctx: SurvivalContext):
        """Go `applyTotemEffects`; the caller takes the totem."""
        self.add_health(2 - self.health.health)
        var ids = List[Int]()
        for e in self.effects:
            ids.append(e.type_id())
        for id in ids:
            self.remove_effect(id)
        self.add_effect(new(Regeneration(), 2, 40 * SECOND), ctx)
        self.add_effect(new(FireResistance(), 1, 40 * SECOND), ctx)
        self.add_effect(new(Absorption(), 2, 5 * SECOND), ctx)
        self._event(EVENT_TOTEM)

    def knock_back(
        mut self,
        pos: Vec3,
        src: Vec3,
        force: Float64,
        height: Float64,
        resistance: Float64,
    ):
        """Knocks the player at `pos` away from `src` (Go `knockBack`);
        `resistance` is the armour's knock-back resistance."""
        var v = pos.sub(src)
        v = Vec3(v.x(), 0, v.z())
        if v.len() != 0:
            v = v.normalize().mul(force)
        v = Vec3(v.x(), height, v.z())
        self.events.append(
            LivingEvent(EVENT_KNOCK_BACK, None, v.mul(1 - resistance))
        )

    # Falling

    def update_fall_state(
        mut self,
        distance_this_tick: Float64,
        on_ground: Bool,
        mut armour: Armour,
        ctx: SurvivalContext,
    ):
        """Tracks falling and hurts on landing (Go `updateFallState`)."""
        if on_ground:
            self.fall_distance -= distance_this_tick
            if self.fall_distance > 3:
                self.fall(self.fall_distance, armour, ctx)
            self.fall_distance = 0
        elif distance_this_tick < 0 and distance_this_tick < self.fall_distance:
            self.fall_distance -= distance_this_tick
        else:
            self.fall_distance = 0

    def fall(
        mut self, distance: Float64, mut armour: Armour, ctx: SurvivalContext
    ):
        """Hurts after a fall (Go `fall`; landing on blocks such as farmland
        is not ported)."""
        var dmg = distance - 3
        if case .Some(boost) = self.effect(JumpBoost.ID):
            dmg -= Float64(boost.level())
        if dmg < 0.5:
            return
        _ = self.hurt(ceil(dmg), AnyDamageSource(DAMAGE_FALL), armour, ctx)

    # Hunger

    def exhaust(mut self, points: Float64, ctx: SurvivalContext):
        """Adds exhaustion (Go `Exhaust`; the handler is not ported)."""
        if not ctx.takes_damage or ctx.food_regenerates:
            return
        var before = self.hunger.food_level
        self.hunger.exhaust(points)
        var after = self.hunger.food_level
        if before != after and before >= 7 and after <= 6:
            self._event(EVENT_STOP_SPRINTING)
        self._event(EVENT_FOOD)

    def saturate(mut self, food: Int, saturation: Float64):
        """Go `Saturate`."""
        self.hunger.saturate(food, saturation)
        self._event(EVENT_FOOD)

    def add_food(mut self, points: Int):
        """Go `AddFood`."""
        self.hunger.add_food(points)
        self._event(EVENT_FOOD)

    def set_food(mut self, level: Int):
        """Go `SetFood`."""
        self.hunger.set_food(level)
        self._event(EVENT_FOOD)

    def tick_food(mut self, mut armour: Armour, ctx: SurvivalContext):
        """Regenerates or starves (Go `tickFood`)."""
        if self.hunger.food_tick % 10 == 0 and (
            self.hunger.can_quickly_regenerate() or ctx.food_regenerates
        ):
            if ctx.food_regenerates:
                self.add_food(1)
            if self.hunger.food_tick % 20 == 0:
                self._regenerate(True, ctx)
        if self.hunger.food_tick == 1:
            if self.hunger.can_regenerate():
                self._regenerate(not ctx.food_regenerates, ctx)
            elif self.hunger.starving():
                if self.health.health > ctx.starvation_health_limit:
                    _ = self.hurt(
                        1, AnyDamageSource(DAMAGE_STARVATION), armour, ctx
                    )
        if not self.hunger.can_sprint():
            self._event(EVENT_STOP_SPRINTING)
        self.hunger.food_tick += 1
        if self.hunger.food_tick > 80:
            self.hunger.food_tick = 1

    def _regenerate(mut self, exhaust: Bool, ctx: SurvivalContext):
        # Go `regenerate`.
        if self.health.health == self.health.max:
            return
        var regenerated = self.heal(1, ctx)
        if exhaust and regenerated > 0:
            self.exhaust(6, ctx)

    # Experience

    def add_experience(mut self, amount: Int) -> Int:
        """Adds experience (Go `AddExperience` without the handler)."""
        _ = self.experience.add(amount)
        self._event(EVENT_EXPERIENCE)
        return amount

    # Effects

    def effect(self, id: Int) -> Optional[Effect]:
        """Returns the lasting effect of a type (Go `Effect`)."""
        for e in self.effects:
            if e.type_id() == id:
                return e
        return None

    def add_effect(mut self, e: Effect, ctx: SurvivalContext):
        """Adds an effect (Go `AddEffect` and `EffectManager.Add`): instant
        effects apply at once, a lasting one replaces a weaker one."""
        if not e.lasting():
            self._apply(e, ctx)
            self.events.append(LivingEvent(EVENT_EFFECT, e, Vec3()))
            return
        var id = e.type_id()
        for i in range(len(self.effects)):
            ref existing = self.effects[i]
            if existing.type_id() != id:
                continue
            if existing.level() > e.level() or (
                existing.level() == e.level()
                and (
                    (existing.duration() > e.duration() and not e.infinite())
                    or existing.infinite()
                )
            ):
                self.events.append(LivingEvent(EVENT_EFFECT, existing, Vec3()))
                return
            var old = existing
            self.effects[i] = e
            self._end(old)
            self._start(e)
            self.events.append(LivingEvent(EVENT_EFFECT, e, Vec3()))
            self._event(EVENT_STATE)
            return
        self.effects.append(e)
        self._start(e)
        self.events.append(LivingEvent(EVENT_EFFECT, e, Vec3()))
        self._event(EVENT_STATE)

    def remove_effect(mut self, id: Int):
        """Removes the lasting effect of a type (Go `RemoveEffect`)."""
        for i in range(len(self.effects)):
            if self.effects[i].type_id() == id:
                var e = self.effects.pop(i)
                self._end(e)
                self.events.append(LivingEvent(EVENT_EFFECT_REMOVED, e, Vec3()))
                self._event(EVENT_STATE)
                return

    def tick_effects(mut self, mut armour: Armour, ctx: SurvivalContext):
        """Applies the lasting effects and ends expired ones (Go
        `EffectManager.Tick`)."""
        var update = False
        var i = 0
        while i < len(self.effects):
            var e = self.effects[i]
            if e.duration() <= 0 and not e.infinite():
                _ = self.effects.pop(i)
                self._end(e)
                self.events.append(LivingEvent(EVENT_EFFECT_REMOVED, e, Vec3()))
                update = True
                continue
            self._apply(e, ctx, armour)
            # Applying may have removed or replaced effects.
            if (
                i < len(self.effects)
                and self.effects[i].type_id() == e.type_id()
            ):
                self.effects[i] = self.effects[i].tick_duration()
            i += 1
        if update:
            self._event(EVENT_STATE)

    def _apply(mut self, e: Effect, ctx: SurvivalContext):
        var armour = Armour()
        self._apply(e, ctx, armour)

    def _apply(mut self, e: Effect, ctx: SurvivalContext, mut armour: Armour):
        # The `Apply` methods of the effect types that do something to a
        # living entity.
        var id = e.type_id()
        var lvl = e.level()
        if id == Regeneration.ID:
            if e.tick() % max(50 >> (lvl - 1), 1) == 0:
                _ = self.heal(1, ctx)
        elif id == Poison.ID:
            if e.tick() % max(25 >> (lvl - 1), 1) == 0:
                if self.health.health > 1:
                    _ = self.hurt(
                        1, AnyDamageSource(DAMAGE_POISON), armour, ctx
                    )
        elif id == FatalPoison.ID:
            if e.tick() % max(25 >> (lvl - 1), 1) == 0:
                var src = AnyDamageSource(DAMAGE_POISON)
                src.fatal = True
                _ = self.hurt(1, src, armour, ctx)
        elif id == Wither.ID:
            if e.tick() % max(80 >> lvl, 1) == 0:
                _ = self.hurt(1, AnyDamageSource(DAMAGE_WITHER), armour, ctx)
        elif id == InstantHealth.ID:
            _ = self.heal(Float64(2 << lvl) * e.potency(), ctx)
        elif id == InstantDamage.ID:
            _ = self.hurt(
                Float64(3 << lvl) * e.potency(),
                AnyDamageSource(DAMAGE_INSTANT),
                armour,
                ctx,
            )
        elif id == Hunger.ID:
            self.exhaust(Float64(lvl) * 0.005, ctx)
        elif id == Saturation.ID:
            self.saturate(lvl, 2 * Float64(lvl))

    def _start(mut self, e: Effect):
        # The `Start` methods of lasting effect types.
        var id = e.type_id()
        if id == Absorption.ID:
            self.set_absorption(4 * Float64(e.level()))
        elif id == HealthBoost.ID:
            self.set_max_health(self.health.max + 4 * Float64(e.level()))

    def _end(mut self, e: Effect):
        # The `End` methods of lasting effect types.
        var id = e.type_id()
        if id == Absorption.ID:
            self.set_absorption(0)
        elif id == HealthBoost.ID:
            self.set_max_health(self.health.max - 4 * Float64(e.level()))

    # Fire and air

    def set_on_fire(mut self, duration_ms: Int):
        """Go `SetOnFire`."""
        var ticks = max(duration_ms, 0) // 50
        var changed = (self.fire_ticks > 0) != (ticks > 0)
        self.fire_ticks = ticks
        if changed:
            self._event(EVENT_STATE)

    def tick_air_supply(mut self, mut armour: Armour, ctx: SurvivalContext):
        """Go `tickAirSupply`; Respiration is not taken into account."""
        if not ctx.can_breathe and ctx.takes_damage:
            self.air_supply_ticks -= 1
            if self.air_supply_ticks <= -20:
                self.air_supply_ticks = 0
                _ = self.hurt(2, AnyDamageSource(DAMAGE_DROWNING), armour, ctx)
            self.breathing = False
            self._event(EVENT_STATE)
        elif (
            not self.breathing
            and self.air_supply_ticks < self.max_air_supply_ticks
        ):
            self.air_supply_ticks = min(
                self.air_supply_ticks + 5, self.max_air_supply_ticks
            )
            self.breathing = self.air_supply_ticks == self.max_air_supply_ticks
            self._event(EVENT_STATE)

    # The tick

    def tick(mut self, mut armour: Armour, ctx: SurvivalContext):
        """Ticks effects, food, air, the void, suffocation and fire (the
        survival part of Go `Tick`)."""
        if self.dead():
            return
        self.tick_effects(armour, ctx)
        self.tick_food(armour, ctx)
        self.tick_air_supply(armour, ctx)
        if ctx.below_world:
            _ = self.hurt(4, AnyDamageSource(DAMAGE_VOID), armour, ctx)
        if ctx.inside_solid:
            _ = self.hurt(1, AnyDamageSource(DAMAGE_SUFFOCATION), armour, ctx)
        if self.fire_ticks > 0:
            self.fire_ticks -= 1
            if not ctx.takes_damage or self.fire_ticks <= 0 or ctx.raining:
                self.set_on_fire(0)
            if (self.fire_ticks * 50) % 1000 == 0:
                _ = self.hurt(1, AnyDamageSource(DAMAGE_FIRE), armour, ctx)

    # Death and respawning

    def kill(mut self, pos: Vec3):
        """Empties health, ends effects and records the death position (Go
        `kill`; dropping items is the caller's)."""
        self.add_health(-self.health.max)
        var ids = List[Int]()
        for e in self.effects:
            ids.append(e.type_id())
        for id in ids:
            self.remove_effect(id)
        self.death_pos = pos

    def respawn(mut self):
        """Restores health, food and air for a respawn (the survival part of
        Go `respawn`)."""
        self.add_health(self.health.max)
        self.hunger.reset()
        self._event(EVENT_FOOD)
        self.fire_ticks = 0
        self.air_supply_ticks = self.max_air_supply_ticks
        self.breathing = True
        self.fall_distance = 0
        self.absorption = 0
