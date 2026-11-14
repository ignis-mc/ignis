"""Health, ported from Dragonfly `server/entity/health.go`."""


struct HealthManager(Copyable, Defaultable):
    """Keeps an entity's health between 0 and its maximum (Go
    `HealthManager`)."""

    var health: Float64
    """The current health."""
    var max: Float64
    """The maximum health."""

    def __init__(out self):
        """Creates a manager of 20 out of 20 health."""
        self = Self(20, 20)

    def __init__(out self, health: Float64, max: Float64):
        """Creates a manager (Go `NewHealthManager`)."""
        self.health = min(health, max)
        self.max = max

    def add_health(mut self, health: Float64):
        """Adds (or with a negative value takes) health (Go `AddHealth`)."""
        self.health = max(min(self.health + health, self.max), 0)

    def set_max_health(mut self, m: Float64):
        """Sets the maximum, at least 1 (Go `SetMaxHealth`)."""
        var v = m if m > 0 else 1.0
        self.max = v
        self.health = min(self.health, v)
