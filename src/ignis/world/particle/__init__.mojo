"""Particles, ported from Dragonfly `server/world/particle.go` (the
`Particle` interface) and `server/world/particle` (the particles).

Go's `Particle.Spawn(w, pos)` is a no-op for every particle Dragonfly
defines; the world shows particles to its viewers, and sessions turn them
into packets. Here each particle type has a unique `PARTICLE_ID`, which
sessions compare to pick the packet. `World.AddParticle` and the session
mapping come with world-runtime and sessions.
"""


trait Particle(Copyable, Deinitable):
    """A particle that can be shown in a world (Go `world.Particle`)."""

    comptime PARTICLE_ID: Int
    """Distinguishes particle types; unique per type."""
