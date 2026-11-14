"""Dialogue buttons, ported from Dragonfly `server/player/dialogue/button.go`."""

from ...internal.gojson import JsonObject


@fieldwise_init
struct Button(Copyable, Equatable):
    """A button of an NPC dialogue (Go `dialogue.Button`)."""

    var text: String
    """The text on the button."""

    def marshal_json(self) -> String:
        """Returns the button's JSON: a command button activated by a
        click (Go `MarshalJSON`)."""
        var m = JsonObject()
        m.string("button_name", self.text)
        m.string("text", "")
        m.int("mode", 0)
        m.int("type", 1)
        return m.encode()
