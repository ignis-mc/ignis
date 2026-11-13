"""The game and protocol version Ignis serves, and the Dragonfly version it
is ported from."""

from minecraft.protocol.info import CURRENT_PROTOCOL, CURRENT_VERSION

comptime PROTOCOL: Int32 = CURRENT_PROTOCOL
"""The network protocol version clients must speak."""

comptime GAME_VERSION: StaticString = CURRENT_VERSION
"""The Minecraft: Bedrock Edition version Ignis serves."""

comptime DRAGONFLY_VERSION: StaticString = "v0.11.6"
"""The Dragonfly release the server is ported from."""
