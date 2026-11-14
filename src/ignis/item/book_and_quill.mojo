"""BookAndQuill, ported from Dragonfly `server/item/book_and_quill.go`.

Go panics on an invalid page; the page methods raise instead.
"""

from minecraft.nbt.nbt import TAG_COMPOUND, TAG_LIST, TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..world.block import NBTer
from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


struct BookAndQuill(Equatable, Item, MaxCounter, NBTer):
    """An item used to write written books."""

    comptime BASE_HASH: UInt64 = item_hash("BookAndQuill")
    """`item_hash("BookAndQuill")`."""

    var pages: List[String]
    """The pages of the book. Not hashed."""

    def __init__(out self, *, var pages: List[String] = []):
        """Creates the item; omitted fields take Go zero values."""
        self.pages = pages^

    def __eq__(self, other: Self) -> Bool:
        """Compares two books by pages."""
        return self.pages == other.pages

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def total_pages(self) -> Int:
        """Returns the number of pages (Go `TotalPages`)."""
        return len(self.pages)

    def page(self, page: Int) -> Optional[String]:
        """Returns the text of a page, if it exists (Go `Page`)."""
        if page < 0 or len(self.pages) <= page:
            return None
        return self.pages[page]

    def delete_page(self, page: Int) raises -> Self:
        """Returns the book without a page (Go `DeletePage`)."""
        if page < 0 or page >= 50:
            raise Error("invalid page number")
        if not self.page(page):
            raise Error("cannot delete nonexistent page")
        var b = self.copy()
        _ = b.pages.pop(page)
        return b^

    def insert_page(self, page: Int, text: String) raises -> Self:
        """Returns the book with a page inserted (Go `InsertPage`)."""
        if page < 0 or page >= 50:
            raise Error("invalid page number")
        if text.byte_length() > 256:
            raise Error("text longer then 256 bytes")
        if page > len(self.pages):
            raise Error("unable to insert page at invalid position")
        var b = self.copy()
        b.pages.insert(page, text)
        return b^

    def set_page(self, page: Int, text: String) raises -> Self:
        """Returns the book with a page's text set, adding empty pages up to
        it (Go `SetPage`)."""
        if page < 0 or page >= 50:
            raise Error("invalid page number")
        if text.byte_length() > 256:
            raise Error("text longer then 256 bytes")
        var b = self.copy()
        while len(b.pages) <= page:
            b.pages.append(String())
        b.pages[page] = text
        return b^

    def swap_pages(self, page_one: Int, page_two: Int) raises -> Self:
        """Returns the book with two pages swapped (Go `SwapPages`)."""
        if page_one < 0 or page_two < 0:
            raise Error("negative page number")
        if not self.page(max(page_one, page_two)):
            raise Error("invalid page number")
        var b = self.copy()
        b.pages.swap_elements(page_one, page_two)
        return b^

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the pages (Go `EncodeNBT`); nothing for an empty book."""
        if len(self.pages) == 0:
            return
        var l = tag.put_list(root, "pages")
        for p in self.pages:
            var c = tag.append_compound(l)
            _ = tag.put_string(c, "text", p)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the book with its pages appended (Go `DecodeNBT`)."""
        var b = self.copy()
        b.pages.extend(_read_pages(tag, root))
        return b^

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:writable_book", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the pages are not hashed."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash: an empty book."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]


def _read_pages(tag: Tree, root: Tag) raises -> List[String]:
    """Reads the `text` of each compound of the `pages` list, skipping
    entries that are not compounds holding a string."""
    var out = List[String]()
    if case .Some(l) = tag.get(root, "pages"):
        if tag.type_of(l) != TAG_LIST:
            return out^
        for p in tag.children(l):
            if tag.type_of(p) != TAG_COMPOUND:
                continue
            if case .Some(t) = tag.get(p, "text"):
                if tag.type_of(t) == TAG_STRING:
                    out.append(tag.as_string(t))
    return out^
