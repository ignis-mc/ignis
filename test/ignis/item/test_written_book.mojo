from ignis.item.book_and_quill import BookAndQuill
from ignis.item.written_book import WrittenBook
from ignis.item.written_book_generation import WrittenBookGeneration
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_book_and_quill_pages() raises:
    var b = BookAndQuill().set_page(2, "c")
    assert_equal(b.total_pages(), 3)
    b = b.insert_page(0, "a").swap_pages(0, 3).delete_page(1)
    assert_equal(b.pages[0], "c")
    assert_equal(b.page(2).value(), "a")
    assert_true(not b.page(3))
    var empty = Tree()
    BookAndQuill().encode_nbt(empty, empty.root())
    assert_true(not empty.has(empty.root(), "pages"))
    var t = Tree()
    b.encode_nbt(t, t.root())
    assert_true(BookAndQuill().decode_nbt(t, t.root()) == b)


def test_written_book_nbt() raises:
    var w = WrittenBook(
        title="T",
        author="A",
        generation=WrittenBookGeneration.COPY,
        pages=["x", "y"],
    )
    var t = Tree()
    w.encode_nbt(t, t.root())
    assert_equal(Int(t.get_byte(t.root(), "generation")), 1)
    assert_true(WrittenBook().decode_nbt(t, t.root()) == w)
    assert_equal(String(WrittenBookGeneration.COPY), "copy of original")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
