"""Entities, ported from the core of Dragonfly `server/world/entity.go`.

Go splits an entity into an `EntityHandle` (persistent identity, type and
`EntityData`, valid across worlds) and an `Entity` opened from it inside a
transaction, with the type's behaviour state in `EntityData.Data any`.
Mojo has no interface values, so Ignis uses the same pattern as for blocks:

- An entity type is a struct conforming to `EntityType`. The struct is both
  Go's `EntityType` (its `IDENTIFIER`, `bbox`, NBT) and Go's `Data`: the
  value holds the type's behaviour state.
- `EntityHandle[E]` holds the UUID, the shared `EntityData` and the state
  as an `E.State`, a `Variant` over the types of the entity set `E`
  (`EntitySet[*Ts]`). The world owns the handles of its entities and keys
  them by UUID; `World.remove_entity` gives the handle back, so it can be
  added to another world, as in Go.
- Behaviours some types have (Go `TickerEntity`) are traits refining
  `EntityType`, dispatched by `EntitySet` like `BlockSet` dispatches block
  behaviours.

The transaction machinery of Go's `EntityHandle` (conditions, weak
transactions, `execWorld`) has no counterpart: everything runs on the loop.
Not ported yet: `EntityRegistryConfig` (the constructors blocks and items
use to spawn entities) and the damage and healing source interfaces.
"""

from std.utils import Variant

from minecraft.nbt.nbt import TAG_FLOAT, TAG_LIST, TAG_SHORT, TAG_STRING
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..block.cube.rotation import Rotation
from ..mgl64 import Vec3
from .world import World, WorldTypes


@fieldwise_init
struct EntityData(Copyable, Defaultable, Writable):
    """The data every entity has (Go `EntityData`, without `Data`, which is
    the handle's `state`)."""

    var pos: Vec3
    """The position."""
    var vel: Vec3
    """The velocity, in blocks per tick."""
    var rot: Rotation
    """The yaw and pitch."""
    var name: String
    """The name tag."""
    var always_show_name_tag: Bool
    """Whether the name tag shows when not looked at."""
    var fire_duration_ms: Int
    """How long the entity stays on fire."""
    var age_ms: Int
    """How long the entity has existed."""

    def __init__(out self):
        """Creates the data of a new entity (Go sets `AlwaysShowNameTag`)."""
        self.pos = Vec3()
        self.vel = Vec3()
        self.rot = Rotation()
        self.name = String()
        self.always_show_name_tag = True
        self.fire_duration_ms = 0
        self.age_ms = 0


trait EntityType(Copyable, Deinitable):
    """A type of entity and the behaviour state of one entity of it (Go
    `EntityType` together with `EntityData.Data`)."""

    comptime IDENTIFIER: StaticString
    """The saved entity type, such as `minecraft:item` (Go
    `EncodeEntity`)."""

    def bbox(self, data: EntityData) -> BBox:
        """Returns the entity's bounding box (Go `BBox`)."""
        ...

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes the type's own fields to the entity's compound (Go
        `EncodeNBT`)."""
        ...

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads the type's own fields from the entity's compound (Go
        `DecodeNBT`)."""
        ...


trait NetworkEncodedEntity(EntityType):
    """An entity type shown to clients as another type (Dragonfly's
    `NetworkEncodeEntity`, which the session checks for)."""

    comptime NETWORK_IDENTIFIER: StaticString
    """The type sent to clients."""


@fieldwise_init
struct EntityMovement(Copyable, ImplicitlyCopyable, Writable):
    """The movement of an entity during a tick, which the world shows to the
    viewers of the entity's chunk (Go `entity.Movement` and its `Send`)."""

    var pos: Vec3
    """The new position."""
    var rot: Rotation
    """The new rotation."""
    var vel: Vec3
    """The new velocity."""
    var on_ground: Bool
    """Whether the entity is on the ground."""
    var moved: Bool
    """Whether the position or rotation changed (viewers get
    `view_entity_movement`)."""
    var vel_changed: Bool
    """Whether the velocity changed (viewers get `view_entity_velocity`)."""


