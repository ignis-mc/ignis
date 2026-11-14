"""Entity metadata of world entities, ported from Dragonfly
`server/session/entity_metadata.go` (`parseEntityMetadata` and the parts of
`addSpecificMetadata` the world's entity types reach).

Go checks interfaces on the entity and its behaviour; here the types of
`VanillaEntities` are checked one by one. Owners are given as runtime IDs,
which only the session knows. Player metadata stays in the session.
"""

from std.memory import bitcast

from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import NBT, NETWORK_LITTLE_ENDIAN
from minecraft.protocol.entity_metadata import (
    ENTITY_DATA_FLAG_ALWAYS_SHOW_NAME,
    ENTITY_DATA_FLAG_CLIMB,
    ENTITY_DATA_FLAG_CRITICAL,
    ENTITY_DATA_FLAG_ENCHANTED,
    ENTITY_DATA_FLAG_HAS_GRAVITY,
    ENTITY_DATA_FLAG_IGNITED,
    ENTITY_DATA_FLAG_LINGERING,
    ENTITY_DATA_FLAG_NO_AI,
    ENTITY_DATA_FLAG_ON_FIRE,
    ENTITY_DATA_FLAG_SHOW_NAME,
    ENTITY_DATA_KEY_ALWAYS_SHOW_NAME_TAG,
    ENTITY_DATA_KEY_AUX_VALUE_DATA,
    ENTITY_DATA_KEY_COLOR_INDEX,
    ENTITY_DATA_KEY_CUSTOM_DISPLAY,
    ENTITY_DATA_KEY_DATA_CHANGE_ON_PICKUP,
    ENTITY_DATA_KEY_DATA_CHANGE_RATE,
    ENTITY_DATA_KEY_DATA_DURATION,
    ENTITY_DATA_KEY_DATA_RADIUS,
    ENTITY_DATA_KEY_DISPLAY_FIREWORK,
    ENTITY_DATA_KEY_EFFECT_AMBIENCE,
    ENTITY_DATA_KEY_EFFECT_COLOR,
    ENTITY_DATA_KEY_FLAGS,
    ENTITY_DATA_KEY_FUSE_TIME,
    ENTITY_DATA_KEY_HEIGHT,
    ENTITY_DATA_KEY_NAME,
    ENTITY_DATA_KEY_OWNER,
    ENTITY_DATA_KEY_VALUE,
    ENTITY_DATA_KEY_VISIBLE_MOB_EFFECTS,
    ENTITY_DATA_KEY_WIDTH,
    EntityMetadata,
    new_entity_metadata,
)

from ..entity.area_effect_cloud import AreaEffectCloud
from ..entity.arrow import Arrow
from ..entity.bottle_of_enchanting import BottleOfEnchanting
from ..entity.effect import resulting_colour
from ..entity.egg import Egg
from ..entity.ender_pearl import EnderPearl
from ..entity.experience_orb import ExperienceOrb
from ..entity.firework import Firework
from ..entity.lightning import Lightning
from ..entity.lingering_potion import LingeringPotion
from ..entity.projectile import ProjectileBehaviour
from ..entity.register import VanillaEntities
from ..entity.snowball import Snowball
from ..entity.splash_potion import SplashPotion
from ..entity.text import Text
from ..entity.tnt import TNT
from ..item.item import int32_from_rgba
from ..item.nbt import write_nbt
from ..item.stack import Stack
from ..world.entity import EntityHandle, EntityTypes

comptime _SMALLEST_NONZERO_FLOAT32 = bitcast[DType.float32](UInt32(1))
"""Go `math.SmallestNonzeroFloat32`."""


