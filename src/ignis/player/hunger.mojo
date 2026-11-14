"""Hunger, ported from Dragonfly `server/player/hunger.go`."""


struct HungerManager(Copyable, Defaultable):
    """A player's food, saturation and exhaustion (Go `hungerManager`)."""

    var food_level: Int
    """Go `foodLevel`, 0 to 20."""
    var saturation_level: Float64
    """Go `saturationLevel`."""
    var exhaustion_level: Float64
    """Go `exhaustionLevel`."""
    var food_tick: Int
    """Ticks counted towards regeneration or starvation (Go `foodTick`)."""

    def __init__(out self):
        """Creates a full manager (Go `newHungerManager`)."""
        self.food_level = 20
        self.saturation_level = 5
        self.exhaustion_level = 0
        self.food_tick = 1

    def set_food(mut self, level: Int):
        """Sets the food level (Go `SetFood`)."""
        self.food_level = max(min(level, 20), 0)

    def add_food(mut self, points: Int):
        """Adds food points (Go `AddFood`)."""
        self.food_level = max(min(self.food_level + points, 20), 0)

    def reset(mut self):
        """Fills up again (Go `Reset`)."""
        self = Self()

    def reset_exhaustion(mut self):
        """Clears exhaustion and saturation (Go `resetExhaustion`)."""
        self.exhaustion_level = 0
        self.saturation_level = 0
        self.food_tick = 1

    def exhaust(mut self, points: Float64):
        """Adds exhaustion; every 4 points take saturation or food (Go
        `exhaust`)."""
        self.exhaustion_level += points
        while self.exhaustion_level >= 4:
            self.exhaustion_level -= 4
            self._desaturate()

    def saturate(mut self, food: Int, saturation: Float64):
        """Adds food and saturation, saturation capped at food (Go
        `saturate`)."""
        self.food_level = max(min(self.food_level + food, 20), 0)
        self.saturation_level = max(
            min(self.saturation_level + saturation, Float64(self.food_level)), 0
        )

    def _desaturate(mut self):
        # Go `desaturate`.
        if self.saturation_level <= 0 and self.food_level != 0:
            self.food_level -= 1
        elif self.saturation_level > 0:
            self.saturation_level = max(self.saturation_level - 1, 0)

    def can_quickly_regenerate(self) -> Bool:
        """Go `canQuicklyRegenerate`."""
        return self.food_level == 20 and self.saturation_level > 0

    def can_regenerate(self) -> Bool:
        """Go `canRegenerate`."""
        return self.food_level >= 18

    def can_sprint(self) -> Bool:
        """Go `canSprint`."""
        return self.food_level > 6

    def starving(self) -> Bool:
        """Go `starving`."""
        return self.food_level == 0
