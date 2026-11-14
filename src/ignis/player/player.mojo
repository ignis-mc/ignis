"""Players, ported from the core of Dragonfly `server/player/player.go`:
identity, position, rotation, game mode, movement and chat.

Go's `Player` reaches its viewers and the global chat through the world
transaction. Ignis has no shared references, so the methods here only
change the player's own state and report what happened; the server, which
owns every session, shows the result to the viewers (see `server.Server`).
The skin stays on the session (Go keeps a copy there too, as `joinSkin`) so
that a `Player` is cheap to copy.
"""

from minecraft.protocol.uuid import UUID

from ..block.cube.rotation import Rotation
from ..mgl64 import Vec3, approx_equal, float_equal
from ..world.game_mode import GAME_MODE_SURVIVAL, GameMode


comptime EYE_HEIGHT = 1.62
"""How far the eyes are above the feet (Go `EyeHeight` and the network
offset of `player.Type`)."""
comptime BBOX_WIDTH = 0.6
"""The width of the player's bounding box (Go `Type.BBox`)."""
comptime BBOX_HEIGHT = 1.8
"""The height of the player's bounding box (Go `Type.BBox`)."""
comptime DEFAULT_FLIGHT_SPEED = 0.05
"""Go's default `flightSpeed`."""
comptime DEFAULT_VERTICAL_FLIGHT_SPEED = 1.0
"""Go's default `verticalFlightSpeed`."""


