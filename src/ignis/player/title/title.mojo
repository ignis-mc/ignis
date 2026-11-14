"""Titles, ported from Dragonfly `server/player/title/title.go`.

Durations are milliseconds (Go `time.Duration`).
"""


def _format(s: String) -> String:
    # Go `format`: Sprintln without its newline, dropping one more.
    if s.endswith("\n"):
        return String(s[byte = : s.byte_length() - 1])
    return s


struct Title(Copyable):
    """A title, subtitle and action bar text shown together (Go
    `title.Title`)."""

    var _text: String
    var _subtitle: String
    var _action_text: String
    var _fade_in_ms: Int
    var _fade_out_ms: Int
    var _duration_ms: Int

    def __init__(out self, text: String = ""):
        """Creates a title shown for 2 s with 50 ms fades (Go `New`)."""
        self._text = _format(text)
        self._subtitle = String()
        self._action_text = String()
        self._fade_in_ms = 50
        self._fade_out_ms = 50
        self._duration_ms = 2000

    def text(self) -> String:
        """Returns the title text (Go `Text`)."""
        return self._text

    def with_subtitle(self, text: String) -> Self:
        """Returns a copy with a subtitle (Go `WithSubtitle`)."""
        var t = self.copy()
        t._subtitle = _format(text)
        return t^

    def subtitle(self) -> String:
        """Returns the subtitle (Go `Subtitle`)."""
        return self._subtitle

    def with_action_text(self, text: String) -> Self:
        """Returns a copy with action bar text (Go `WithActionText`)."""
        var t = self.copy()
        t._action_text = _format(text)
        return t^

    def action_text(self) -> String:
        """Returns the action bar text (Go `ActionText`)."""
        return self._action_text

    def duration_ms(self) -> Int:
        """Returns how long the title stays (Go `Duration`)."""
        return self._duration_ms

    def with_duration_ms(self, d: Int) -> Self:
        """Returns a copy with the duration set (Go `WithDuration`)."""
        var t = self.copy()
        t._duration_ms = d
        return t^

    def with_fade_in_duration_ms(self, d: Int) -> Self:
        """Returns a copy with the fade-in set (Go `WithFadeInDuration`)."""
        var t = self.copy()
        t._fade_in_ms = d
        return t^

    def fade_in_duration_ms(self) -> Int:
        """Returns the fade-in duration (Go `FadeInDuration`)."""
        return self._fade_in_ms

    def with_fade_out_duration_ms(self, d: Int) -> Self:
        """Returns a copy with the fade-out set (Go `WithFadeOutDuration`)."""
        var t = self.copy()
        t._fade_out_ms = d
        return t^

    def fade_out_duration_ms(self) -> Int:
        """Returns the fade-out duration (Go `FadeOutDuration`)."""
        return self._fade_out_ms
