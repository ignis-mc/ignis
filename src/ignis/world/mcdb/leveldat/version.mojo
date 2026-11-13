"""The `level.dat` storage version, ported from Dragonfly
`server/world/mcdb/leveldat/version.go`."""

from minecraft.protocol.info import CURRENT_VERSION

comptime VERSION: Int32 = 10
"""The storage version written in `level.dat` headers (Go `Version`)."""


def minimum_compatible_client_version() -> List[Int32]:
    """Returns the game version as numbers with two zeros appended (Go
    `minimumCompatibleClientVersion`): `1.26.60` gives `[1, 26, 60, 0, 0]`.

    Returns:
        The version numbers.
    """
    var out = List[Int32]()
    for part in String(CURRENT_VERSION).split("."):
        try:
            out.append(Int32(Int(String(part))))
        except:
            out.append(0)
    out.append(0)
    out.append(0)
    return out^
