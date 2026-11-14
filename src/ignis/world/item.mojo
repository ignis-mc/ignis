"""Items and the item registry, ported from Dragonfly `server/world/item.go`.

Go's `world.Item` is an interface held as interface values. As with blocks
(see `block.mojo`), Ignis splits the two roles:

- Each item type is a struct conforming to `Item`. Code that knows the type
  works with it directly (`Stick()`, `Beef(cooked=True)`).
- An item of unknown type is an `AnyItem`: the type's `BASE_HASH` and the
  value's `hash()`, plus whether the type is a block. `item.get[T]()`
  replaces Go's `it.(T)`.

Go keeps the registered items and the runtime ID tables in package globals;
Ignis has no globals, so they live in an `ItemRegistry` value the server
builds once (`ignis.item.register.vanilla_item_registry`).

Not ported yet: `CustomItem` and custom item runtime IDs (they need the
resource pack builder), and the disk format of items.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import NBT, NETWORK_LITTLE_ENDIAN, TAG_COMPOUND
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.item import ItemEntry
from std.collections import Dict

from ..internal.fnv import fnv1a_64
from .block import Block


def item_hash(type_name: StaticString) -> UInt64:
    """Returns the base hash of an item type: FNV-1a 64 of its Go type name.

    Dragonfly has no item hashes; Ignis derives them from the type name so
    that they are stable and need no generated table. Use it as
    `comptime BASE_HASH: UInt64 = item_hash("Stick")`.

    Args:
        type_name: The name of the Go type, such as `"Stick"`.

    Returns:
        The hash.
    """
    return fnv1a_64(type_name.as_bytes())


@fieldwise_init
struct EncodedItem(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """An item's name and metadata value: the result of Go's `EncodeItem`
    and the key of Go's `itemHash`."""

    var name: String
    """The item name, such as `minecraft:stick`."""
    var meta: Int16
    """The metadata value, usually 0."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes the item as `name:meta`.

        Args:
            writer: The destination.
        """
        writer.write(self.name, ":", self.meta)


trait Item(Copyable, Deinitable):
    """An item that may be added to an inventory (Go `world.Item`).

    Conforming types must make `from_hash(it.hash()) == it` hold for every
    value they register. A block type that is also an item conforms to both
    `Block` and `Item`; the two traits share `BASE_HASH`, `hash` and
    `from_hash`.
    """

    comptime BASE_HASH: UInt64
    """The type's base hash, unique per type: `item_hash` of the Go type name
    for items, the block's `BASE_HASH` for blocks."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item to its name and metadata value (Go `EncodeItem`).

        Returns:
            The name and metadata value.
        """
        ...

    def hash(self) -> UInt64:
        """Returns a value that identifies the item among the values of its
        type.

        Returns:
            The hash.
        """
        ...

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from the value `hash` returned.

        Args:
            hash: A value previously returned by `hash`.

        Returns:
            The item.
        """
        ...

    @staticmethod
    def all_items() -> List[Self]:
        """Returns every value of the type registered as an item (the
        `world.RegisterItem` calls for the type in Go's `register.go`).

        Returns:
            The values, in Go's registration order.
        """
        ...


trait ItemHasher(Item):
    """An item whose identity holds more than its `hash`: a block whose item
    depends on block entity data, such as a banner's colour (Go compares
    the whole item value). `AnyItem` stores `item_hash` for these."""

    def item_hash(self) -> UInt64:
        """Returns the hash identifying the item among its type's items."""
        ...

    @staticmethod
    def from_item_hash(hash: UInt64) -> Self:
        """Rebuilds the item from the value `item_hash` returned."""
        ...


