"""Item tags, ported from Dragonfly `server/item/recipe/item_tag.go`.

Go decodes `item_tags.json` into a package global at `init`; here
`ItemTags` holds it and `new_item_tag` takes it.
"""

from std.collections import Dict

from ...internal.json import JSON_ARRAY, JSON_OBJECT, JsonDoc

comptime ITEM_TAGS_PATH = "resources/item_tags.json"
"""Where `item_tags.json` lives, relative to the repository root."""


struct ItemTags(Copyable, Defaultable):
    """The item names of every item tag (Go's `itemTags`)."""

    var _tags: Dict[String, List[String]]

    def __init__(out self):
        """Creates an empty tag table."""
        self._tags = Dict[String, List[String]]()

    @staticmethod
    def parse(data: Span[UInt8, _]) raises -> Self:
        """Reads `item_tags.json`: an object of tag names to item names."""
        var doc = JsonDoc(data)
        var root = doc.root()
        if doc.kind(root) != JSON_OBJECT:
            raise Error("item_tags.json: not an object")
        var out = Self()
        for t in doc.children(root):
            if doc.kind(t) != JSON_ARRAY:
                raise Error(t"item_tags.json: {doc.key(t)} is not an array")
            var names = List[String]()
            for n in doc.children(t):
                names.append(doc.as_string(n))
            out._tags[doc.key(t)] = names^
        return out^

    @staticmethod
    def load(path: String = ITEM_TAGS_PATH) raises -> Self:
        """Reads `item_tags.json` from disk."""
        var data: List[UInt8]
        with open(path, "r") as f:
            data = f.read_bytes()
        return Self.parse(Span(data))

    def items(self, tag: StringSlice) -> List[String]:
        """Returns the item names of a tag; empty for an unknown tag."""
        if case .Some(names) = self._tags.get(String(tag)):
            return names.copy()
        return List[String]()


@fieldwise_init
struct ItemTag(Copyable, Equatable, Writable):
    """A recipe item identified by a tag, such as `minecraft:planks` (Go
    `ItemTag`)."""

    var _tag: String
    var _count: Int
    var _items: List[String]

    def count(self) -> Int:
        """Returns the number of items required (Go `Count`)."""
        return self._count

    def empty(self) -> Bool:
        """Reports whether the tag requires nothing (Go `Empty`)."""
        return self._count == 0 or self._tag.byte_length() == 0

    def tag(self) -> String:
        """Returns the tag (Go `Tag`)."""
        return self._tag

    def contains(self, name: StringSlice) -> Bool:
        """Reports whether the tag holds the item named (Go `Contains`)."""
        for n in self._items:
            if n == name:
                return True
        return False

    def write_to(self, mut writer: Some[Writer]):
        """Writes the tag and count as `#tag*count`."""
        writer.write("#", self._tag, "*", self._count)


def new_item_tag(tags: ItemTags, tag: String, count: Int) -> ItemTag:
    """Creates an item tag (Go `NewItemTag`); a negative count becomes 0."""
    return ItemTag(tag, max(count, 0), tags.items(tag))
