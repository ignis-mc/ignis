"""Chat subscribers, ported from Dragonfly `server/player/chat/subscriber.go`.

Go's `Subscriber` and `Translator` interfaces are a `Delivery` (see
`chat.mojo`); this module keeps Go's `StdoutSubscriber` as a function.
"""

from ...text import ansi


def stdout_message(message: String):
    """Prints a chat message to stdout with ANSI colours (Go
    `StdoutSubscriber.Message`)."""
    var t = ansi(message)
    if t.endswith("\n"):
        print(t, end="")
    else:
        print(t)
