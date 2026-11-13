"""Biomes: the `Biome` trait from Dragonfly `server/world/biome.go`, and the
vanilla biomes of `server/world/biome`.

Mojo cannot have a module and a package with the same name, so Go's
`world/biome.go` lives in this package's `__init__`.

Go keeps registered biomes as `Biome` interface values in a global map.
Here a `BiomeRegistry` holds a `BiomeInfo` (the biome's data) per ID, filled
from a compile-time `BiomeSet` of biome types (`register.VanillaBiomes`);
chunks store biome IDs (`encode_biome`).
"""

from std.collections import Dict

from ...internal.color import RGBA


trait Biome(ImplicitlyCopyable):
    """A region with distinct features, temperature, rainfall and colours."""

    def temperature(self) -> Float64:
        """Returns the temperature of the biome.

        Returns:
            The temperature.
        """
        ...

    def rainfall(self) -> Float64:
        """Returns the rainfall of the biome.

        Returns:
            The rainfall.
        """
        ...

    def depth(self) -> Float64:
        """Returns the depth of the biome.

        Returns:
            The depth.
        """
        ...

    def scale(self) -> Float64:
        """Returns the scale of the biome.

        Returns:
            The scale.
        """
        ...

    def water_colour(self) -> RGBA:
        """Returns the water colour of the biome.

        Returns:
            The colour.
        """
        ...

    def tags(self) -> List[String]:
        """Returns the tags of the biome.

        Returns:
            The tags.
        """
        ...

    def string(self) -> String:
        """Returns the biome name (Go `String`).

        Returns:
            The name, such as `plains`.
        """
        ...

    def encode_biome(self) -> Int:
        """Returns the biome ID used on the network and in chunks.

        Returns:
            The biome ID.
        """
        ...


@fieldwise_init
struct BiomeInfo(Copyable, Equatable, Writable):
    """The data of a registered biome, as the `Biome` methods return it."""

    var id: Int
    """The biome ID (Go `EncodeBiome`)."""
    var name: String
    """The biome name (Go `String`)."""
    var temperature: Float64
    """The temperature (Go `Temperature`)."""
    var rainfall: Float64
    """The rainfall (Go `Rainfall`)."""
    var depth: Float64
    """The depth (Go `Depth`)."""
    var scale: Float64
    """The scale (Go `Scale`)."""
    var water_colour: RGBA
    """The colour of water (Go `WaterColour`)."""
    var tags: List[String]
    """The tags (Go `Tags`)."""

    @staticmethod
    def of[B: Biome](b: B) -> Self:
        """Collects the data of a biome.

        Parameters:
            B: The biome type.

        Args:
            b: The biome.

        Returns:
            The data.
        """
        return BiomeInfo(
            b.encode_biome(),
            b.string(),
            b.temperature(),
            b.rainfall(),
            b.depth(),
            b.scale(),
            b.water_colour(),
            b.tags(),
        )

    def __eq__(self, other: Self) -> Bool:
        """Compares two biomes field by field.

        Args:
            other: The biome to compare with.

        Returns:
            True if all fields are equal.
        """
        return (
            self.id == other.id
            and self.name == other.name
            and self.temperature == other.temperature
            and self.rainfall == other.rainfall
            and self.depth == other.depth
            and self.scale == other.scale
            and self.water_colour == other.water_colour
            and self.tags == other.tags
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the biome as `name(id)`.

        Args:
            writer: The destination.
        """
        writer.write(self.name, "(", self.id, ")")


def unknown_biome(id: Int) -> BiomeInfo:
    """Returns the biome Dragonfly uses for IDs without a registered biome
    (Go `unknownBiome`).

    Args:
        id: The biome ID.

    Returns:
        A biome named `unknown` with temperature 0.5 and no rain.
    """
    return BiomeInfo(
        id, "unknown", 0.5, 0, 0.1, 0.1, RGBA(0x44, 0xAF, 0xF5, 0xFF), []
    )


struct BiomeRegistry(Copyable, Defaultable):
    """The biomes a server knows, by ID and by name (Go's `biomes` and
    `biomeByName` maps with `RegisterBiome`, `BiomeByID`, `BiomeByName` and
    `Biomes`)."""

    var _by_id: Dict[Int, BiomeInfo]
    var _id_by_name: Dict[String, Int]
    var _max_vanilla_id: Int

    def __init__(out self):
        """Creates an empty registry."""
        self._by_id = Dict[Int, BiomeInfo]()
        self._id_by_name = Dict[String, Int]()
        self._max_vanilla_id = 0

    def register[B: Biome](mut self, b: B) raises:
        """Registers a biome (Go `RegisterBiome`).

        Parameters:
            B: The biome type.

        Args:
            b: The biome.

        Raises:
            If a biome with the same ID is already registered (Go panics).
        """
        var info = BiomeInfo.of(b)
        if info.id in self._by_id:
            raise Error(t"cannot register the same biome ({info.name}) twice")
        self._id_by_name[info.name] = info.id
        self._by_id[info.id] = info^

    def finalise(mut self):
        """Records the highest vanilla biome ID, after the vanilla biomes are
        registered (Go `finaliseBiomeRegistry`). Biomes with higher IDs are
        custom and are sent with their ID in biome definitions.
        """
        for id in self._by_id:
            if id > self._max_vanilla_id:
                self._max_vanilla_id = id

    def max_vanilla_id(self) -> Int:
        """Returns the highest vanilla biome ID (Go `maxVanillaBiomeID`).

        Returns:
            The ID; 0 before `finalise`.
        """
        return self._max_vanilla_id

    def by_id(self, id: Int) -> Optional[BiomeInfo]:
        """Looks up a biome by ID (Go `BiomeByID`).

        Args:
            id: The biome ID.

        Returns:
            The biome, or None if no biome has the ID.
        """
        if case .Some(ref b) = self._by_id.get(id):
            return b.copy()
        return None

    def by_name(self, name: String) -> Optional[BiomeInfo]:
        """Looks up a biome by name (Go `BiomeByName`).

        Args:
            name: The biome name, such as `plains`.

        Returns:
            The biome, or None if no biome has the name.
        """
        if case .Some(id) = self._id_by_name.get(name):
            return self.by_id(id)
        return None

    def biomes(self) -> List[BiomeInfo]:
        """Returns every registered biome (Go `Biomes`, whose order is
        random), sorted by ID.

        Returns:
            The biomes.
        """
        var ids = List[Int]()
        for id in self._by_id:
            ids.append(id)
        sort(ids)
        var out = List[BiomeInfo](capacity=len(ids))
        for id in ids:
            out.append(self.by_id(id).value().copy())
        return out^


struct BiomeSet[*Ts: Biome & Defaultable & Deinitable]:
    """A compile-time list of biome types (no Go counterpart: it replaces
    the `RegisterBiome` calls).

    Parameters:
        Ts: The biome types.
    """

    @staticmethod
    def register_all(mut r: BiomeRegistry) raises:
        """Registers one value of every type.

        Args:
            r: The registry.

        Raises:
            If two types share a biome ID.
        """
        comptime for i in range(len(Self.Ts)):
            r.register(Self.Ts[i]())
