"""Block state upgrading, ported from `df-mc/worldupgrader` v1.0.22
`blockupgrader/` (`upgrader.go`, `schema.go`, `model.go`, `registry.go`).

The upgrade schemas are the JSON files of that package, copied unchanged
to `resources/worldupgrader/blockupgrader/schemas/` and applied in file
name order, as Go's `embed.FS.ReadDir` returns them. A state is passed
through every schema whose version is not older than the state's.

Go keeps properties in maps and mutates the caller's map in place; here a
state's `Properties` are copied, so the input is never modified. Where Go
iterates a map (renamed and remapped properties) the JSON order is used;
no schema depends on the order.
"""

from std.collections import Dict

from ..internal.fs import join, list_dir, read_file
from ..internal.json import JSON_OBJECT, JsonDoc
from ..world.block_state import BlockState, Properties, Property, PropertyValue

comptime SCHEMA_DIR = "resources/worldupgrader/blockupgrader/schemas"
"""Where the upgrade schemas are, relative to the working directory."""


@fieldwise_init
struct _FlattenInfo(Copyable, Defaultable):
    var prefix: String
    var flattened_property: String
    var suffix: String
    var value_remaps: Dict[String, String]
    var property_type: String

    def __init__(out self):
        self.prefix = String()
        self.flattened_property = String()
        self.suffix = String()
        self.value_remaps = Dict[String, String]()
        self.property_type = String()


@fieldwise_init
struct _BlockRemap(Copyable):
    var old_properties: Properties
    var new_name: String
    var new_flattened_name: _FlattenInfo
    var new_properties: Properties
    var copied_properties: List[String]


@fieldwise_init
struct _ValueRemap(Copyable):
    var old: PropertyValue
    var new: PropertyValue


@fieldwise_init
struct _PropertyRemaps(Copyable):
    var property: String
    var remaps: List[_ValueRemap]


struct Schema(Copyable):
    """One upgrade schema (Go `schema`)."""

    var id: Int32
    """The version the schema upgrades to, as big-endian bytes
    `major.minor.patch.revision`."""
    var _renamed_ids: Dict[String, String]
    var _added_properties: Dict[String, Properties]
    var _removed_properties: Dict[String, List[String]]
    var _renamed_properties: Dict[String, List[Tuple[String, String]]]
    var _flattened_properties: Dict[String, _FlattenInfo]
    var _remapped_property_values: Dict[String, List[_PropertyRemaps]]
    var _remapped_states: Dict[String, List[_BlockRemap]]

    def __init__(out self, doc: JsonDoc) raises:
        """Parses a schema (Go `parseSchemaModel`)."""
        var r = doc.root()
        var major = Int32(doc.as_int(doc.get(r, "maxVersionMajor").value()))
        var minor = Int32(doc.as_int(doc.get(r, "maxVersionMinor").value()))
        var patch = Int32(doc.as_int(doc.get(r, "maxVersionPatch").value()))
        var rev = Int32(doc.as_int(doc.get(r, "maxVersionRevision").value()))
        self.id = (major << 24) | (minor << 16) | (patch << 8) | rev
        self._renamed_ids = Dict[String, String]()
        self._added_properties = Dict[String, Properties]()
        self._removed_properties = Dict[String, List[String]]()
        self._renamed_properties = Dict[String, List[Tuple[String, String]]]()
        self._flattened_properties = Dict[String, _FlattenInfo]()
        self._remapped_property_values = Dict[String, List[_PropertyRemaps]]()
        self._remapped_states = Dict[String, List[_BlockRemap]]()

        if case .Some(o) = doc.get(r, "renamedIds"):
            for c in doc.children(o):
                self._renamed_ids[doc.key(c)] = doc.as_string(c)
        if case .Some(o) = doc.get(r, "addedProperties"):
            for c in doc.children(o):
                self._added_properties[doc.key(c)] = _parse_properties(doc, c)
        if case .Some(o) = doc.get(r, "removedProperties"):
            for c in doc.children(o):
                var names = List[String]()
                for n in doc.children(c):
                    names.append(doc.as_string(n))
                self._removed_properties[doc.key(c)] = names^
        if case .Some(o) = doc.get(r, "renamedProperties"):
            for c in doc.children(o):
                var pairs = List[Tuple[String, String]]()
                for p in doc.children(c):
                    pairs.append((doc.key(p), doc.as_string(p)))
                self._renamed_properties[doc.key(c)] = pairs^
        if case .Some(o) = doc.get(r, "flattenedProperties"):
            for c in doc.children(o):
                self._flattened_properties[doc.key(c)] = _parse_flatten(doc, c)
        var index = Dict[String, List[_ValueRemap]]()
        if case .Some(o) = doc.get(r, "remappedPropertyValuesIndex"):
            for c in doc.children(o):
                var remaps = List[_ValueRemap]()
                for p in doc.children(c):
                    remaps.append(
                        _ValueRemap(
                            _parse_tag(doc, doc.get(p, "old").value()),
                            _parse_tag(doc, doc.get(p, "new").value()),
                        )
                    )
                index[doc.key(c)] = remaps^
        if case .Some(o) = doc.get(r, "remappedPropertyValues"):
            for c in doc.children(o):
                var props = List[_PropertyRemaps]()
                for p in doc.children(c):
                    var key = doc.as_string(p)
                    if key not in index:
                        raise Error(
                            t"missing key from schema values index: {key}"
                        )
                    props.append(_PropertyRemaps(doc.key(p), index[key].copy()))
                self._remapped_property_values[doc.key(c)] = props^
        if case .Some(o) = doc.get(r, "remappedStates"):
            for c in doc.children(o):
                var remaps = List[_BlockRemap]()
                for m in doc.children(c):
                    var old_props = Properties()
                    if case .Some(x) = doc.get(m, "oldState"):
                        if doc.kind(x) == JSON_OBJECT:
                            old_props = _parse_properties(doc, x)
                    var new_props = Properties()
                    if case .Some(x) = doc.get(m, "newState"):
                        if doc.kind(x) == JSON_OBJECT:
                            new_props = _parse_properties(doc, x)
                    var new_name = String()
                    if case .Some(x) = doc.get(m, "newName"):
                        new_name = doc.as_string(x)
                    var flat = _FlattenInfo()
                    if case .Some(x) = doc.get(m, "newFlattenedName"):
                        if doc.kind(x) == JSON_OBJECT:
                            flat = _parse_flatten(doc, x)
                    var copied = List[String]()
                    if case .Some(x) = doc.get(m, "copiedState"):
                        for n in doc.children(x):
                            copied.append(doc.as_string(n))
                    remaps.append(
                        _BlockRemap(
                            old_props^, new_name^, flat^, new_props^, copied^
                        )
                    )
                self._remapped_states[doc.key(c)] = remaps^

    def _locate_new_value(
        self, old_name: String, old_prop: String, old_val: PropertyValue
    ) raises -> PropertyValue:
        # Go schema.locateNewPropertyValue.
        if old_name in self._remapped_property_values:
            for ref pr in self._remapped_property_values[old_name]:
                if pr.property == old_prop:
                    for ref pair in pr.remaps:
                        if pair.old == old_val:
                            return pair.new.copy()
        return old_val.copy()


