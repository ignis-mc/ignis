"""LevelDB keys of the world format, ported from Dragonfly
`server/world/mcdb/keys.go`."""

comptime KEY_SUB_CHUNK_DATA: UInt8 = 0x2F
"""`/`: a sub-chunk; followed by the sub-chunk Y byte."""
comptime KEY_VERSION: UInt8 = 0x2C
"""`,`: one byte holding the chunk version."""
comptime KEY_VERSION_OLD: UInt8 = 0x76
"""`v`: the chunk version key older worlds use."""
comptime KEY_BLOCK_ENTITIES: UInt8 = 0x31
"""`1`: block entity compounds, concatenated."""
comptime KEY_ENTITIES_OLD: UInt8 = 0x32
"""`2`: entity compounds, concatenated (replaced by `digp`/`actorprefix`)."""
comptime KEY_PENDING_SCHEDULED_TICKS: UInt8 = 0x33
"""`3`: the scheduled block updates of the chunk."""
comptime KEY_FINALISATION: UInt8 = 0x36
"""`6`: a little-endian int32 generation state; 2 is fully finalised."""
comptime KEY_3D_DATA: UInt8 = 0x2B
"""`+`: a 512-byte height map followed by the biome storages."""
comptime KEY_2D_DATA: UInt8 = 0x2D
"""`-`: 2D biomes of worlds from before the height change."""
comptime KEY_CHECKSUMS: UInt8 = 0x3B
"""`;`: checksums of unknown use."""
comptime KEY_LEGACY_STATES: UInt8 = 0x7C
"""`|`: marks a chunk saved while derived block states still held
defaults from an upgrade (outside the range vanilla writes)."""

comptime KEY_ENTITY_IDENTIFIERS = "digp"
"""Prefix of the list of entity IDs in a chunk."""
comptime KEY_ENTITY = "actorprefix"
"""Prefix of an entity's data, followed by its ID."""

comptime KEY_AUTONOMOUS_ENTITIES = "AutonomousEntities"
"""A world-wide key vanilla writes."""
comptime KEY_OVERWORLD = "Overworld"
"""A world-wide key vanilla writes."""
comptime KEY_MOB_EVENTS = "mobevents"
"""A world-wide key vanilla writes."""
comptime KEY_BIOME_DATA = "BiomeData"
"""A world-wide key vanilla writes."""
comptime KEY_SCOREBOARD = "scoreboard"
"""A world-wide key vanilla writes."""
comptime KEY_LOCAL_PLAYER = "~local_player"
"""The local player's data in single-player worlds."""

comptime FINALISATION_GENERATED: UInt32 = 1
"""The chunk was generated but not populated."""
comptime FINALISATION_POPULATED: UInt32 = 2
"""The chunk is fully finalised."""
