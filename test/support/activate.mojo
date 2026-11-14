"""Helpers for tests that activate blocks in a vanilla world."""

from ignis.world.world import World
from support.world_runtime import RecordingViewer, VanillaWorld


def viewing(mut w: World[VanillaWorld]) -> UInt64:
    """Adds a recording loader around the origin and loads its chunks."""
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    return id


def sounds(mut w: World[VanillaWorld], id: UInt64, sound_id: Int) -> Int:
    """Counts the sounds of one type the loader's viewer saw."""
    return w.viewer(id).count(String(t"sound {sound_id} "))


def particles(mut w: World[VanillaWorld], id: UInt64, particle_id: Int) -> Int:
    """Counts the particles of one type the loader's viewer saw."""
    return w.viewer(id).count(String(t"particle {particle_id} "))
