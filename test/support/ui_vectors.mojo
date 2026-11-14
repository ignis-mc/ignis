"""The vectors `interop/ui/main.go` wrote: "key hex(value)" lines."""

from std.collections import Dict


def _unhex(s: StringSlice) raises -> List[UInt8]:
    var b = s.as_bytes()
    var out = List[UInt8](capacity=len(b) // 2)
    for i in range(0, len(b) - 1, 2):
        var hi = Int(b[i])
        var lo = Int(b[i + 1])
        hi = hi - 48 if hi <= 57 else hi - 87
        lo = lo - 48 if lo <= 57 else lo - 87
        out.append(UInt8(hi * 16 + lo))
    return out^


struct UIVectors(Movable):
    """The vectors, by key."""

    var _v: Dict[String, List[UInt8]]

    def __init__(out self) raises:
        self._v = Dict[String, List[UInt8]]()
        var text: String
        with open("test/data/ui/vectors.txt", "r") as f:
            text = f.read()
        for line in text.split("\n"):
            if line.byte_length() == 0:
                continue
            var sp = line.find(" ")
            self._v[String(line[byte=:sp])] = _unhex(line[byte = sp + 1 :])

    def has(self, key: String) -> Bool:
        return key in self._v

    def bytes(self, key: String) raises -> List[UInt8]:
        return self._v[key].copy()

    def str(self, key: String) raises -> String:
        return String(unsafe_from_utf8=self._v[key])

    def list(self, key: String) raises -> List[String]:
        """A value of "\\x1f"-separated strings."""
        var out = List[String]()
        var s = self.str(key)
        if s.byte_length() == 0:
            return out^
        for part in s.split("\x1f"):
            out.append(String(part))
        return out^
