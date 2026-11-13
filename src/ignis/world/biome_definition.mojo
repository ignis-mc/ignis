"""Biome definitions for the client, ported from Dragonfly
`server/world/biome_definition.go`.
"""

from std.collections import Dict

from minecraft.protocol.biome import BiomeDefinition

from .biome import BiomeRegistry


def biome_definitions(
    r: BiomeRegistry,
) -> Tuple[List[BiomeDefinition], List[String]]:
    """Encodes the registered biomes for the `BiomeDefinitionList` packet
    (Go `BiomeDefinitions`).

    Names come first in the string list, in ID order, followed by tags as
    they are first used. Vanilla biomes are sent with biome ID -1; custom
    ones (IDs above `max_vanilla_id`) with their ID.

    Args:
        r: The finalised biome registry.

    Returns:
        The definitions, sorted by ID, and the interned string list.
    """
    var strings = List[String]()
    var index = Dict[String, Int]()

    def intern(s: String) {mut strings, mut index} -> Int:
        if case .Some(i) = index.get(s):
            return i
        var i = len(strings)
        strings.append(s)
        index[s] = i
        return i

    var biomes = r.biomes()
    for b in biomes:
        _ = intern(b.name)
    var defs = List[BiomeDefinition](capacity=len(biomes))
    for b in biomes:
        var d = BiomeDefinition()
        d.name_index = Int16(intern(b.name))
        var tag_indices = List[UInt16](capacity=len(b.tags))
        for t in b.tags:
            tag_indices.append(UInt16(intern(t)))
        d.biome_id = -1
        if b.id > r.max_vanilla_id():
            d.biome_id = Int16(b.id)
        d.temperature = Float32(b.temperature)
        d.downfall = Float32(b.rainfall)
        d.depth = Float32(b.depth)
        d.scale = Float32(b.scale)
        var w = b.water_colour
        d.map_water_colour = Int32(
            UInt32(w.a) << 24
            | UInt32(w.r) << 16
            | UInt32(w.g) << 8
            | UInt32(w.b)
        )
        d.rain = b.rainfall > 0
        d.tags = tag_indices^
        defs.append(d^)
    return (defs^, strings^)