trait TickerEntity(EntityType):
    """An entity that is ticked every tick (Go `TickerEntity`)."""

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Ticks the entity. The entity is taken out of the world while it
        ticks, so it can use the world freely; it changes its own state
        (`self`) and data directly."""
        ...


trait DamageableEntity(EntityType):
    """An entity that projectiles, explosions and the like can hurt (Go
    `entity.DamageableEntity`: a `Living` entity or a behaviour with
    `Hurt`). Hurting entities comes with living entities."""

    pass


trait ExplodableEntity(EntityType):
    """An entity an explosion affects (Go `block.ExplodableEntity` through
    the entity's behaviour)."""

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Applies an explosion at `src` with an impact of 0 to 1; returns
        True if the entity is destroyed (Go `Explode`)."""
        ...


trait EntityTypes:
    """The entity types a world knows, with dispatch of their behaviours.
    `EntitySet` is the implementation; a world names its set in
    `WorldTypes.Entities`."""

    comptime State: Copyable & Deinitable
    """The behaviour state of an entity of any of the types."""

    @staticmethod
    def identifier(s: Self.State) -> String:
        """Returns the saved type of an entity (Go `EncodeEntity`)."""
        ...

    @staticmethod
    def network_identifier(s: Self.State) -> String:
        """Returns the type an entity is shown to clients as."""
        ...

    @staticmethod
    def bbox(s: Self.State, data: EntityData) -> BBox:
        """Returns an entity's bounding box (Go `BBox`)."""
        ...

    @staticmethod
    def ticks(s: Self.State) -> Bool:
        """Reports whether an entity is a `TickerEntity`."""
        ...

    @staticmethod
    def damageable(s: Self.State) -> Bool:
        """Reports whether an entity is a `DamageableEntity`."""
        ...

    @staticmethod
    def explode(
        mut s: Self.State, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Applies an explosion to an `ExplodableEntity`; returns True if it
        is destroyed."""
        ...

    @staticmethod
    def tick[
        T: WorldTypes
    ](mut e: EntityHandle[Self], mut tx: World[T], current: Int64) -> Optional[
        EntityMovement
    ]:
        """Ticks an entity if its type is a `TickerEntity`."""
        ...

    @staticmethod
    def wrap[E: EntityType](var t: E) -> Self.State:
        """Wraps the state of an entity type in the set's state; does not
        compile if `E` is not in the set."""
        ...

    @staticmethod
    def try_wrap[E: EntityType](var t: E) -> Optional[Self.State]:
        """Wraps the state of an entity type, or returns None if `E` is not
        in the set (for blocks that spawn entities, such as falling
        blocks, in worlds of any entity set)."""
        ...

    @staticmethod
    def encode_nbt(
        s: Self.State, data: EntityData, mut tree: Tree, tag: Tag
    ) raises:
        """Writes an entity's type fields (Go `EncodeNBT`)."""
        ...

    @staticmethod
    def decode_nbt(
        identifier: String, tree: Tree, tag: Tag, mut data: EntityData
    ) raises -> Optional[Self.State]:
        """Reads an entity of the type with the identifier passed (Go
        `EntityRegistry.Lookup` and `DecodeNBT`)."""
        ...


struct EntitySet[*Ts: EntityType](EntityTypes):
    """Static dispatch over the entity types `Ts` (Go `EntityRegistry`)."""

    comptime State = Variant[*Self.Ts]
    """The state of an entity of any of `Ts`."""

    @staticmethod
    def identifier(s: Self.State) -> String:
        """Returns the saved type of an entity (Go `EncodeEntity`)."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            if s.isa[E]():
                return String(E.IDENTIFIER)
        return String()

    @staticmethod
    def network_identifier(s: Self.State) -> String:
        """Returns the type an entity is shown to clients as."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            if s.isa[E]():
                comptime if conforms_to(E, NetworkEncodedEntity):
                    return String(_network_identifier[E]())
                return String(E.IDENTIFIER)
        return String()

    @staticmethod
    def bbox(s: Self.State, data: EntityData) -> BBox:
        """Returns an entity's bounding box (Go `BBox`)."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            if s.isa[E]():
                return s[E].bbox(data)
        return BBox()

    @staticmethod
    def explode(
        mut s: Self.State, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Applies an explosion to an `ExplodableEntity`; returns True if it
        is destroyed."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            comptime if conforms_to(E, ExplodableEntity):
                if s.isa[E]():
                    return _explode[E](s[E], data, src, impact)
        return False

    @staticmethod
    def damageable(s: Self.State) -> Bool:
        """Reports whether an entity is a `DamageableEntity`."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            comptime if conforms_to(E, DamageableEntity):
                if s.isa[E]():
                    return True
        return False

    @staticmethod
    def ticks(s: Self.State) -> Bool:
        """Reports whether an entity is a `TickerEntity`."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            comptime if conforms_to(E, TickerEntity):
                if s.isa[E]():
                    return True
        return False

    @staticmethod
    def tick[
        T: WorldTypes
    ](mut e: EntityHandle[Self], mut tx: World[T], current: Int64) -> Optional[
        EntityMovement
    ]:
        """Ticks an entity if its type is a `TickerEntity`."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            comptime if conforms_to(E, TickerEntity):
                if e.state.isa[E]():
                    return _tick[E, T](e.state[E], e.id, e.data, tx, current)
        return None

    @staticmethod
    def wrap[E: EntityType](var t: E) -> Self.State:
        """Wraps the state of an entity type in the set's state; does not
        compile if `E` is not in the set."""
        return Self.State(t^)

    @staticmethod
    def try_wrap[E: EntityType](var t: E) -> Optional[Self.State]:
        """Wraps the state of an entity type, or returns None if `E` is not
        in the set."""
        comptime for i in range(len(Self.Ts)):
            comptime if Self.Ts[i] == E:
                return Self.State(rebind_var[Self.Ts[i]](t^))
        return None

    @staticmethod
    def encode_nbt(
        s: Self.State, data: EntityData, mut tree: Tree, tag: Tag
    ) raises:
        """Writes an entity's type fields (Go `EncodeNBT`)."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            if s.isa[E]():
                s[E].encode_nbt(data, tree, tag)
                return

    @staticmethod
    def decode_nbt(
        identifier: String, tree: Tree, tag: Tag, mut data: EntityData
    ) raises -> Optional[Self.State]:
        """Reads an entity of the type with the identifier passed (Go
        `EntityRegistry.Lookup` and `DecodeNBT`)."""
        comptime for i in range(len(Self.Ts)):
            comptime E = Self.Ts[i]
            if identifier == E.IDENTIFIER:
                return Self.State(E.decode_nbt(tree, tag, data))
        return None


def _network_identifier[E: NetworkEncodedEntity]() -> StaticString:
    return E.NETWORK_IDENTIFIER


def _tick[
    E: TickerEntity, T: WorldTypes
](
    mut s: E,
    id: UUID,
    mut data: EntityData,
    mut tx: World[T],
    current: Int64,
) -> Optional[EntityMovement]:
    return s.tick[T](id, data, tx, current)


@fieldwise_init
struct EntitySpawnOpts(Copyable, Defaultable):
    """Options for a new entity (Go `EntitySpawnOpts`)."""

    var position: Vec3
    """Where the entity spawns."""
    var rotation: Rotation
    """The entity's rotation."""
    var velocity: Vec3
    """The entity's initial velocity."""
    var id: UUID
    """The entity's UUID; leave nil to have the world assign one with only
    the last 8 bytes set, as Go does."""
    var name_tag: String
    """The entity's name tag."""

    def __init__(out self):
        """Creates options for an entity at the origin."""
        self.position = Vec3()
        self.rotation = Rotation()
        self.velocity = Vec3()
        self.id = UUID()
        self.name_tag = String()


struct EntityHandle[E: EntityTypes](Copyable):
    """The persistent identity and data of an entity (Go `EntityHandle`)."""

    var id: UUID
    """The entity's UUID (Go `UUID`)."""
    var data: EntityData
    """The data every entity has."""
    var state: Self.E.State
    """The type's behaviour state; its arm is the entity's type."""

    def __init__(out self, opts: EntitySpawnOpts, var state: Self.E.State):
        """Creates an entity (Go `EntitySpawnOpts.New`). Add it to a world
        with `World.add_entity`."""
        self.id = opts.id
        self.data = EntityData()
        self.data.pos = opts.position
        self.data.rot = opts.rotation
        self.data.vel = opts.velocity
        self.data.name = opts.name_tag
        self.state = state^

    def __init__(
        out self, id: UUID, var data: EntityData, var state: Self.E.State
    ):
        """Creates an entity from its parts."""
        self.id = id
        self.data = data^
        self.state = state^

    def uuid(self) -> UUID:
        """Returns the entity's UUID (Go `UUID`)."""
        return self.id

    def position(self) -> Vec3:
        """Returns the entity's position (Go `Entity.Position`)."""
        return self.data.pos

    def rotation(self) -> Rotation:
        """Returns the entity's rotation (Go `Entity.Rotation`)."""
        return self.data.rot

    def identifier(self) -> String:
        """Returns the entity's saved type (Go `Type().EncodeEntity()`)."""
        return Self.E.identifier(self.state)

    def bbox(self) -> BBox:
        """Returns the entity's bounding box (Go `Type().BBox(e)`)."""
        return Self.E.bbox(self.state, self.data)

    def encode_nbt(self) raises -> Tree:
        """Encodes the entity as it is saved with its chunk (Go
        `encodeNBT`, the type's `EncodeNBT` and `identifier`)."""
        var t = Tree()
        var root = t.root()
        _put_vec3(t, root, "Pos", self.data.pos)
        _put_vec3(t, root, "Motion", self.data.vel)
        _ = t.put_float(root, "Yaw", Float32(self.data.rot.yaw()))
        _ = t.put_float(root, "Pitch", Float32(self.data.rot.pitch()))
        _ = t.put_short(root, "Fire", Int16(self.data.fire_duration_ms // 50))
        _ = t.put_short(root, "Age", Int16(min(self.data.age_ms // 50, 32767)))
        _ = t.put_string(root, "NameTag", self.data.name)
        Self.E.encode_nbt(self.state, self.data, t, root)
        _ = t.put_string(root, "identifier", self.identifier())
        return t^

    @staticmethod
    def decode_nbt(id: Int64, tree: Tree) raises -> Optional[Self]:
        """Reads an entity saved with its chunk (Go `entityFromData`)."""
        var root = tree.root()
        if not tree.has(root, "identifier"):
            return None
        var identifier = tree.get_string(root, "identifier")
        var data = EntityData()
        data.pos = _read_vec3(tree, root, "Pos")
        data.vel = _read_vec3(tree, root, "Motion")
        data.rot = Rotation(
            Float64(_read_float(tree, root, "Yaw")),
            Float64(_read_float(tree, root, "Pitch")),
        )
        data.age_ms = Int(_read_short(tree, root, "Age")) * 50
        data.fire_duration_ms = Int(_read_short(tree, root, "Fire")) * 50
        if case .Some(n) = tree.get(root, "NameTag"):
            if tree.type_of(n) == TAG_STRING:
                data.name = tree.as_string(n)
        var state = Self.E.decode_nbt(identifier, tree, root, data)
        if not state:
            return None
        var bytes = List[UInt8](length=16, fill=0)
        var u = UInt64(id)
        for i in range(8):
            bytes[8 + i] = UInt8((u >> UInt64(8 * i)) & 0xFF)
        return Self(UUID(Span(bytes)), data^, state.take())

    def saved_id(self) -> Int64:
        """Returns the ID the entity is saved with: the last 8 bytes of its
        UUID, little endian."""
        var u = UInt64(0)
        for i in range(8):
            u |= UInt64(self.id.bytes[8 + i]) << UInt64(8 * i)
        return Int64(u)


def _put_vec3(mut t: Tree, tag: Tag, key: StringSpan, v: Vec3) raises:
    var l = t.put_list(tag, key, TAG_FLOAT)
    _ = t.append_float(l, Float32(v.x()))
    _ = t.append_float(l, Float32(v.y()))
    _ = t.append_float(l, Float32(v.z()))


def _read_vec3(t: Tree, tag: Tag, key: StringSpan) raises -> Vec3:
    """Go `readVec3`: a list of three floats, or zero."""
    if case .Some(l) = t.get(tag, key):
        if t.type_of(l) != TAG_LIST or t.length(l) != 3:
            return Vec3()
        if t.elem_type(l) != TAG_FLOAT:
            return Vec3()
        return Vec3(
            Float64(t.as_float(t.at(l, 0))),
            Float64(t.as_float(t.at(l, 1))),
            Float64(t.as_float(t.at(l, 2))),
        )
    return Vec3()


def _read_float(t: Tree, tag: Tag, key: StringSpan) raises -> Float32:
    if case .Some(v) = t.get(tag, key):
        if t.type_of(v) == TAG_FLOAT:
            return t.as_float(v)
    return 0


def _read_short(t: Tree, tag: Tag, key: StringSpan) raises -> Int16:
    if case .Some(v) = t.get(tag, key):
        if t.type_of(v) == TAG_SHORT:
            return t.as_short(v)
    return 0


def _explode[
    E: ExplodableEntity
](mut e: E, mut data: EntityData, src: Vec3, impact: Float64) -> Bool:
    return e.explode(data, src, impact)
