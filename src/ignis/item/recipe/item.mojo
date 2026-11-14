"""Recipe items, ported from Dragonfly `server/item/recipe/item.go`.

Go's `recipe.Item` interface is implemented by `item.Stack` and `ItemTag`;
here `Item` holds one of the two. Go marks an input whose metadata is
32767 (any variant) with the stack value `variants`; Ignis has no stack
values yet, so `Item` keeps the flag itself. `input_item` and
`output_item` decode the `inputItem` and `outputItem` entries of the recipe
data files.
"""

from minecraft.nbt.tree import Tag, Tree

from ...block.register import VanillaBlocks
from ...internal.nbtconv.read import get_int16, get_int32, get_string
from ...world.block_registry import BasicBlockRegistry
from ...world.block_state import Properties, decode_properties
from ...world.item import ItemRegistry, RegisteredItem
from ..register import VanillaBlockItems, VanillaItems
from ..stack import Stack, has_nbt
from .item_tag import ItemTag, ItemTags, new_item_tag

comptime VARIANTS_META: Int16 = 32767
"""The metadata that stands for every variant of an item (Go
`math.MaxInt16`)."""


struct Item(Copyable):
    """A recipe input: an item stack or an item tag (Go `recipe.Item`)."""

    var _stack: Stack
    var _tag: Optional[ItemTag]
    var _variants: Bool

    def __init__(out self, var stack: Stack, *, variants: Bool = False):
        """Creates an input of a stack; `variants` accepts any metadata."""
        self._stack = stack^
        self._tag = None
        self._variants = variants

    def __init__(out self, var tag: ItemTag):
        """Creates an input of every item with a tag."""
        self._stack = Stack()
        self._tag = tag^
        self._variants = False

    def count(self) -> Int:
        """Returns the number of items required (Go `Count`)."""
        if case .Some(ref t) = self._tag:
            return t.count()
        return self._stack.count()

    def empty(self) -> Bool:
        """Reports whether the input requires nothing (Go `Empty`)."""
        if case .Some(ref t) = self._tag:
            return t.empty()
        return self._stack.empty()

    def stack(self) -> Optional[Stack]:
        """Returns the stack, if the input is one (Go `i.(item.Stack)`)."""
        if self._tag:
            return None
        return self._stack.copy()

    def tag(self) -> Optional[ItemTag]:
        """Returns the tag, if the input is one (Go `i.(ItemTag)`)."""
        return self._tag.copy()

    def variants(self) -> Bool:
        """Reports whether any metadata matches (Go `Value("variants")`)."""
        return self._variants


def input_item(
    tree: Tree, t: Tag, reg: ItemRegistry, tags: ItemTags
) raises -> Optional[Item]:
    """Decodes an `inputItem` (Go `inputItem.Item`); None if its item is not
    registered."""
    var count = Int(get_int32(tree, t, "count"))
    var tag = get_string(tree, t, "tag")
    if tag.byte_length() != 0:
        return Item(new_item_tag(tags, tag, count))
    var meta = Int16(get_int32(tree, t, "meta"))
    var found = reg.item_by_name(get_string(tree, t, "name"), meta)
    if not found:
        return None
    return Item(Stack(found.value(), count), variants=meta == VARIANTS_META)


def input_items(
    tree: Tree, l: Tag, reg: ItemRegistry, tags: ItemTags
) raises -> Optional[List[Item]]:
    """Decodes a list of `inputItem`s (Go `inputItems.Items`); None if one
    of them is not registered."""
    var out = List[Item]()
    for e in tree.children(l):
        if case .Some(it) = input_item(tree, e, reg, tags):
            out.append(it.copy())
        else:
            return None
    return out^


def output_item(
    tree: Tree, t: Tag, br: BasicBlockRegistry, reg: ItemRegistry
) raises -> Optional[Stack]:
    """Decodes an `outputItem` (Go `outputItem.Stack`); None if its item is
    not registered."""
    var found: Optional[RegisteredItem] = None
    if case .Some(b) = tree.get(t, "block"):
        var name = get_string(tree, b, "name")
        if name.byte_length() != 0:
            var props = Properties()
            if case .Some(states) = tree.get(b, "states"):
                props = decode_properties(tree, states)
            var rid = br.block_by_name(name, props)
            if case .Some(r) = rid:
                found = VanillaBlocks.block_item(br.kind(r), br.state_hash(r))
    if not found:
        found = reg.item_by_name(
            get_string(tree, t, "name"), Int16(get_int32(tree, t, "meta"))
        )
    if not found:
        return None
    var it = found.value().item
    var st = Stack(found.value(), Int(get_int16(tree, t, "count")))
    if case .Some(d) = tree.get(t, "data"):
        var data = Tree()
        for c in tree.children(d):
            _ = data.put_tree(data.root(), tree.name(c), tree, c)
        if has_nbt(data):
            var nbt: Optional[Tree]
            if it.block:
                nbt = VanillaBlockItems.item_nbt(it.kind, it.hash, data)
            else:
                nbt = VanillaItems.item_nbt(it.kind, it.hash, data)
            if case .Some(ref n) = nbt:
                st = st.with_item_nbt(n.copy())
    return st^


def output_items(
    tree: Tree, l: Tag, br: BasicBlockRegistry, reg: ItemRegistry
) raises -> Optional[List[Stack]]:
    """Decodes a list of `outputItem`s (Go `outputItems.Stacks`); None if
    one of them is not registered."""
    var out = List[Stack]()
    for e in tree.children(l):
        if case .Some(s) = output_item(tree, e, br, reg):
            out.append(s.copy())
        else:
            return None
    return out^
