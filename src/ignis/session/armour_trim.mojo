"""The armour trim packet, ported from `sendArmourTrimData` in Dragonfly
`server/session/player.go`."""

from minecraft.protocol.packet.trim_data import TrimData
from minecraft.protocol.trim import TrimMaterial, TrimPattern

from ..item.armour_trim import armour_trim_materials
from ..item.register import VanillaBlockItems, VanillaItems
from ..item.smithing_template import SmithingTemplate
from ..item.smithing_template_type import (
    SmithingTemplateType,
    smithing_templates,
)


def trim_data() raises -> TrimData:
    """Builds the `TrimData` packet: every trim pattern but the netherite
    upgrade, and every trim material (Go `sendArmourTrimData`)."""
    var pk = TrimData()
    for t in smithing_templates():
        if t == SmithingTemplateType.NETHERITE_UPGRADE:
            continue
        var p = TrimPattern()
        p.item_name = SmithingTemplate(template=t).encode_item().name
        p.pattern_id = String(t)
        pk.patterns.append(p^)
    for it in armour_trim_materials():
        var material: Optional[StaticString]
        var colour: Optional[StaticString]
        var name: String
        if it.block:
            material = VanillaBlockItems.trim_material(it.kind, it.hash)
            colour = VanillaBlockItems.material_colour(it.kind, it.hash)
            name = VanillaBlockItems.encode_item(it.kind, it.hash).value().name
        else:
            material = VanillaItems.trim_material(it.kind, it.hash)
            colour = VanillaItems.material_colour(it.kind, it.hash)
            name = VanillaItems.encode_item(it.kind, it.hash).value().name
        if not material:
            continue
        var m = TrimMaterial()
        m.material_id = String(material.value())
        m.colour = String(colour.value())
        m.item_name = name^
        pk.materials.append(m^)
    return pk^
