"""Difficulties, ported from Dragonfly `server/world/difficulty.go`.

As with game modes, the vanilla set is closed: a difficulty is its ID and
the `DIFFICULTY_*` constants are Go's `Difficulty*` variables.
"""


@fieldwise_init
struct Difficulty(Equatable, ImplicitlyCopyable, Writable):
    """The difficulty of a world (Go `Difficulty`)."""

    var id: Int
    """The ID (Go `DifficultyID`): 0 peaceful, 1 easy, 2 normal, 3 hard."""

    def food_regenerates(self) -> Bool:
        """Reports whether food levels regenerate by themselves."""
        return self.id == 0

    def starvation_health_limit(self) -> Float64:
        """Returns the health below which starvation stops hurting."""
        if self.id == 0:
            return 20
        if self.id == 1:
            return 10
        if self.id == 2:
            return 2
        return -1

    def fire_spread_increase(self) -> Int:
        """Returns how much faster fire spreads."""
        return self.id * 7

    def write_to(self, mut writer: Some[Writer]):
        """Writes the difficulty's name."""
        if self.id == 0:
            writer.write("peaceful")
        elif self.id == 1:
            writer.write("easy")
        elif self.id == 2:
            writer.write("normal")
        else:
            writer.write("hard")


comptime DIFFICULTY_PEACEFUL = Difficulty(0)
"""Few hostile mobs; health and food regenerate (Go
`DifficultyPeaceful`)."""
comptime DIFFICULTY_EASY = Difficulty(1)
"""Weaker mobs; starvation stops at 5 hearts (Go `DifficultyEasy`)."""
comptime DIFFICULTY_NORMAL = Difficulty(2)
"""Normal mobs; starvation stops at 1 heart (Go `DifficultyNormal`)."""
comptime DIFFICULTY_HARD = Difficulty(3)
"""Stronger mobs; starvation kills (Go `DifficultyHard`)."""


def difficulty_by_id(id: Int) -> Optional[Difficulty]:
    """Looks up a difficulty by ID (Go `DifficultyByID`)."""
    if id < 0 or id > 3:
        return None
    return Difficulty(id)
