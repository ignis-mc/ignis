"""Scoreboards, ported from Dragonfly
`server/player/scoreboard/scoreboard.go`.

Go's `Set` and `Remove` panic on an index outside 0 to 14; here they raise.
"""


struct Scoreboard(Copyable):
    """A sidebar with a title and up to 15 lines (Go
    `scoreboard.Scoreboard`)."""

    var _name: String
    var _lines: List[String]
    var _padding: Bool
    var _descending: Bool

    def __init__(out self, name: String):
        """Creates a scoreboard (Go `New`); the name is kept as given."""
        self._name = name
        self._lines = List[String]()
        self._padding = True
        self._descending = False

    def name(self) -> String:
        """Returns the title (Go `Name`)."""
        return self._name

    def write_string(mut self, s: String) raises -> Int:
        """Appends the lines of a string, split on newlines (Go
        `WriteString`); raises once 15 or more lines are held, after adding
        them."""
        var n = 0
        for line in s.split("\n"):
            self._lines.append(String(line))
            n += 1
        if len(self._lines) >= 15:
            raise Error(
                "write scoreboard: maximum of 15 lines of text exceeded"
            )
        return n

    def set(mut self, index: Int, s: String) raises:
        """Sets a line, adding empty lines up to it (Go `Set`)."""
        if index < 0 or index >= 15:
            raise Error(t"index out of range {index}")
        while len(self._lines) <= index:
            self._lines.append(String())
        var v = s
        for _ in range(2):
            if v.endswith("\n"):
                var trimmed = String(v[byte = : v.byte_length() - 1])
                v = trimmed^
        self._lines[index] = v^

    def remove(mut self, index: Int) raises:
        """Removes a line (Go `Remove`)."""
        if index < 0 or index >= 15:
            raise Error(t"index out of range {index}")
        _ = self._lines.pop(index)

    def remove_padding(mut self):
        """Stops padding lines with spaces (Go `RemovePadding`)."""
        self._padding = False

    def lines(self) -> List[String]:
        """Returns the lines as shown: padded with spaces to the title's
        width unless padding was removed, reversed if descending (Go
        `Lines`)."""
        var out = self._lines.copy()
        if self._padding:
            for ref line in out:
                var pad = self._name.byte_length() - line.byte_length() - 2
                if pad <= 0:
                    line = " " + line + " "
                    continue
                line = " " + line + String(" ") * pad
        if self._descending:
            out.reverse()
        return out^

    def descending(self) -> Bool:
        """Reports whether the lines are shown in descending order (Go
        `Descending`)."""
        return self._descending

    def set_descending(mut self):
        """Shows the lines in descending order (Go `SetDescending`)."""
        self._descending = True
