from ignis.player.chat import Chat, Delivery, Translation, message_join
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true


struct Log(Delivery):
    var lines: List[String]
    var translator: UUID

    def __init__(out self, translator: UUID):
        self.lines = List[String]()
        self.translator = translator

    def message(mut self, subscriber: UUID, message: String):
        self.lines.append(String(t"{subscriber}: {message}"))

    def messaget(
        mut self, subscriber: UUID, t: Translation, args: List[String]
    ) raises -> Bool:
        if subscriber != self.translator:
            return False
        self.lines.append(String(t"{subscriber}: t {t.str}"))
        return True


def test_chat_delivers_to_subscribers() raises:
    var a = UUID.from_random(Span(List[UInt8](length=16, fill=1)))
    var b = UUID.from_random(Span(List[UInt8](length=16, fill=2)))
    var c = Chat()
    c.subscribe(a)
    c.subscribe(b)
    c.subscribe(a)
    assert_equal(len(c.subscribers()), 2)
    var log = Log(b)
    c.write_string("hi", log)
    c.writet(message_join(), ["Steve"], log)
    assert_equal(len(log.lines), 4)
    assert_equal(log.lines[0], String(t"{a}: hi"))
    assert_true(log.lines[2].endswith("Steve joined the game§r"))
    assert_equal(log.lines[3], String(t"{b}: t %multiplayer.player.joined"))
    c.unsubscribe(a)
    assert_false(c.subscribed(a))
    c.close()
    assert_equal(len(c.subscribers()), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