def _parse_tag(doc: JsonDoc, i: Int) raises -> PropertyValue:
    # Go parseModelTag: {"byte": n}, {"int": n} or {"string": s}.
    if case .Some(v) = doc.get(i, "byte"):
        return PropertyValue(byte=UInt8(doc.as_int(v)))
    if case .Some(v) = doc.get(i, "int"):
        return PropertyValue(int32=Int32(doc.as_int(v)))
    if case .Some(v) = doc.get(i, "string"):
        return PropertyValue(string=doc.as_string(v))
    raise Error("invalid tag in upgrade schema")


def _parse_properties(doc: JsonDoc, i: Int) raises -> Properties:
    var p = Properties()
    for c in doc.children(i):
        p.set(doc.key(c), _parse_tag(doc, c))
    return p^


def _parse_flatten(doc: JsonDoc, i: Int) raises -> _FlattenInfo:
    var f = _FlattenInfo()
    if case .Some(x) = doc.get(i, "prefix"):
        f.prefix = doc.as_string(x)
    if case .Some(x) = doc.get(i, "flattenedProperty"):
        f.flattened_property = doc.as_string(x)
    if case .Some(x) = doc.get(i, "suffix"):
        f.suffix = doc.as_string(x)
    if case .Some(x) = doc.get(i, "flattenedPropertyType"):
        f.property_type = doc.as_string(x)
    if case .Some(x) = doc.get(i, "flattenedValueRemaps"):
        for c in doc.children(x):
            f.value_remaps[doc.key(c)] = doc.as_string(c)
    return f^


def _remove(mut p: Properties, key: StringSlice) -> Bool:
    for i in range(len(p.entries)):
        if p.entries[i].key == key:
            _ = p.entries.pop(i)
            return True
    return False


