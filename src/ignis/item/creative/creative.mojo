"""The creative inventory, ported from Dragonfly
`server/item/creative/creative.go`.

Go's `RegisterGroup`/`RegisterItem` append to package globals; here they
are methods of a `Creative` value. `register_creative_items` reads
`creative_items.nbt` as Go's `registerCreativeItems` does, resolving items
through the block and item registries and the vanilla item sets.
Enchantments are added with `with_forced_enchantments`: the file only
enchants enchanted books, which Go's `WithEnchantments` never filters.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.nbt import (
    NETWORK_LITTLE_ENDIAN,
    TAG_BYTE,
    TAG_COMPOUND,
    TAG_INT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree

from ...block.register import VanillaBlocks
from ...world.block_registry import BasicBlockRegistry
from ...world.block_state import Properties, PropertyValue
from ...world.item import ItemRegistry, RegisteredItem
from ..enchantment.register import VanillaEnchantments
from ..register import VanillaBlockItems, VanillaItems
from ..stack import Enchantment, Stack
from .category import Category

comptime CREATIVE_ITEMS_PATH = "resources/creative_items.nbt"
"""Where `creative_items.nbt` lives, relative to the repository root."""


@fieldwise_init
struct Item(Copyable):
    """An item in the creative inventory and the group it is in (Go
    `creative.Item`)."""

    var stack: Stack
    """The stack shown."""
    var group: String
    """The name of the item's group; the first group of that name wins."""


@fieldwise_init
struct Group(Copyable):
    """A group of items in the creative inventory (Go `creative.Group`);
    one without name or icon does not group its contents."""

    var category: Category
    """The tab the group is shown in."""
    var name: String
    """The localised name, such as `itemGroup.name.planks`."""
    var icon: Stack
    """The item shown as the group's icon."""


struct Creative(Copyable, Defaultable):
    """The registered creative groups and items (Go's `creativeGroups` and
    `creativeItemStacks`)."""

    var _groups: List[Group]
    var _items: List[Item]

    def __init__(out self):
        """Creates an empty creative inventory."""
        self._groups = List[Group]()
        self._items = List[Item]()

    def groups(ref self) -> ref[self._groups] List[Group]:
        """Returns every registered group (Go `Groups`)."""
        return self._groups

    def register_group(mut self, var group: Group):
        """Registers a group (Go `RegisterGroup`)."""
        self._groups.append(group^)

    def items(ref self) -> ref[self._items] List[Item]:
        """Returns every registered item (Go `Items`)."""
        return self._items

    def register_item(mut self, var item: Item):
        """Registers an item (Go `RegisterItem`)."""
        self._items.append(item^)


def register_creative_items(
    data: Span[UInt8, _], br: BasicBlockRegistry, reg: ItemRegistry
) raises -> Creative:
    """Builds the creative inventory from `creative_items.nbt` (Go
    `registerCreativeItems`): every group, and every item that is registered
    here."""
    var tree = decode(data, NETWORK_LITTLE_ENDIAN)
    var root = tree.root()
    var c = Creative()
    var i = 0
    for g in tree.children(tree.get_list(root, "groups")):
        var name = tree.get_string(g, "name")
        if name.byte_length() == 0:
            name = String(t"anon{i}")
        var icon = _stack_from_entry(
            tree, tree.get_compound(g, "icon"), br, reg
        )
        c.register_group(
            Group(
                Category(UInt8(tree.get_int(g, "category"))),
                name^,
                icon^.or_else(Stack()),
            )
        )
        i += 1
    for e in tree.children(tree.get_list(root, "items")):
        var group_index = Int32(0)
        if tree.has(e, "group_index"):
            group_index = tree.get_int(e, "group_index")
        if Int(group_index) >= len(c._groups):
            raise Error(
                t"invalid group index {group_index} for item"
                t" {tree.get_string(e, 'name')}"
            )
        if case .Some(st) = _stack_from_entry(tree, e, br, reg):
            c.register_item(Item(st.copy(), c._groups[Int(group_index)].name))
    return c^


def load_creative_items(
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    path: String = CREATIVE_ITEMS_PATH,
) raises -> Creative:
    """Builds the creative inventory from a `creative_items.nbt` on disk."""
    var data: List[UInt8]
    with open(path, "r") as f:
        data = f.read_bytes()
    return register_creative_items(Span(data), br, reg)


def _sub_tree(tree: Tree, t: Tag) raises -> Tree:
    """Copies the compound `t` into a tree of its own."""
    var sub = Tree()
    for c in tree.children(t):
        _ = sub.put_tree(sub.root(), tree.name(c), tree, c)
    return sub^


def _properties(tree: Tree, t: Tag) raises -> Properties:
    var p = Properties()
    for c in tree.children(t):
        var key = tree.name(c)
        var tag = tree.type_of(c)
        if tag == TAG_BYTE:
            p.set(key^, PropertyValue(byte=tree.as_byte(c)))
        elif tag == TAG_INT:
            p.set(key^, PropertyValue(int32=tree.as_int(c)))
        elif tag == TAG_STRING:
            p.set(key^, PropertyValue(string=tree.as_string(c)))
        else:
            raise Error(t"creative item: property {key} has tag {tag}")
    return p^


def _stack_from_entry(
    tree: Tree, e: Tag, br: BasicBlockRegistry, reg: ItemRegistry
) raises -> Optional[Stack]:
    """Go `itemStackFromEntry`: the stack of an entry, or None if its item
    is not registered."""
    var name = tree.get_string(e, "name")
    var meta = Int16(0)
    if tree.has(e, "meta"):
        meta = tree.get_short(e, "meta")
    var found: Optional[RegisteredItem]
    var props = tree.get(e, "block_properties")
    if props and len(tree.children(props.value())) > 0:
        var rid = br.block_by_name(name, _properties(tree, props.value()))
        if not rid:
            return None
        found = VanillaBlocks.block_item(
            br.kind(rid.value()), br.state_hash(rid.value())
        )
    else:
        found = reg.item_by_name(name, meta)
        if found and reg.encode_item(found.value().item).value().meta != meta:
            return None
    if not found:
        return None
    var it = found.value().item
    var data = Tree()
    if case .Some(n) = tree.get(e, "nbt"):
        data = _sub_tree(tree, n)
    var st = Stack(found.value(), 1)
    var item_nbt: Optional[Tree]
    if it.block:
        item_nbt = VanillaBlockItems.item_nbt(it.kind, it.hash, data)
    else:
        item_nbt = VanillaItems.item_nbt(it.kind, it.hash, data)
    if case .Some(ref t) = item_nbt:
        st = st.with_item_nbt(t.copy())
    if case .Some(ench) = data.get(data.root(), "ench"):
        var enchants = List[Enchantment]()
        for v in data.children(ench):
            if data.type_of(v) != TAG_COMPOUND:
                continue
            var id = data.get_short(v, "id")
            if not VanillaEnchantments.contains(Int(id)):
                return None
            enchants.append(Enchantment(id, Int(data.get_short(v, "lvl"))))
        st = st.with_forced_enchantments(enchants)
    return st^
