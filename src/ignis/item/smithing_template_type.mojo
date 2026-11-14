"""`SmithingTemplateType`, ported from Dragonfly
`server/item/smithing_template_type.go`.
"""

from ..internal.enum import enum_name


struct SmithingTemplateType(Equatable, ImplicitlyCopyable, Writable):
    """A type of smithing template (Go `SmithingTemplateType`)."""

    var _v: UInt8

    comptime NETHERITE_UPGRADE = SmithingTemplateType(0)
    """Go `TemplateNetheriteUpgrade()`."""
    comptime SENTRY = SmithingTemplateType(1)
    """Go `TemplateSentry()`."""
    comptime VEX = SmithingTemplateType(2)
    """Go `TemplateVex()`."""
    comptime WILD = SmithingTemplateType(3)
    """Go `TemplateWild()`."""
    comptime COAST = SmithingTemplateType(4)
    """Go `TemplateCoast()`."""
    comptime DUNE = SmithingTemplateType(5)
    """Go `TemplateDune()`."""
    comptime WAY_FINDER = SmithingTemplateType(6)
    """Go `TemplateWayFinder()`."""
    comptime RAISER = SmithingTemplateType(7)
    """Go `TemplateRaiser()`."""
    comptime SHAPER = SmithingTemplateType(8)
    """Go `TemplateShaper()`."""
    comptime HOST = SmithingTemplateType(9)
    """Go `TemplateHost()`."""
    comptime WARD = SmithingTemplateType(10)
    """Go `TemplateWard()`."""
    comptime SILENCE = SmithingTemplateType(11)
    """Go `TemplateSilence()`."""
    comptime TIDE = SmithingTemplateType(12)
    """Go `TemplateTide()`."""
    comptime SNOUT = SmithingTemplateType(13)
    """Go `TemplateSnout()`."""
    comptime RIB = SmithingTemplateType(14)
    """Go `TemplateRib()`."""
    comptime EYE = SmithingTemplateType(15)
    """Go `TemplateEye()`."""
    comptime SPIRE = SmithingTemplateType(16)
    """Go `TemplateSpire()`."""
    comptime FLOW = SmithingTemplateType(17)
    """Go `TemplateFlow()`."""
    comptime BOLT = SmithingTemplateType(18)
    """Go `TemplateBolt()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `SmithingTemplateType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the value's name (Go `String`)."""
        return enum_name(
            (
                "netherite_upgrade,sentry,vex,wild,coast,dune,wayfinder,"
                "raiser,shaper,host,ward,silence,tide,snout,rib,eye,spire,"
                "flow,bolt"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's name (Go `String`)."""
        writer.write(self.name())


def smithing_templates() -> List[SmithingTemplateType]:
    """Returns every value (Go `SmithingTemplates`)."""
    var out = List[SmithingTemplateType](capacity=19)
    for i in range(19):
        out.append(SmithingTemplateType(i))
    return out^


def smithing_template_from_string(
    name: StringSlice,
) -> Optional[SmithingTemplateType]:
    """Returns the template named `name` (Go `smithingTemplateFromString`)."""
    for t in smithing_templates():
        if t.name() == name:
            return t
    return None
