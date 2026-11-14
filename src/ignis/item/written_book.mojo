"""WrittenBook, ported from Dragonfly `server/item/written_book.go`.

Go's `DecodeNBT` panics on a page that is not a compound with a string
`text`; `decode_nbt` raises.
"""

from minecraft.nbt.nbt import TAG_BYTE, TAG_LIST, TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..world.block import NBTer
from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter
from .written_book_generation import WrittenBookGeneration


struct WrittenBook(Equatable, Item, MaxCounter, NBTer):
    """The item created when a book and quill is signed. It looks like a
    regular book, without the quill, and has an enchanted glint."""

    comptime BASE_HASH: UInt64 = item_hash("WrittenBook")
    """`item_hash("WrittenBook")`."""

    var title: String
    """The title of the book. Not hashed, like the other fields."""
    var author: String
    """The author of the book."""
    var generation: WrittenBookGeneration
    """The copy generation of the book."""
    var pages: List[String]
    """The pages of the book."""

    def __init__(
        out self,
        *,
        title: String = "",
        author: String = "",
        generation: WrittenBookGeneration = WrittenBookGeneration(),
        var pages: List[String] = [],
    ):
        """Creates the item; omitted fields take Go zero values."""
        self.title = title
        self.author = author
        self.generation = generation
        self.pages = pages^

    def __eq__(self, other: Self) -> Bool:
        """Compares two books field by field."""
        return (
            self.title == other.title
            and self.author == other.author
            and self.generation == other.generation
            and self.pages == other.pages
        )

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def total_pages(self) -> Int:
        """Returns the number of pages (Go `TotalPages`)."""
        return len(self.pages)

    def page(self, page: Int) -> Optional[String]:
        """Returns the text of a page, if it exists (Go `Page`)."""
        if page < 0 or len(self.pages) <= page:
            return None
        return self.pages[page]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the book's NBT (Go `EncodeNBT`)."""
        var l = tag.put_list(root, "pages")
        for p in self.pages:
            var c = tag.append_compound(l)
            _ = tag.put_string(c, "text", p)
        _ = tag.put_string(root, "author", self.author)
        _ = tag.put_string(root, "title", self.title)
        _ = tag.put_byte(root, "generation", self.generation.uint8())

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the book with its NBT decoded (Go `DecodeNBT`)."""
        var w = self.copy()
        if case .Some(l) = tag.get(root, "pages"):
            if tag.type_of(l) == TAG_LIST:
                w.pages = List[String]()
                for p in tag.children(l):
                    w.pages.append(tag.get_string(p, "text"))
        w.title = _string_or_empty(tag, root, "title")
        w.author = _string_or_empty(tag, root, "author")
        if case .Some(g) = tag.get(root, "generation"):
            if tag.type_of(g) == TAG_BYTE:
                var v = tag.as_byte(g)
                if v <= 2:
                    w.generation = WrittenBookGeneration(Int(v))
        return w^

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:written_book", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; no field is hashed."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash: an empty book."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]


def _string_or_empty(tag: Tree, root: Tag, key: StringSpan) raises -> String:
    """Go's `v, _ := data[key].(string)`."""
    if case .Some(t) = tag.get(root, key):
        if tag.type_of(t) == TAG_STRING:
            return tag.as_string(t)
    return ""