struct Player(Copyable):
    """A player in a world (Go `player.Player`, the parts ported so far)."""

    var _name: String
    var _xuid: String
    var _uuid: UUID
    var _locale: String
    var _name_tag: String
    var _game_mode: GameMode
    var _pos: Vec3
    var _rot: Rotation
    var _on_ground: Bool
    var _flying: Bool
    var _sneaking: Bool
    var _sprinting: Bool
    var _flight_speed: Float64
    var _vertical_flight_speed: Float64

    def __init__(
        out self,
        name: String,
        xuid: String,
        uuid: UUID,
        pos: Vec3,
        game_mode: GameMode = GAME_MODE_SURVIVAL,
        rot: Rotation = Rotation(),
    ):
        """Creates a player (Go `Config.Apply` with a fresh `Data`).

        Args:
            name: The display name; also the initial name tag.
            xuid: The XUID, empty for an unauthenticated player.
            uuid: The UUID.
            pos: The position of the feet.
            game_mode: The game mode.
            rot: The rotation.
        """
        self._name = name.copy()
        self._xuid = xuid.copy()
        self._uuid = uuid
        self._locale = "en_US"
        self._name_tag = name.copy()
        self._game_mode = game_mode
        self._pos = pos
        self._rot = rot
        self._on_ground = False
        self._flying = False
        self._sneaking = False
        self._sprinting = False
        self._flight_speed = DEFAULT_FLIGHT_SPEED
        self._vertical_flight_speed = DEFAULT_VERTICAL_FLIGHT_SPEED

    def name(self) -> String:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return self._name.copy()

    def xuid(self) -> String:
        """Returns the XUID (Go `XUID`).

        Returns:
            The XUID, empty if the player is not signed in to Xbox Live.
        """
        return self._xuid.copy()

    def uuid(self) -> UUID:
        """Returns the UUID (Go `UUID`).

        Returns:
            The UUID.
        """
        return self._uuid

    def name_tag(self) -> String:
        """Returns the name tag shown above the player (Go `NameTag`).

        Returns:
            The name tag.
        """
        return self._name_tag.copy()

    def set_name_tag(mut self, name: String):
        """Changes the name tag (Go `SetNameTag`); the caller shows the new
        state to viewers.

        Args:
            name: The new name tag.
        """
        self._name_tag = name.copy()

    def locale(self) -> String:
        """Returns the language code (Go `Locale`).

        Returns:
            The locale, such as `en_US`.
        """
        return self._locale.copy()

    def set_locale(mut self, locale: String):
        """Sets the language code from the client data.

        Args:
            locale: The locale.
        """
        self._locale = locale.copy()

    def position(self) -> Vec3:
        """Returns the position of the feet (Go `Position`).

        Returns:
            The position.
        """
        return self._pos

    def rotation(self) -> Rotation:
        """Returns the rotation (Go `Rotation`).

        Returns:
            The yaw and pitch.
        """
        return self._rot

    def on_ground(self) -> Bool:
        """Reports whether the player stands on the ground (Go `OnGround`).

        Returns:
            True after a movement the client reported as grounded.
        """
        return self._on_ground

    def game_mode(self) -> GameMode:
        """Returns the game mode (Go `GameMode`).

        Returns:
            The game mode.
        """
        return self._game_mode

    def set_game_mode(mut self, mode: GameMode):
        """Changes the game mode (Go `SetGameMode`); the session sends it.

        Args:
            mode: The new game mode.
        """
        self._game_mode = mode
        if not mode.allows_flying():
            self._flying = False

    def flying(self) -> Bool:
        """Reports whether the player is flying (Go `Flying`).

        Returns:
            True while flying.
        """
        return self._flying

    def start_flying(mut self):
        """Starts flying (Go `StartFlying`)."""
        self._flying = True

    def stop_flying(mut self):
        """Stops flying (Go `StopFlying`)."""
        self._flying = False

    def sneaking(self) -> Bool:
        """Reports whether the player is sneaking (Go `Sneaking`).

        Returns:
            True while sneaking.
        """
        return self._sneaking

    def set_sneaking(mut self, sneaking: Bool):
        """Starts or stops sneaking (Go `StartSneaking` / `StopSneaking`).

        Args:
            sneaking: Whether the player sneaks.
        """
        self._sneaking = sneaking

    def sprinting(self) -> Bool:
        """Reports whether the player is sprinting (Go `Sprinting`).

        Returns:
            True while sprinting.
        """
        return self._sprinting

    def set_sprinting(mut self, sprinting: Bool):
        """Starts or stops sprinting (Go `StartSprinting` /
        `StopSprinting`).

        Args:
            sprinting: Whether the player sprints.
        """
        self._sprinting = sprinting

    def flight_speed(self) -> Float64:
        """Returns the flight speed (Go `FlightSpeed`).

        Returns:
            The horizontal flight speed.
        """
        return self._flight_speed

    def vertical_flight_speed(self) -> Float64:
        """Returns the vertical flight speed (Go `VerticalFlightSpeed`).

        Returns:
            The vertical flight speed.
        """
        return self._vertical_flight_speed

    def move(
        mut self, delta_pos: Vec3, delta_yaw: Float64, delta_pitch: Float64
    ) -> Bool:
        """Moves and rotates the player (Go `Move`, without the handler,
        block collisions and fall damage, which are not ported yet).

        Args:
            delta_pos: The change in position.
            delta_yaw: The change in yaw.
            delta_pitch: The change in pitch.

        Returns:
            True if the player moved or turned, so viewers must be shown
            the new position (Go calls `ViewEntityMovement` here).
        """
        if (
            approx_equal(delta_pos, Vec3())
            and float_equal(delta_yaw, 0)
            and float_equal(delta_pitch, 0)
        ):
            self._on_ground = True
            return False
        self._pos = self._pos.add(delta_pos)
        self._rot = self._rot.add(Rotation(delta_yaw, delta_pitch))
        return True

    def teleport(mut self, pos: Vec3):
        """Moves the player to a position (Go `teleport`); the server shows it
        to the viewers."""
        self._pos = pos

    def chat(self, message: String) -> String:
        """Formats a chat message from the player (Go `Chat`, which writes
        it to `chat.Global`).

        Args:
            message: The message the player typed.

        Returns:
            `<name> message`, the line every chat subscriber receives.
        """
        return String(t"<{self._name}> {message}")
