"""Smelting, ported from Dragonfly `server/item/smelting_info.go`.

Durations are milliseconds (Go `time.Duration`).
"""

from .stack import Stack


struct SmeltInfo(Copyable, Defaultable, Equatable):
    """What smelting an item gives (Go `SmeltInfo`)."""

    var product: Stack
    """The stack smelting the item results in."""
    var experience: Float64
    """The experience gained by the smelt."""
    var food: Bool
    """Whether the smelt is food, which smokers smelt."""
    var ores: Bool
    """Whether the smelt is ores, which blast furnaces smelt."""

    def __init__(out self):
        """Creates the info of an item that smelts into nothing (Go
        `SmeltInfo{}`)."""
        self.product = Stack()
        self.experience = 0
        self.food = False
        self.ores = False

    def __init__(
        out self,
        var product: Stack,
        experience: Float64,
        *,
        food: Bool = False,
        ores: Bool = False,
    ):
        """Creates the info of a smelt (Go `newSmeltInfo`, or
        `newFoodSmeltInfo` with `food=True` and `newOreSmeltInfo` with
        `ores=True`).
        """
        self.product = product^
        self.experience = experience
        self.food = food
        self.ores = ores


struct FuelInfo(Copyable, Defaultable, Equatable):
    """How long an item burns in a smelter and what it leaves (Go
    `FuelInfo`)."""

    var duration: Int
    """How long the fuel burns, in milliseconds."""
    var residue: Stack
    """The stack left after burning the fuel (a bucket for lava)."""

    def __init__(out self):
        """Creates the info of an item that does not burn (Go
        `FuelInfo{}`)."""
        self.duration = 0
        self.residue = Stack()

    def __init__(out self, duration: Int):
        """Creates the info of a fuel without residue (Go `newFuelInfo`)."""
        self.duration = duration
        self.residue = Stack()

    def with_residue(self, var residue: Stack) -> Self:
        """Returns the info with a residue (Go `WithResidue`)."""
        var f = self.copy()
        f.residue = residue^
        return f^


trait Smeltable:
    """An item that may be smelted in a smelter (Go `Smeltable`)."""

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the item gives."""
        ...


trait Fuel:
    """An item that may burn in a smelter (Go `Fuel`)."""

    def fuel_info(self) -> FuelInfo:
        """Returns how long the item burns and what it leaves."""
        ...
