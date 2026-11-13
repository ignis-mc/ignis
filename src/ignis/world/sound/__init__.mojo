"""Sounds, ported from Dragonfly `server/world/sound.go` (the `Sound`
interface) and `server/world/sound` (the sounds).

Go's `Sound.Play(w, pos)` is a no-op for every sound Dragonfly defines; the
world plays a sound by showing it to its viewers, and sessions turn it into
packets. Here each sound type has a unique `SOUND_ID`, which sessions
compare to pick the packet (Go: a type switch in `session/world.go`).
`World.PlaySound` and the session mapping come with world-runtime and
sessions.
"""


trait Sound(Copyable, Deinitable):
    """A sound that can be played in a world (Go `world.Sound`)."""

    comptime SOUND_ID: Int
    """Distinguishes sound types; unique per type."""
