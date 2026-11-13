"""Command targets (Dragonfly `server/cmd/target.go`).

Go's `Target` is an interface that every entity satisfies, and `[]Target`
parameters hold the entities themselves. Mojo has no trait objects, so a
`Target` here is a value describing one targetable entity: its UUID (how the
world finds the entity again), its name, position and whether it is a
player. The world supplies the candidates through `TargetProvider`, the
part of Go's `*world.Tx` that target selectors need.
"""

from minecraft.protocol.uuid import UUID

from ..mgl64 import Vec3


struct Target(Copyable, Defaultable, Equatable, Writable):
    """One entity a command can target (Go `cmd.Target`/`NamedTarget`)."""

    var uuid: UUID
    """The UUID of the entity's handle."""
    var name: String
    """The name (Go `NamedTarget.Name`); empty for unnamed entities."""
    var position: Vec3
    """The position when the command was parsed (Go `Position`)."""
    var player: Bool
    """Whether the entity is a player (listed by `players`)."""

    def __init__(out self):
        """Creates a zero target."""
        self.uuid = UUID()
        self.name = String()
        self.position = Vec3()
        self.player = False

    def __init__(
        out self,
        uuid: UUID,
        var name: String,
        position: Vec3,
        player: Bool,
    ):
        """Creates a target.

        Args:
            uuid: The entity's UUID.
            name: The entity's name, or empty.
            position: The entity's position.
            player: Whether the entity is a player.
        """
        self.uuid = uuid
        self.name = name^
        self.position = position
        self.player = player

    def __eq__(self, other: Self) -> Bool:
        """Compares every field.

        Args:
            other: The other target.

        Returns:
            True if both describe the same entity at the same position.
        """
        return (
            self.uuid == other.uuid
            and self.name == other.name
            and self.position == other.position
            and self.player == other.player
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the name, or the UUID for an unnamed target.

        Args:
            writer: The destination.
        """
        if self.name.byte_length() > 0:
            writer.write(self.name)
        else:
            writer.write(self.uuid)


trait TargetProvider:
    """Lists the entities target selectors choose from: the part of Go's
    `*world.Tx` used by `targets(tx)`.

    A source that is not in a world (a console) uses `NoTargets`, which
    behaves like Go's nil `tx`.
    """

    def attached(self) -> Bool:
        """Reports whether there is a world to select from (Go `tx != nil`).

        Returns:
            False if selectors such as `@a` must fail.
        """
        ...

    def entities(self) -> List[Target]:
        """Lists every entity (Go `tx.Entities()`), players included.

        Returns:
            The entities.
        """
        ...

    def players(self) -> List[Target]:
        """Lists every player (Go `tx.Players()`).

        Returns:
            The players, each with its name.
        """
        ...


struct NoTargets(Defaultable, Movable, TargetProvider):
    """A `TargetProvider` with no world, like Go's nil `*world.Tx`."""

    def __init__(out self):
        """Creates the provider."""
        pass

    def attached(self) -> Bool:
        """Reports that there is no world.

        Returns:
            False.
        """
        return False

    def entities(self) -> List[Target]:
        """Lists no entities.

        Returns:
            An empty list.
        """
        return List[Target]()

    def players(self) -> List[Target]:
        """Lists no players.

        Returns:
            An empty list.
        """
        return List[Target]()