@fieldwise_init
struct AnyItem(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """An item whose type is only known at run time (Go: a `world.Item`
    interface value)."""

    var kind: UInt64
    """The `BASE_HASH` of the item's type."""
    var hash: UInt64
    """The value's `hash()`."""
    var block: Bool
    """Whether the type is a block type (Go: `it.(world.Block)` succeeds)."""

    @staticmethod
    def of[T: Item](it: T) -> AnyItem:
        """Wraps a typed item.

        Parameters:
            T: The item type.

        Args:
            it: The item.

        Returns:
            The item as an `AnyItem`.
        """
        comptime if conforms_to(T, ItemHasher):
            return AnyItem(T.BASE_HASH, _item_hash(it), conforms_to(T, Block))
        return AnyItem(T.BASE_HASH, it.hash(), conforms_to(T, Block))

    def is_a[T: Item](self) -> Bool:
        """Reports whether the item is of type `T` (Go `_, ok := it.(T)`).

        Parameters:
            T: The item type.

        Returns:
            True if the item's kind is `T.BASE_HASH`.
        """
        return self.kind == T.BASE_HASH

    def get[T: Item](self) -> Optional[T]:
        """Returns the item as a `T` (Go `it, ok := it.(T)`).

        Parameters:
            T: The item type.

        Returns:
            The item, or None if it is of another type.
        """
        if not self.is_a[T]():
            return None
        return from_any_hash[T](self.hash)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the kind and hash, for debugging.

        Args:
            writer: The destination.
        """
        writer.write("AnyItem(", self.kind, ", ", self.hash, ")")


@fieldwise_init
struct ItemInfo(Equatable, ImplicitlyCopyable, Writable):
    """What a `Stack` needs to know about its item type without knowing the
    type: Go asks the item through `MaxCounter` and `Durable`, Ignis computes
    the answers when the item is registered or the stack created
    (`ignis.item.item_info`)."""

    var max_count: Int
    """The maximum count of a stack of the item (Go `MaxCount`, default 64)."""
    var max_durability: Int
    """The item's `DurabilityInfo.MaxDurability`, or -1 if it is not
    `Durable`."""
    var persistent: Bool
    """Go `DurabilityInfo.Persistent`: the item cannot break."""
    var repairable: Bool
    """Whether the item is `Repairable` or an enchanted book: only those
    take an anvil cost (Go `WithAnvilCost`)."""
    var air: Bool
    """Whether the item encodes to `minecraft:air`: stacks of it are empty
    (Go `Stack.Empty`)."""

    def __init__(out self):
        """Creates the info of a plain item: 64 per stack, not durable."""
        self.max_count = 64
        self.max_durability = -1
        self.persistent = False
        self.repairable = False
        self.air = False

    def durable(self) -> Bool:
        """Reports whether the item has durability (Go `it.(Durable)`).

        Returns:
            True if `max_durability` is set.
        """
        return self.max_durability >= 0


@fieldwise_init
struct RegisteredItem(ImplicitlyCopyable, Writable):
    """An item found in the registry, with what stacks need to know about it."""

    var item: AnyItem
    """The item."""
    var info: ItemInfo
    """Its stack behaviour."""


@fieldwise_init
struct ItemRuntimeID(Equatable, ImplicitlyCopyable, Writable):
    """An item's network identity: what Go's `ItemRuntimeID` returns."""

    var runtime_id: Int32
    """The runtime ID of the item's name."""
    var meta: Int16
    """The metadata value."""


@fieldwise_init
struct VanillaItemEntry(Copyable):
    """One entry of `vanilla_items.nbt` (the value type Go's `server.go`
    decodes it into)."""

    var name: String
    """The item name."""
    var runtime_id: Int32
    """Go `RuntimeID`."""
    var component_based: Bool
    """Go `ComponentBased`."""
    var version: Int32
    """Go `Version`."""
    var data: Optional[Tree]
    """Go `Data`: the item's components, if the entry has a `data` field."""


struct ItemRegistry(Copyable, Defaultable):
    """The item runtime ID tables and the registered items (Go's
    `world/item.go` globals plus the item table of `server.go`)."""

    var _entries: List[VanillaItemEntry]
    var _names_to_rids: Dict[String, Int32]
    var _rids_to_names: Dict[Int32, String]
    var _items: Dict[EncodedItem, RegisteredItem]
    var _encoded: Dict[AnyItem, EncodedItem]
    var _order: List[AnyItem]

    def __init__(out self):
        """Creates a registry without runtime IDs or items."""
        self._entries = List[VanillaItemEntry]()
        self._names_to_rids = Dict[String, Int32]()
        self._rids_to_names = Dict[Int32, String]()
        self._items = Dict[EncodedItem, RegisteredItem]()
        self._encoded = Dict[AnyItem, EncodedItem]()
        self._order = List[AnyItem]()

    @staticmethod
    def from_vanilla_items(data: Span[UInt8, _]) raises -> Self:
        """Creates a registry holding the runtime IDs of a
        `vanilla_items.nbt` file (Go `world/item.go` `init`).

        Args:
            data: The file: one network little-endian compound mapping item
                names to `{runtime_id, component_based, version, data?}`.

        Returns:
            A registry without registered items.

        Raises:
            If the data is malformed or a name or runtime ID repeats.
        """
        var reg = Self()
        var tree = decode(data, NETWORK_LITTLE_ENDIAN)
        for e in tree.children(tree.root()):
            var name = tree.name(e)
            var rid = tree.get_int(e, "runtime_id")
            var component_based = False
            if tree.has(e, "component_based"):
                component_based = tree.get_bool(e, "component_based")
            var version = Int32(0)
            if tree.has(e, "version"):
                version = tree.get_int(e, "version")
            var entry_data: Optional[Tree] = None
            if case .Some(d) = tree.get(e, "data"):
                if tree.type_of(d) != TAG_COMPOUND:
                    raise Error(t"vanilla_items: data of {name} not compound")
                var sub = Tree()
                for c in tree.children(d):
                    _ = sub.put_tree(sub.root(), tree.name(c), tree, c)
                entry_data = sub^
            if name in reg._names_to_rids or rid in reg._rids_to_names:
                raise Error(t"vanilla_items: duplicate {name} / {rid}")
            reg._names_to_rids[name] = rid
            reg._rids_to_names[rid] = name
            reg._entries.append(
                VanillaItemEntry(
                    name, rid, component_based, version, entry_data^
                )
            )
        return reg^

    @staticmethod
    def load(path: String) raises -> Self:
        """Creates a registry from a `vanilla_items.nbt` file on disk.

        Args:
            path: The path of the file.

        Returns:
            A registry without registered items.

        Raises:
            If the file cannot be read or is malformed.
        """
        var data: List[UInt8]
        with open(path, "r") as f:
            data = f.read_bytes()
        return Self.from_vanilla_items(Span(data))

    def register_item[T: Item](mut self, it: T, info: ItemInfo) raises:
        """Registers an item so that it can be found by name and runtime ID
        (Go `RegisterItem`).

        Parameters:
            T: The item type.

        Args:
            it: The item.
            info: Its stack behaviour.

        Raises:
            If an item with the same name and metadata is registered, or the
            name has no runtime ID (Go panics in both cases).
        """
        var enc = it.encode_item()
        if enc in self._items:
            raise Error(
                t"item registered with name {enc.name} and meta {enc.meta}"
                t" already exists"
            )
        if enc.name not in self._names_to_rids:
            raise Error(t"item name {enc.name} does not have a runtime ID")
        var any = AnyItem.of(it)
        self._items[enc] = RegisteredItem(any, info)
        self._encoded[any] = enc
        self._order.append(any)

    def item_by_name(
        self, name: StringSlice, meta: Int16
    ) -> Optional[RegisteredItem]:
        """Looks up a registered item by name and metadata value (Go
        `ItemByName`), falling back to metadata 0 for items with durability.

        Args:
            name: The item name.
            meta: The metadata value.

        Returns:
            The item, or None if neither key is registered.
        """
        if case .Some(it) = self._items.get(EncodedItem(String(name), meta)):
            return it
        return self._items.get(EncodedItem(String(name), 0))

    def item_runtime_id[T: Item](self, it: T) -> Optional[ItemRuntimeID]:
        """Returns the runtime ID and metadata of an item (Go
        `ItemRuntimeID`). The item need not be registered; only its name
        must have a runtime ID.

        Parameters:
            T: The item type.

        Args:
            it: The item.

        Returns:
            The runtime ID and metadata, or None if the name is unknown.
        """
        return self._runtime_id(it.encode_item())

    def any_item_runtime_id(self, it: AnyItem) -> Optional[ItemRuntimeID]:
        """Returns the runtime ID and metadata of a registered item of
        unknown type.

        Args:
            it: The item.

        Returns:
            The runtime ID and metadata, or None if the item is not
            registered.
        """
        if case .Some(enc) = self._encoded.get(it):
            return self._runtime_id(enc)
        return None

    def _runtime_id(self, enc: EncodedItem) -> Optional[ItemRuntimeID]:
        if case .Some(rid) = self._names_to_rids.get(enc.name):
            return ItemRuntimeID(rid, enc.meta)
        return None

    def encode_item(self, it: AnyItem) -> Optional[EncodedItem]:
        """Returns the name and metadata of a registered item of unknown
        type (Go `it.EncodeItem()`).

        Args:
            it: The item.

        Returns:
            The name and metadata, or None if the item is not registered.
        """
        return self._encoded.get(it)

    def item_by_runtime_id(
        self, rid: Int32, meta: Int16
    ) -> Optional[RegisteredItem]:
        """Looks up a registered item by runtime ID and metadata (Go
        `ItemByRuntimeID`), falling back to metadata 0.

        Args:
            rid: The runtime ID.
            meta: The metadata value.

        Returns:
            The item, or None if none is registered.
        """
        if case .Some(name) = self._rids_to_names.get(rid):
            return self.item_by_name(name, meta)
        return None

    def runtime_id(self, name: StringSlice) -> Optional[Int32]:
        """Returns the runtime ID of an item name.

        Args:
            name: The item name.

        Returns:
            The runtime ID, or None if the name is unknown.
        """
        return self._names_to_rids.get(String(name))

    def items(self) -> List[AnyItem]:
        """Returns every registered item, in registration order (Go
        `Items`, whose order is random).

        Returns:
            The items.
        """
        return self._order.copy()

    def vanilla_entries(
        ref self,
    ) -> ref[self._entries] List[VanillaItemEntry]:
        """Returns the entries of `vanilla_items.nbt`, in file order.

        Returns:
            The entries.
        """
        return self._entries

    def item_entries(self) raises -> List[ItemEntry]:
        """Returns the item table for StartGame (Go `Server.itemEntries`).

        Go builds the list from a map, so its order is random; Ignis keeps
        the file order. An entry without data carries an empty compound, as
        gophertunnel writes a nil map.

        Returns:
            One entry per vanilla item.

        Raises:
            If item data cannot be encoded.
        """
        var out = List[ItemEntry](capacity=len(self._entries))
        for ref e in self._entries:
            var entry = ItemEntry()
            entry.name = e.name
            entry.runtime_id = Int16(e.runtime_id)
            entry.component_based = e.component_based
            entry.version = e.version
            if case .Some(ref d) = e.data:
                entry.data = to_nbt(d, NETWORK_LITTLE_ENDIAN)
            else:
                entry.data = NBT.empty_compound()
            out.append(entry^)
        return out^


def from_any_hash[T: Item](hash: UInt64) -> T:
    """Rebuilds an item from an `AnyItem.hash`: `from_item_hash` for an
    `ItemHasher`, `from_hash` otherwise."""
    comptime if conforms_to(T, ItemHasher):
        return _from_item_hash[T](hash)
    return T.from_hash(hash)


def _item_hash[T: ItemHasher](it: T) -> UInt64:
    return it.item_hash()


def _from_item_hash[T: ItemHasher](hash: UInt64) -> T:
    return T.from_item_hash(hash)
