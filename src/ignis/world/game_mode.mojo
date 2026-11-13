"""Game modes, ported from Dragonfly `server/world/game_mode.go`.

Go's `GameMode` is an interface with four vanilla implementations compared
by identity. Here, as with `Dimension`, it is a small value type: the
vanilla modes are the `GAME_MODE_*` constants, and the methods read the
flags each Go type returns.
"""


@fieldwise_init
struct GameMode(Equatable, ImplicitlyCopyable, Writable):
    """A game mode: what a player in it may do."""

    var id: Int
    """The ID Go's `GameModeID` returns."""
    var name: StaticString
    """The lower-case name, as used in `config.toml`."""
    var _allows_editing: Bool
    var _allows_taking_damage: Bool
    var _creative_inventory: Bool
    var _has_collision: Bool
    var _allows_flying: Bool
    var _allows_interaction: Bool
    var _visible: Bool

    def allows_editing(self) -> Bool:
        """Reports whether the player may place and break blocks.

        Returns:
            Go `AllowsEditing`.
        """
        return self._allows_editing

    def allows_taking_damage(self) -> Bool:
        """Reports whether the player can be hurt.

        Returns:
            Go `AllowsTakingDamage`.
        """
        return self._allows_taking_damage

    def creative_inventory(self) -> Bool:
        """Reports whether the player has the creative inventory.

        Returns:
            Go `CreativeInventory`.
        """
        return self._creative_inventory

    def has_collision(self) -> Bool:
        """Reports whether the player collides with blocks.

        Returns:
            Go `HasCollision`.
        """
        return self._has_collision

    def allows_flying(self) -> Bool:
        """Reports whether the player may fly.

        Returns:
            Go `AllowsFlying`.
        """
        return self._allows_flying

    def allows_interaction(self) -> Bool:
        """Reports whether the player may interact with the world.

        Returns:
            Go `AllowsInteraction`.
        """
        return self._allows_interaction

    def visible(self) -> Bool:
        """Reports whether other players can see the player.

        Returns:
            Go `Visible`.
        """
        return self._visible

    def __eq__(self, other: Self) -> Bool:
        """Compares game modes by ID.

        Args:
            other: The other game mode.

        Returns:
            True if both are the same mode.
        """
        return self.id == other.id

    def write_to(self, mut writer: Some[Writer]):
        """Writes the name.

        Args:
            writer: The writer.
        """
        writer.write(self.name)


comptime GAME_MODE_SURVIVAL = GameMode(
    0, "survival", True, True, False, True, False, True, True
)
"""Go `GameModeSurvival`."""
comptime GAME_MODE_CREATIVE = GameMode(
    1, "creative", True, False, True, True, True, True, True
)
"""Go `GameModeCreative`."""
comptime GAME_MODE_ADVENTURE = GameMode(
    2, "adventure", False, True, False, True, False, True, True
)
"""Go `GameModeAdventure`."""
comptime GAME_MODE_SPECTATOR = GameMode(
    3, "spectator", False, False, False, False, True, False, False
)
"""Go `GameModeSpectator`."""


def game_mode_by_id(id: Int) -> Optional[GameMode]:
    """Looks a game mode up by ID (Go `GameModeByID`).

    Args:
        id: 0 survival, 1 creative, 2 adventure or 3 spectator.

    Returns:
        The game mode, or `None` for any other ID.
    """
    if id == 0:
        return GAME_MODE_SURVIVAL
    if id == 1:
        return GAME_MODE_CREATIVE
    if id == 2:
        return GAME_MODE_ADVENTURE
    if id == 3:
        return GAME_MODE_SPECTATOR
    return None


def game_mode_by_name(name: StringSlice) -> Optional[GameMode]:
    """Looks a game mode up by its lower-case name or numeric ID.

    Args:
        name: `survival`, `creative`, `adventure`, `spectator` or `0`-`3`.

    Returns:
        The game mode, or `None` if the name is unknown.
    """
    for i in range(4):
        var mode = game_mode_by_id(i).value()
        if name == mode.name or name == String(i):
            return mode
    return None