def _apply_flattened(
    info: _FlattenInfo, old_name: String, var properties: Properties
) -> Tuple[String, Properties]:
    # Go schema.applyPropertyFlattened.
    var embed_key = String()
    var t = info.property_type
    if t == "":
        t = "string"
    if case .Some(v) = properties.get(info.flattened_property):
        if t == "string" and v.tag == PropertyValue(string="").tag:
            embed_key = v.string
        elif t == "int" and v.tag == PropertyValue(int32=0).tag:
            embed_key = String(v.int)
        elif t == "byte" and v.tag == PropertyValue(byte=0).tag:
            embed_key = String(v.int)
    if embed_key == "":
        return (old_name, properties^)
    _ = _remove(properties, info.flattened_property)
    var embed_value = info.value_remaps.get(embed_key).or_else(embed_key)
    return (info.prefix + embed_value + info.suffix, properties^)


struct BlockUpgrader(Movable):
    """The registered schemas and the upgrade algorithm (Go package
    `blockupgrader`)."""

    var schemas: List[Schema]
    """The schemas in the order they are applied."""

    def __init__(out self):
        """Creates an upgrader without schemas; `upgrade` returns its input."""
        self.schemas = List[Schema]()

    @staticmethod
    def load(dir: StringSlice = SCHEMA_DIR) raises -> Self:
        """Loads every `.json` schema of a directory in file name order (Go
        `init` of `registry.go`)."""
        var names = List[String]()
        for n in list_dir(dir):
            if n.endswith(".json"):
                names.append(n)
        sort(names)
        var u = Self()
        for n in names:
            u.register_schema(Span(read_file(join(dir, n))))
        return u^

    def register_schema(mut self, data: Span[mut=False, UInt8, _]) raises:
        """Parses and appends a schema (Go `RegisterSchema`)."""
        self.schemas.append(Schema(JsonDoc(data)))

    def upgrade(self, state: BlockState) raises -> BlockState:
        """Upgrades a block state to the newest schema (Go `Upgrade` of a
        `BlockState`)."""
        var cur = state.copy()
        var version = state.version
        for ref s in self.schemas:
            var res_version = s.id
            if version > res_version:
                continue
            var old_name = cur.name
            var old_properties = cur.properties.copy()
            if old_name in s._remapped_states:
                var next_schema = False
                for ref remap in s._remapped_states[old_name]:
                    if len(remap.old_properties) > len(old_properties):
                        continue
                    var matches = True
                    for ref p in remap.old_properties.entries:
                        var v = old_properties.get(p.key)
                        if not v or v.value() != p.value:
                            matches = False
                            break
                    if not matches:
                        continue
                    var new_properties = remap.new_properties.copy()
                    for k in remap.copied_properties:
                        if case .Some(v) = old_properties.get(k):
                            new_properties.set(k, v.copy())
                    var new_name = remap.new_name
                    if new_name == "":
                        new_name = _apply_flattened(
                            remap.new_flattened_name,
                            old_name,
                            old_properties.copy(),
                        )[0]
                    cur = BlockState(new_name^, new_properties^, res_version)
                    next_schema = True
                    break
                if next_schema:
                    continue
            var properties = cur.properties.copy()
            var renamed = s._renamed_ids.get(old_name)
            var flattened = old_name in s._flattened_properties
            var name: String
            if renamed and flattened:
                raise Error(
                    t"both renamedIds and flattenedProperties are set the for"
                    t" the same block ID \"{old_name}\" - don't know what to do"
                )
            elif flattened:
                var r = _apply_flattened(
                    s._flattened_properties[old_name], old_name, properties^
                )
                name = r[0]
                properties = r[1].copy()
            elif renamed:
                name = renamed.value()
            else:
                name = old_name
            var modified = Bool(renamed) or flattened
            if case .Some(added) = s._added_properties.get(old_name):
                for ref p in added.entries:
                    if not properties.get(p.key):
                        properties.set(p.key, p.value.copy())
                        modified = True
            if case .Some(removed) = s._removed_properties.get(old_name):
                for k in removed:
                    if _remove(properties, k):
                        modified = True
            if old_name in s._renamed_properties:
                for ref pair in s._renamed_properties[old_name]:
                    if case .Some(v) = properties.get(pair[0]):
                        _ = _remove(properties, pair[0])
                        modified = True
                        properties.set(
                            pair[1], s._locate_new_value(old_name, pair[0], v)
                        )
            if old_name in s._remapped_property_values:
                for ref pr in s._remapped_property_values[old_name]:
                    if case .Some(v) = properties.get(pr.property):
                        var nv = s._locate_new_value(old_name, pr.property, v)
                        if nv != v:
                            properties.set(pr.property, nv^)
                            modified = True
            if modified:
                cur = BlockState(name^, properties^, res_version)
        return cur^
