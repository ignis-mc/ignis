"""The stand-in for a player among the world's entities.

In Dragonfly a player is a world entity, so projectiles, explosions,
lightning, clouds, splash potions, fireworks, ender pearls and experience
orbs find it with `tx.EntitiesWithin` and call its methods. In Ignis the
server owns the players; it keeps one `PlayerProxy` per player in the
world, at the player's position and with the facts those entities check
(game mode, health, box), and applies the `LivingRequest`s they record.
Proxies are never saved, and sessions never show them: each session shows
the players itself.
"""

from minecraft.nbt.tree import Tag, Tree

from ..block.cube.bbox import BBox
from ..world.entity import (
    EntityData,
    ExperienceCollector,
    TransientEntity,
)
from .living_request import (
    REQUEST_COLLECT_EXPERIENCE,
    LivingRequest,
)

comptime XP_PICKUP_COOLDOWN_TICKS = 2
"""Go's 100 ms between two orbs collected (`lastXPPickup`)."""


struct PlayerProxy(Copyable, ExperienceCollector, TransientEntity):
    """A player as the world's entities see it (Go `player.Type`)."""

    comptime IDENTIFIER: StaticString = "minecraft:player"
    """Go `ptype.EncodeEntity`."""

    var health: Float64
    """The player's health."""
    var has_collision: Bool
    """Go `GameMode().HasCollision()`: spectators are not hit."""
    var collects: Bool
    """Alive and in a game mode that allows interaction (Go
    `CanCollectExperience` without the cooldown)."""
    var sneaking: Bool
    """Sneaking players are lower (Go `ptype.BBox`)."""
    var last_xp_tick: Int64
    """The world tick the last orb was collected (Go `lastXPPickup`)."""
    var requests: List[LivingRequest]
    """The calls recorded since the server last took them."""

    def __init__(out self):
        """Creates the proxy of a healthy survival player."""
        self.health = 20
        self.has_collision = True
        self.collects = True
        self.sneaking = False
        self.last_xp_tick = -XP_PICKUP_COOLDOWN_TICKS
        self.requests = List[LivingRequest]()

    def bbox(self, data: EntityData) -> BBox:
        """Returns the player's box (Go `ptype.BBox`, standing or
        sneaking)."""
        var h = 1.49 if self.sneaking else 1.8
        return BBox.box(-0.3, 0, -0.3, 0.3, h, 0.3)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes nothing: proxies are never saved."""
        pass

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Creates a proxy; proxies are never saved, so never loaded."""
        return Self()

    def living_health(self) -> Float64:
        """Returns the player's health."""
        return self.health

    def request(mut self, var r: LivingRequest):
        """Records a call for the server."""
        self.requests.append(r^)

    def can_collect_experience(self, current: Int64) -> Bool:
        """Go `CanCollectExperience` with the 100 ms cooldown of
        `CollectExperience`."""
        return (
            self.collects
            and current - self.last_xp_tick >= XP_PICKUP_COOLDOWN_TICKS
        )

    def collect_experience(mut self, value: Int, current: Int64):
        """Go `CollectExperience`: the orb is gone; the server adds the
        experience."""
        self.last_xp_tick = current
        var r = LivingRequest(REQUEST_COLLECT_EXPERIENCE)
        r.value = value
        self.requests.append(r^)
