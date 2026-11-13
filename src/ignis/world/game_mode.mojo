"""Game modes, ported from Dragonfly `server/world/game_mode.go`.

Go's `GameMode` is an interface with four vanilla implementations and a
registry from IDs. The set is closed, so here a game mode is its ID and the
methods answer per ID; the `GAME_MODE_*` constants are Go's `GameMode*`
variables.
"""


@fieldwise_init
struct GameMode(Equatable, ImplicitlyCopyable, Writable):
    """A game mode a player may have (Go `GameMode`)."""

    var id: Int
    """The ID the game mode is registered with (Go `GameModeID`): 0
    survival, 1 creative, 2 adventure, 3 spectator."""

    def allows_editing(self) -> Bool:
        """Reports whether a player can edit the world.

        Returns:
            True in survival and creative.
        """
        return self.id <= 1

    def allows_taking_damage(self) -> Bool:
        """Reports whether a player can take damage.

        Returns:
            True in survival and adventure.
        """
        return self.id == 0 or self.id == 2

    def creative_inventory(self) -> Bool:
        """Reports whether a player has the creative inventory.

        Returns:
            True in creative.
        """
        return self.id == 1

    def has_collision(self) -> Bool:
        """Reports whether a player collides with blocks and entities.

        Returns:
            False in spectator.
        """
        return self.id != 3

    def allows_flying(self) -> Bool:
        """Reports whether a player can fly.

        Returns:
            True in creative and spectator.
        """
        return self.id == 1 or self.id == 3

    def allows_interaction(self) -> Bool:
        """Reports whether a player can interact with entities and use
        items.

        Returns:
            False in spectator.
        """
        return self.id != 3

    def visible(self) -> Bool:
        """Reports whether a player is visible to others.

        Returns:
            False in spectator.
        """
        return self.id != 3

    def instant_portal_travel(self) -> Bool:
        """Reports whether a player travels through nether portals at once.

        Returns:
            True in creative.
        """
        return self.id == 1

    def write_to(self, mut writer: Some[Writer]):
        """Writes the game mode's name.

        Args:
            writer: The destination.
        """
        if self.id == 0:
            writer.write("survival")
        elif self.id == 1:
            writer.write("creative")
        elif self.id == 2:
            writer.write("adventure")
        else:
            writer.write("spectator")


comptime GAME_MODE_SURVIVAL = GameMode(0)
"""Limited supplies; blocks take time to break (Go `GameModeSurvival`)."""
comptime GAME_MODE_CREATIVE = GameMode(1)
"""Infinite blocks and items, instant breaking, flying (Go
`GameModeCreative`)."""
comptime GAME_MODE_ADVENTURE = GameMode(2)
"""No placing or breaking blocks (Go `GameModeAdventure`)."""
comptime GAME_MODE_SPECTATOR = GameMode(3)
"""Invisible, flying, no interaction, no collision (Go
`GameModeSpectator`)."""


def game_mode_by_id(id: Int) -> Optional[GameMode]:
    """Looks up a game mode by ID (Go `GameModeByID`).

    Args:
        id: 0 to 3.

    Returns:
        The game mode, or None for other IDs (Go returns survival and
        false).
    """
    if id < 0 or id > 3:
        return None
    return GameMode(id)
