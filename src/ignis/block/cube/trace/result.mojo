"""Trace results, ported from Dragonfly `server/block/cube/trace/result.go`.

`Perform` and `EntityFilter` need `world.Tx` and entities:
TODO(world-runtime).
"""

from ....mgl64 import Vec3
from ..bbox import BBox
from ..face import Face


trait Result:
    """The result of a ray trace hitting something (Go `trace.Result`)."""

    def bbox(self) -> BBox:
        """Returns the box that was hit (Go `BBox`)."""
        ...

    def position(self) -> Vec3:
        """Returns the point where the ray hit (Go `Position`)."""
        ...

    def face(self) -> Face:
        """Returns the face that was hit (Go `Face`)."""
        ...
