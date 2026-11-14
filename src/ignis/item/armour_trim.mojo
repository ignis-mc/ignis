"""`ArmourTrim` and `ArmourTrimMaterial`, ported from Dragonfly
`server/item/armour_trim.go`.

Go's trim holds its material as an item value (`ArmourTrimMaterial`); here
it is an `AnyItem`, and the material's name and colour come from
`trim_material_name`/`trim_material_colour`, which list the same items as
Go's `ArmourTrimMaterials`. `Trimmable` (`WithTrim`) is a method of each
armour piece.
"""

from minecraft.nbt.nbt import TAG_COMPOUND, TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..block.hash import HASH_REDSTONE_WIRE
from ..internal.enum import enum_name
from ..world.item import AnyItem, item_hash
from .smithing_template_type import (
    SmithingTemplateType,
    smithing_template_from_string,
)

comptime _MATERIAL_TYPES = (
    "AmethystShard,CopperIngot,Diamond,Emerald,GoldIngot,IronIngot,"
    "LapisLazuli,NetheriteIngot,NetherQuartz,ResinBrick"
)
comptime _MATERIAL_NAMES = (
    "amethyst,copper,diamond,emerald,gold,iron,lapis,netherite,quartz,resin,"
    "redstone"
)
# gophertunnel `text` colours (`text.Amethyst`, ...): the protocol submodule
# has no text package.
comptime _MATERIAL_COLOURS = "§u,§n,§s,§q,§p,§i,§t,§j,§h,§v,§m"


trait ArmourTrimMaterial:
    """An item that may be used as the material of an armour trim."""

    def trim_material(self) -> StaticString:
        """Returns the material's identifier (Go `TrimMaterial`)."""
        ...

    def material_colour(self) -> StaticString:
        """Returns the material's text colour (Go `MaterialColour`)."""
        ...


def armour_trim_materials() -> List[AnyItem]:
    """Returns every trim material item (Go `ArmourTrimMaterials`)."""
    var out = List[AnyItem](capacity=11)
    for i in range(10):
        out.append(AnyItem(item_hash(enum_name(_MATERIAL_TYPES, i)), 0, False))
    # block.RedstoneWire{}, a block item.
    out.append(AnyItem(HASH_REDSTONE_WIRE, 0, True))
    return out^


def _material_index(material: AnyItem) -> Int:
    var all = armour_trim_materials()
    for i in range(len(all)):
        if all[i].kind == material.kind:
            return i
    return -1


def trim_material_name(material: AnyItem) -> StaticString:
    """Returns `TrimMaterial` of a material item, or "" for other items."""
    var i = _material_index(material)
    if i < 0:
        return ""
    return enum_name(_MATERIAL_NAMES, i)


def trim_material_colour(material: AnyItem) -> StaticString:
    """Returns `MaterialColour` of a material item, or "" for other items."""
    var i = _material_index(material)
    if i < 0:
        return ""
    return enum_name(_MATERIAL_COLOURS, i)


def trim_material_from_string(name: StringSlice) -> Optional[AnyItem]:
    """Returns the material item named `name` (Go
    `trimMaterialFromString`)."""
    var all = armour_trim_materials()
    for i in range(len(all)):
        if enum_name(_MATERIAL_NAMES, i) == name:
            return all[i]
    return None


@fieldwise_init
struct ArmourTrim(Defaultable, Equatable, ImplicitlyCopyable):
    """A trim applied to a piece of armour (Go `ArmourTrim`)."""

    var template: SmithingTemplateType
    """The smithing template the trim was applied with."""
    var material: Optional[AnyItem]
    """The material item of the trim; None for no trim."""

    def __init__(out self):
        """Creates the absent trim (Go `ArmourTrim{}`)."""
        self.template = SmithingTemplateType.NETHERITE_UPGRADE
        self.material = None

    def __eq__(self, other: Self) -> Bool:
        """Compares two trims."""
        if self.template != other.template:
            return False
        if self.material and other.material:
            return self.material.value() == other.material.value()
        return not self.material and not other.material

    def zero(self) -> Bool:
        """Reports whether the trim is absent (Go `Zero`)."""
        return (
            not self.material
            or self.template == SmithingTemplateType.NETHERITE_UPGRADE
        )


def read_trim(tag: Tree, root: Tag) raises -> ArmourTrim:
    """Reads the `Trim` compound of armour NBT (Go `readTrim`)."""
    if case .Some(trim) = tag.get(root, "Trim"):
        if tag.type_of(trim) != TAG_COMPOUND:
            return ArmourTrim()
        var material = String()
        var pattern = String()
        if case .Some(m) = tag.get(trim, "Material"):
            if tag.type_of(m) == TAG_STRING:
                material = tag.as_string(m)
        if case .Some(p) = tag.get(trim, "Pattern"):
            if tag.type_of(p) == TAG_STRING:
                pattern = tag.as_string(p)
        var template = smithing_template_from_string(pattern)
        var trim_material = trim_material_from_string(material)
        if template and trim_material:
            return ArmourTrim(template.value(), trim_material.value())
    return ArmourTrim()


def write_trim(mut tag: Tree, root: Tag, t: ArmourTrim) raises:
    """Writes the `Trim` compound of armour NBT (Go `writeTrim`)."""
    if t.zero():
        return
    var trim = tag.put_compound(root, "Trim")
    _ = tag.put_string(trim, "Material", trim_material_name(t.material.value()))
    _ = tag.put_string(trim, "Pattern", t.template.name())
