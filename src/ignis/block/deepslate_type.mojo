"""`DeepslateType`, ported from Dragonfly `server/block/deepslate_type.go`."""

from ..internal.enum import enum_name


struct DeepslateType(Equatable, ImplicitlyCopyable, Writable):
    """A type of deepslate (Go `DeepslateType`)."""

    var _v: UInt8

    comptime NORMAL = DeepslateType(0)
    """Go `NormalDeepslate()`."""
    comptime COBBLED = DeepslateType(1)
    """Go `CobbledDeepslate()`."""
    comptime POLISHED = DeepslateType(2)
    """Go `PolishedDeepslate()`."""
    comptime CHISELED = DeepslateType(3)
    """Go `ChiseledDeepslate()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `DeepslateType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name(
            "Deepslate,Cobbled Deepslate,Polished Deepslate,Chiseled Deepslate",
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "deepslate,cobbled_deepslate,polished_deepslate,"
                    "chiseled_deepslate"
                ),
                Int(self._v),
            )
        )


def deepslate_types() -> List[DeepslateType]:
    """Returns every deepslate type (Go `DeepslateTypes`)."""
    var out = List[DeepslateType](capacity=4)
    for i in range(4):
        out.append(DeepslateType(i))
    return out^
