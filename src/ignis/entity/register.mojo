"""Registration of the vanilla entity types, ported from Dragonfly
`server/entity/register.go`."""

from ..world.entity import EntitySet
from .text import Text

comptime VanillaEntities = EntitySet[Text]
"""Every entity type Ignis implements. Player types join it when players
are ported."""
