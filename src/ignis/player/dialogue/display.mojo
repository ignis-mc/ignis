"""Dialogue display settings, ported from Dragonfly
`server/player/dialogue/display.go`."""

from ...internal.gojson import JsonObject, format_float
from ...mgl64 import Vec3


def vec3_json(v: Vec3) -> String:
    """Returns a vector as Go marshals `mgl64.Vec3`: an array of three
    numbers."""
    return String(
        t"[{format_float(v.x())},{format_float(v.y())},{format_float(v.z())}]"
    )


@fieldwise_init
struct DisplaySettings(Copyable, Defaultable):
    """How the entity is shown in a dialogue (Go `DisplaySettings`)."""

    var entity_scale: Vec3
    """The entity's scale; the zero vector means 1, 1, 1."""
    var entity_offset: Vec3
    """The entity's offset in blocks."""
    var entity_rotation: Vec3
    """The entity's rotation in degrees (yaw, pitch, roll)."""

    def __init__(out self):
        """Creates the default settings."""
        self.entity_scale = Vec3()
        self.entity_offset = Vec3()
        self.entity_rotation = Vec3()

    def marshal_json(self) -> String:
        """Returns the settings' JSON (Go `MarshalJSON`)."""
        var r = self.entity_rotation
        var rotation = Vec3(r.y(), r.x() - 32, r.z())
        var m = JsonObject()
        m.raw("translate", vec3_json(self.entity_offset.mul(-32)))
        m.raw("rotate", vec3_json(rotation))
        if self.entity_scale != Vec3():
            m.raw("scale", vec3_json(self.entity_scale))
        else:
            m.raw("scale", "[1,1,1]")
        return m.encode()
