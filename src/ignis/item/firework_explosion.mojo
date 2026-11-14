"""`FireworkExplosion`, ported from Dragonfly
`server/item/firework_explosion.go`.

Go's `DecodeNBT` panics on a missing or mistyped key; `decode_nbt` raises.
"""

from minecraft.nbt.nbt import TAG_BYTE_ARRAY, TAG_LIST
from minecraft.nbt.tree import Tag, Tree

from ..world.block import NBTer
from .colour import Colour, invert_colour, invert_colour_id
from .firework_shape import FireworkShape, firework_shapes


struct FireworkExplosion(Equatable, ImplicitlyCopyable, NBTer):
    """An explosion of a firework (Go `FireworkExplosion`)."""

    var shape: FireworkShape
    """The shape of the explosion."""
    var colour: Colour
    """The colour of the explosion."""
    var fade: Colour
    """The colour the explosion fades to, if `fades` is set."""
    var fades: Bool
    """Whether the explosion fades to `fade`."""
    var twinkle: Bool
    """Whether the explosion twinkles."""
    var trail: Bool
    """Whether the explosion leaves a trail."""

    def __init__(
        out self,
        *,
        shape: FireworkShape = FireworkShape(),
        colour: Colour = Colour(0),
        fade: Colour = Colour(0),
        fades: Bool = False,
        twinkle: Bool = False,
        trail: Bool = False,
    ):
        """Creates the explosion; omitted fields take Go zero values."""
        self.shape = shape
        self.colour = colour
        self.fade = fade
        self.fades = fades
        self.twinkle = twinkle
        self.trail = trail

    def __eq__(self, other: Self) -> Bool:
        """Compares two explosions field by field."""
        return (
            self.shape == other.shape
            and self.colour == other.colour
            and self.fade == other.fade
            and self.fades == other.fades
            and self.twinkle == other.twinkle
            and self.trail == other.trail
        )

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the explosion's NBT (Go `EncodeNBT`)."""
        _ = tag.put_byte(root, "FireworkType", self.shape.uint8())
        var colour: List[UInt8] = [UInt8(invert_colour(self.colour))]
        _ = tag.put_byte_array(root, "FireworkColor", colour)
        var fade = List[UInt8]()
        if self.fades:
            fade.append(UInt8(invert_colour(self.fade)))
        _ = tag.put_byte_array(root, "FireworkFade", fade)
        _ = tag.put_byte(
            root, "FireworkFlicker", UInt8(1 if self.twinkle else 0)
        )
        _ = tag.put_byte(root, "FireworkTrail", UInt8(1 if self.trail else 0))

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the explosion with its NBT decoded (Go `DecodeNBT`)."""
        var f = self
        f.shape = firework_shapes()[Int(tag.get_byte(root, "FireworkType"))]
        f.twinkle = tag.get_byte(root, "FireworkFlicker") == 1
        f.trail = tag.get_byte(root, "FireworkTrail") == 1
        if case .Some(c) = tag.get(root, "FireworkColor"):
            # Disk NBT holds a byte array, network NBT a list of bytes.
            if tag.type_of(c) == TAG_BYTE_ARRAY:
                var b = tag.as_byte_array(c)
                if len(b) == 1:
                    f.colour = invert_colour_id(Int16(b[0]))
            elif tag.type_of(c) == TAG_LIST and tag.length(c) > 0:
                f.colour = invert_colour_id(Int16(tag.as_byte(tag.at(c, 0))))
        if case .Some(c) = tag.get(root, "FireworkFade"):
            if tag.type_of(c) == TAG_BYTE_ARRAY:
                var b = tag.as_byte_array(c)
                if len(b) == 1:
                    f.fade = invert_colour_id(Int16(b[0]))
                    f.fades = True
        return f
