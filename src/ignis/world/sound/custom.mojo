"""The custom sounds, ported from Dragonfly `server/world/sound/custom.go`.
"""

from . import Sound


struct Custom(ImplicitlyCopyable, Sound):
    """A sound identified by name. It may be used to play sounds defined by a
    resource pack (Go `sound.Custom`)."""

    comptime SOUND_ID: Int = 88
    """The sound ID of `Custom`."""

    var name: String
    """Name is the identifier of the sound."""
    var volume: Float64
    """Volume is the volume of the sound."""
    var pitch: Float64
    """Pitch is the pitch of the sound."""

    def __init__(
        out self,
        *,
        name: String = String(),
        volume: Float64 = 0,
        pitch: Float64 = 0,
    ):
        """Creates the value; omitted fields take Go zero values.

        Args:
            name: Name is the identifier of the sound.
            volume: Volume is the volume of the sound.
            pitch: Pitch is the pitch of the sound.
        """
        self.name = name
        self.volume = volume
        self.pitch = pitch
