"""Chats, ported from Dragonfly `server/player/chat/chat.go`.

Go's `chat.Global` is a package variable that players write into from any
goroutine, holding subscribers behind an interface. Ignis has no globals
and no interface values: the server owns its `Chat`, which records the
UUIDs of its subscribers, and writing to it hands each subscriber's message
to a `Delivery` the caller provides (the server, which owns the sessions).
"""

from minecraft.protocol.uuid import UUID

from .translate import Translation


trait Delivery:
    """Delivers chat messages to subscribers by UUID (Go `Subscriber.Message`
    and `Translator.Messaget`)."""

    def message(mut self, subscriber: UUID, message: String):
        """Sends a message to a subscriber."""
        ...

    def messaget(
        mut self, subscriber: UUID, t: Translation, args: List[String]
    ) raises -> Bool:
        """Sends a translation to a subscriber that translates messages
        itself, returning False if it does not (Go: not a `Translator`)."""
        ...


struct Chat(Defaultable, Movable):
    """A chat that subscribers receive every message of (Go `chat.Chat`)."""

    var _subscribers: List[UUID]

    def __init__(out self):
        """Creates a chat without subscribers (Go `New`)."""
        self._subscribers = List[UUID]()

    def write_string[D: Delivery](mut self, s: String, mut d: D):
        """Sends a message to every subscriber (Go `WriteString`)."""
        for id in self._subscribers:
            d.message(id, s)

    def writet[
        D: Delivery
    ](mut self, t: Translation, args: List[String], mut d: D) raises:
        """Sends a translation to every subscriber, as a translation to those
        that translate and as English text to the others (Go `Writet`)."""
        var fallback = t.f(args.copy()).string()
        for id in self._subscribers:
            if not d.messaget(id, t, args):
                d.message(id, fallback)

    def subscribe(mut self, id: UUID):
        """Adds a subscriber (Go `Subscribe`)."""
        if not self.subscribed(id):
            self._subscribers.append(id)

    def subscribed(self, id: UUID) -> Bool:
        """Reports whether a subscriber is subscribed (Go `Subscribed`)."""
        for s in self._subscribers:
            if s == id:
                return True
        return False

    def unsubscribe(mut self, id: UUID):
        """Removes a subscriber (Go `Unsubscribe`)."""
        for i in range(len(self._subscribers)):
            if self._subscribers[i] == id:
                _ = self._subscribers.pop(i)
                return

    def close(mut self):
        """Removes every subscriber (Go `Close`)."""
        self._subscribers.clear()

    def subscribers(self) -> List[UUID]:
        """Returns the subscribers in the order they subscribed."""
        return self._subscribers.copy()
