"""Throwing projectiles, ported from the `Use` methods of Dragonfly's
throwable items (`server/item/snowball.go`, `egg.go`, `ender_pearl.go`,
`splash_potion.go`, `lingering_potion.go`, `bottle_of_enchanting.go`).

`server.use.use_item` calls these when a player uses the item in the air,
then takes one item from the stack (Go `item.Usable`). The helpers take what
Go reads from the user: its position, eye height, rotation and UUID.
"""

from std.math import sqrt

from minecraft.protocol.uuid import UUID

from ..block.cube.rotation import Rotation
from ..item.potion.potion import Potion
from ..mgl64 import Vec3
from ..world.entity import EntityHandle, EntitySpawnOpts, EntityType
from ..world.sound.item import ItemThrow
from ..world.world import World, WorldTypes
from .bottle_of_enchanting import BottleOfEnchanting
from .egg import Egg
from .ender_pearl import EnderPearl
from .lingering_potion import LingeringPotion
from .snowball import Snowball
from .splash_potion import SplashPotion


def throwable_offset(r: Rotation) -> Rotation:
    """Tilts a throw upwards (Go `throwableOffset`)."""
    var pitch = max(min(r.pitch(), 89.9), -89.9)
    pitch -= sqrt(89.9 * 89.9 - pitch * pitch) * (26.5 / 89.9)
    pitch = max(min(pitch, 89.9), -89.9)
    return Rotation(r.yaw(), pitch)


def _throw[
    T: WorldTypes, E: EntityType
](mut tx: World[T], var e: E, feet: Vec3, eye_height: Float64, vel: Vec3):
    # Go's `Use`: spawn at the eye with the user as owner, then the sound.
    var state = T.Entities.try_wrap(e^)
    if not state:
        return
    var opts = EntitySpawnOpts()
    opts.position = feet.add(Vec3(0, eye_height, 0))
    opts.velocity = vel
    _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))
    tx.play_sound(feet, ItemThrow())


def throw_snowball[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
):
    """Throws a snowball (Go `Snowball.Use`)."""
    var e = Snowball()
    e.proj.owner = owner
    _throw(tx, e^, feet, eye_height, rot.vec3().mul(1.5))


def throw_egg[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
):
    """Throws an egg (Go `Egg.Use`)."""
    var e = Egg()
    e.proj.owner = owner
    _throw(tx, e^, feet, eye_height, rot.vec3().mul(1.5))


def throw_ender_pearl[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
):
    """Throws an ender pearl (Go `EnderPearl.Use`)."""
    var e = EnderPearl()
    e.proj.owner = owner
    _throw(tx, e^, feet, eye_height, rot.vec3().mul(1.5))


def throw_splash_potion[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
    p: Potion,
):
    """Throws a splash potion (Go `SplashPotion.Use`)."""
    var e = SplashPotion()
    e.proj.owner = owner
    e.proj.potion = p
    _throw(tx, e^, feet, eye_height, throwable_offset(rot).vec3().mul(0.5))


def throw_lingering_potion[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
    p: Potion,
):
    """Throws a lingering potion (Go `LingeringPotion.Use`)."""
    var e = LingeringPotion()
    e.proj.owner = owner
    e.proj.potion = p
    _throw(tx, e^, feet, eye_height, throwable_offset(rot).vec3().mul(0.5))


def throw_bottle_of_enchanting[
    T: WorldTypes
](
    mut tx: World[T],
    owner: UUID,
    feet: Vec3,
    eye_height: Float64,
    rot: Rotation,
):
    """Throws a bottle o' enchanting (Go `BottleOfEnchanting.Use`)."""
    var e = BottleOfEnchanting()
    e.proj.owner = owner
    _throw(tx, e^, feet, eye_height, throwable_offset(rot).vec3().mul(0.6))
