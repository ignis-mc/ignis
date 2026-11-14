"""Light types, ported from Dragonfly `server/world/chunk/light_type.go`.

Go's `light` interface with its `skyLight` and `blockLight` values becomes a
`UInt8` tag that `LightArea.light` and `set_light` switch on.
"""

comptime BLOCK_LIGHT: UInt8 = 0
"""Light from blocks that emit it (Go `BlockLight`)."""

comptime SKY_LIGHT: UInt8 = 1
"""Light from the sky (Go `SkyLight`)."""
