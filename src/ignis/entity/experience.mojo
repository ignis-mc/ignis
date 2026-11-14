"""Experience, ported from Dragonfly `server/entity/experience.go`."""

from std.math import sqrt, trunc
from std.os import abort


struct ExperienceManager(Copyable, Defaultable):
    """A player's experience points, from which level and progress follow
    (Go `ExperienceManager`)."""

    var experience: Int
    """Go `experience`."""
    var dec: Float64
    """The fraction of a point left by `set_progress` (Go `dec`)."""

    def __init__(out self):
        """Creates a manager without experience."""
        self.experience = 0
        self.dec = 0

    def add(mut self, amount: Int) -> Tuple[Int, Float64]:
        """Adds experience and returns the level and progress (Go `Add`)."""
        self.experience += amount
        if self.experience < 0:
            self.reset()
        return progress_from_experience(self._total())

    def _total(self) -> Float64:
        return Float64(self.experience) + self.dec

    def level(self) -> Int:
        """Returns the level (Go `Level`)."""
        return progress_from_experience(self._total())[0]

    def progress(self) -> Float64:
        """Returns the progress to the next level, 0 to 1 (Go `Progress`)."""
        return progress_from_experience(self._total())[1]

    def set_level(mut self, level: Int):
        """Sets the level, keeping the progress (Go `SetLevel`)."""
        if level < 0 or level > Int(Int32.MAX):
            abort("level must be between 0 and 2,147,483,647")
        var progress = progress_from_experience(self._total())[1]
        self.experience = experience_for_levels(level) + Int(
            Float64(experience_for_level(level)) * progress
        )

    def set_progress(mut self, progress: Float64):
        """Sets the progress, keeping the level (Go `SetProgress`)."""
        if progress < 0 or progress > 1:
            abort("progress must be between 0 and 1")
        var current = progress_from_experience(self._total())[0]
        var p = Float64(experience_for_level(current)) * progress
        self.experience = experience_for_levels(current) + Int(p)
        self.dec = p - trunc(p)

    def reset(mut self):
        """Removes all experience (Go `Reset`)."""
        self.experience = 0
        self.dec = 0


def progress_from_experience(experience: Float64) -> Tuple[Int, Float64]:
    """Returns the level and progress for an amount of experience (Go
    `progressFromExperience`)."""
    var a: Float64
    var b: Float64
    var c = 0.0
    if experience <= Float64(experience_for_levels(16)):
        a = 1.0
        b = 6.0
    elif experience <= Float64(experience_for_levels(31)):
        a = 2.5
        b = -40.5
        c = 360.0
    else:
        a = 4.5
        b = -162.5
        c = 2220.0
    var sol = 0.0
    var d = b * b - 4 * a * (c - experience)
    if d > 0:
        var s = sqrt(d)
        sol = max((-b + s) / (2 * a), (-b - s) / (2 * a))
    elif d == 0:
        sol = -b / (2 * a)
    return (Int(sol), sol - trunc(sol))


def experience_for_levels(level: Int) -> Int:
    """Returns the experience needed to reach a level (Go
    `experienceForLevels`)."""
    if level <= 16:
        return level * level + level * 6
    elif level <= 31:
        return Int(Float64(level * level) * 2.5 - 40.5 * Float64(level) + 360)
    return Int(Float64(level * level) * 4.5 - 162.5 * Float64(level) + 2220)


def experience_for_level(level: Int) -> Int:
    """Returns the experience between a level and the next (Go
    `experienceForLevel`)."""
    if level <= 15:
        return 2 * level + 7
    elif level <= 30:
        return 5 * level - 38
    return 9 * level - 158