def entity_metadata[
    E: EntityTypes
](
    h: EntityHandle[E], owner_runtime_id: Optional[Int64] = None
) raises -> EntityMetadata:
    """Returns the metadata of a world entity as Dragonfly sends it (Go
    `parseEntityMetadata`); `owner_runtime_id` is the runtime ID of its
    owner, if it has one."""
    var bb = h.bbox()
    var m = new_entity_metadata()
    m.set(ENTITY_DATA_KEY_WIDTH, Float32(bb.width()))
    m.set(ENTITY_DATA_KEY_HEIGHT, Float32(bb.height()))
    m.set(ENTITY_DATA_KEY_EFFECT_COLOR, Int32(0))
    m.set(ENTITY_DATA_KEY_EFFECT_AMBIENCE, UInt8(0))
    m.set(ENTITY_DATA_KEY_COLOR_INDEX, UInt8(0))
    m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_HAS_GRAVITY)
    m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_CLIMB)
    comptime if E == VanillaEntities:
        ref v = rebind[EntityHandle[VanillaEntities]](h)
        ref s = v.state
        if s.isa[BottleOfEnchanting]():
            # Go `bottleOfEnchantingType.Glint`.
            m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_ENCHANTED)
        if s.isa[LingeringPotion]():
            m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_LINGERING)
        # The entity (Go `*entity.Ent`): on fire and its name tag.
        if h.data.fire_duration_ms > 0:
            m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_ON_FIRE)
        _write_name_tag(m, h.data.name, h.data.always_show_name_tag)
        # The behaviour.
        if s.isa[Arrow]():
            _projectile(m, s[Arrow].proj, owner_runtime_id)
        elif s.isa[Snowball]():
            _projectile(m, s[Snowball].proj, owner_runtime_id)
        elif s.isa[Egg]():
            _projectile(m, s[Egg].proj, owner_runtime_id)
        elif s.isa[EnderPearl]():
            _projectile(m, s[EnderPearl].proj, owner_runtime_id)
        elif s.isa[SplashPotion]():
            _projectile(m, s[SplashPotion].proj, owner_runtime_id)
        elif s.isa[LingeringPotion]():
            _projectile(m, s[LingeringPotion].proj, owner_runtime_id)
        elif s.isa[BottleOfEnchanting]():
            _projectile(m, s[BottleOfEnchanting].proj, owner_runtime_id)
        elif s.isa[ExperienceOrb]():
            m.set(ENTITY_DATA_KEY_VALUE, Int32(s[ExperienceOrb].experience))
        elif s.isa[Firework]():
            ref f = s[Firework]
            var t = write_nbt(Stack(f.firework, 1))
            m.set(
                ENTITY_DATA_KEY_DISPLAY_FIREWORK,
                NBT(encode(t, NETWORK_LITTLE_ENDIAN), NETWORK_LITTLE_ENDIAN),
            )
            if f.attached:
                if case .Some(o) = owner_runtime_id:
                    m.set(ENTITY_DATA_KEY_CUSTOM_DISPLAY, o)
        elif s.isa[TNT]():
            m.set(
                ENTITY_DATA_KEY_FUSE_TIME, Int32(s[TNT].passive.fuse_ms // 50)
            )
            m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_IGNITED)
        elif s.isa[Lightning]() or s.isa[Text]():
            # Go `StationaryBehaviour.Immobile`.
            m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_NO_AI)
        elif s.isa[AreaEffectCloud]():
            ref c = s[AreaEffectCloud]
            m.set(ENTITY_DATA_KEY_DATA_RADIUS, Float32(c.radius))
            m.set(ENTITY_DATA_KEY_DATA_DURATION, Int32.MAX)
            m.set(
                ENTITY_DATA_KEY_DATA_CHANGE_ON_PICKUP, _SMALLEST_NONZERO_FLOAT32
            )
            m.set(ENTITY_DATA_KEY_DATA_CHANGE_RATE, _SMALLEST_NONZERO_FLOAT32)
            var colour = resulting_colour(c.potion.effects())
            m.set(ENTITY_DATA_KEY_EFFECT_COLOR, int32_from_rgba(colour[0]))
            m.set(
                ENTITY_DATA_KEY_EFFECT_AMBIENCE,
                UInt8(1) if colour[1] else UInt8(0),
            )
            # Go's `effectBearer`: the cloud has `Effects`.
            var packed = Int64(0)
            for e in c.potion.effects():
                if not e.particles_hidden():
                    packed = (packed << 7) | Int64(e.type_id() << 1)
                    if e.ambient():
                        packed |= 1
            m.set(ENTITY_DATA_KEY_VISIBLE_MOB_EFFECTS, packed)
    return m^


def _projectile(
    mut m: EntityMetadata, p: ProjectileBehaviour, owner: Optional[Int64]
) raises:
    # Go's `arrow`, `owned` and `splash` checks on a ProjectileBehaviour.
    if p.is_critical():
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_CRITICAL)
    if case .Some(o) = owner:
        m.set(ENTITY_DATA_KEY_OWNER, o)
    var tip = p.potion.uint8()
    m.set(ENTITY_DATA_KEY_AUX_VALUE_DATA, Int16(tip))
    if tip > 4:
        m.set(ENTITY_DATA_KEY_CUSTOM_DISPLAY, UInt8(tip + 1))


def _write_name_tag(
    mut m: EntityMetadata, name: String, always_show: Bool
) raises:
    # Go `writeNameTagMetadata`.
    var show = name.byte_length() > 0
    var always = show and always_show
    m.set(ENTITY_DATA_KEY_NAME, name)
    m.set(
        ENTITY_DATA_KEY_ALWAYS_SHOW_NAME_TAG, UInt8(1) if always else UInt8(0)
    )
    if show:
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_SHOW_NAME)
    else:
        m.unset_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_SHOW_NAME)
    if always:
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_ALWAYS_SHOW_NAME)
    else:
        m.unset_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_ALWAYS_SHOW_NAME)
