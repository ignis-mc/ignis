"""Block states, ported from Dragonfly `server/world/block_state.go`.

Go keeps a state's properties in a `map[string]any` whose values are `bool`,
`uint8`, `int32` or `string`. Here they are a `Properties` list sorted by key
with typed `PropertyValue`s; a Go `bool` is a byte, which is how both
`hashProperties` and the network block hash treat it.

Dragonfly's `hashProperties` key concatenates the property values without
their names or lengths, so two different property sets can collide (for
example `{a: "xy", b: ""}` and `{a: "x", b: "y"}`). `state_key` length-prefixes
names and values instead, so lookups only match the exact state.
"""

from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_INT, TAG_STRING
from minecraft.nbt.tree import Tag, Tree


struct PropertyValue(Copyable, Equatable, Writable):
    """The value of one block state property: a byte, an int32 or a string.

    Booleans are bytes 0 and 1, as in the NBT the game uses.
    """

    var tag: UInt8
    """The NBT tag of the value: `TAG_BYTE`, `TAG_INT` or `TAG_STRING`."""
    var int: Int32
    """The value of a byte or int32 property."""
    var string: String
    """The value of a string property."""

    def __init__(out self, *, byte: UInt8):
        """Creates a byte property value (Go `uint8`)."""
        self.tag = TAG_BYTE
        self.int = Int32(byte)
        self.string = String()

    def __init__(out self, *, bool: Bool):
        """Creates a boolean property value, stored as a byte (Go `bool`)."""
        self = PropertyValue(byte=UInt8(1) if bool else UInt8(0))

    def __init__(out self, *, int32: Int32):
        """Creates an int32 property value (Go `int32`)."""
        self.tag = TAG_INT
        self.int = int32
        self.string = String()

    def __init__(out self, *, var string: String):
        """Creates a string property value (Go `string`)."""
        self.tag = TAG_STRING
        self.int = 0
        self.string = string^

    def __eq__(self, other: Self) -> Bool:
        """Compares two values, including their type."""
        return (
            self.tag == other.tag
            and self.int == other.int
            and self.string == other.string
        )

    def as_bool(self) -> Bool:
        """Returns a byte value as a boolean."""
        return self.tag == TAG_BYTE and self.int != 0

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value as `b:1`, `i:5` or `s:north`."""
        if self.tag == TAG_BYTE:
            writer.write("b:", self.int)
        elif self.tag == TAG_INT:
            writer.write("i:", self.int)
        else:
            writer.write("s:", self.string)


@fieldwise_init
struct Property(Copyable, Equatable):
    """A named block state property."""

    var key: String
    """The property name, such as `minecraft:cardinal_direction`."""
    var value: PropertyValue
    """The property value."""


struct Properties(Copyable, Defaultable, Equatable, Sized, Writable):
    """The properties of a block state, sorted by key (Go `map[string]any`)."""

    var entries: List[Property]
    """The properties in ascending key order."""

    def __init__(out self):
        """Creates an empty property set (Go `nil` map)."""
        self.entries = List[Property]()

    def __len__(self) -> Int:
        """Returns the number of properties."""
        return len(self.entries)

    def set(mut self, var key: String, var value: PropertyValue):
        """Sets a property, replacing any value with the same key."""
        var i = 0
        while i < len(self.entries) and self.entries[i].key < key:
            i += 1
        if i < len(self.entries) and self.entries[i].key == key:
            self.entries[i].value = value^
            return
        self.entries.insert(i, Property(key^, value^))

    def with_bool(var self, var key: String, value: Bool) -> Self:
        """Returns the set with a boolean property added."""
        self.set(key^, PropertyValue(bool=value))
        return self^

    def with_byte(var self, var key: String, value: UInt8) -> Self:
        """Returns the set with a byte property added."""
        self.set(key^, PropertyValue(byte=value))
        return self^

    def with_int(var self, var key: String, value: Int32) -> Self:
        """Returns the set with an int32 property added."""
        self.set(key^, PropertyValue(int32=value))
        return self^

    def with_string(var self, var key: String, var value: String) -> Self:
        """Returns the set with a string property added."""
        self.set(key^, PropertyValue(string=value^))
        return self^

    def get(self, key: StringSlice) -> Optional[PropertyValue]:
        """Looks up a property."""
        for ref p in self.entries:
            if p.key == key:
                return p.value.copy()
        return None

    def contains(self, key: StringSlice) -> Bool:
        """Checks if a property is present."""
        for ref p in self.entries:
            if p.key == key:
                return True
        return False

    def __eq__(self, other: Self) -> Bool:
        """Compares two property sets."""
        return self.entries == other.entries

    def write_to(self, mut writer: Some[Writer]):
        """Writes the properties as `k=b:1,k2=s:x`, sorted by key."""
        for i in range(len(self.entries)):
            if i > 0:
                writer.write(",")
            writer.write(self.entries[i].key, "=", self.entries[i].value)


struct BlockState(Copyable, Equatable, Writable):
    """A block name and properties, together with a version."""

    var name: String
    """The block name, such as `minecraft:stone`."""
    var properties: Properties
    """The block state properties (Go `states`)."""
    var version: Int32
    """The block state version; 0 for states produced by `encode_block`."""

    def __init__(
        out self, var name: String, var properties: Properties = Properties()
    ):
        """Creates a block state with version 0."""
        self.name = name^
        self.properties = properties^
        self.version = 0

    def __init__(
        out self, var name: String, var properties: Properties, version: Int32
    ):
        """Creates a block state."""
        self.name = name^
        self.properties = properties^
        self.version = version

    def __eq__(self, other: Self) -> Bool:
        """Compares name and properties; the version is ignored."""
        return self.name == other.name and self.properties == other.properties

    def write_to(self, mut writer: Some[Writer]):
        """Writes the state as `name{k=b:1,...}`."""
        writer.write(self.name, "{", self.properties, "}")


def state_key(name: StringSlice, properties: Properties) -> String:
    """Returns the map key Dragonfly derives from a state (Go `stateHash`).

    Unlike Go's `hashProperties`, names and values are length-prefixed so
    distinct states never share a key.
    """
    var key = String(name)
    for ref p in properties.entries:
        key.write("\x00", p.key.byte_length(), ":", p.key)
        if p.value.tag == TAG_STRING:
            key.write("s", p.value.string.byte_length(), ":", p.value.string)
        elif p.value.tag == TAG_INT:
            key.write("i", p.value.int)
        else:
            key.write("b", p.value.int)
    return key^


def decode_block_state(tree: Tree) raises -> BlockState:
    """Reads a `{name, states, version}` compound (Go `BlockState` via NBT)."""
    var root = tree.root()
    var name = tree.get_string(root, "name")
    var version = Int32(0)
    if tree.has(root, "version"):
        version = tree.get_int(root, "version")
    var properties = Properties()
    if case .Some(states) = tree.get(root, "states"):
        if tree.type_of(states) != TAG_COMPOUND:
            raise Error(t"block state {name}: states is not a compound")
        properties = decode_properties(tree, states)
    return BlockState(name^, properties^, version)


def decode_properties(tree: Tree, states: Tag) raises -> Properties:
    """Reads a compound of block properties (bytes, ints and strings)."""
    var properties = Properties()
    for child in tree.children(states):
        var key = tree.name(child)
        var tag = tree.type_of(child)
        if tag == TAG_BYTE:
            properties.set(key^, PropertyValue(byte=tree.as_byte(child)))
        elif tag == TAG_INT:
            properties.set(key^, PropertyValue(int32=tree.as_int(child)))
        elif tag == TAG_STRING:
            properties.set(key^, PropertyValue(string=tree.as_string(child)))
        else:
            raise Error(t"block property {key} has tag {tag}")
    return properties^
