"""SmithingTemplate, ported from Dragonfly
`server/item/smithing_template.go`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .smithing_template_type import SmithingTemplateType, smithing_templates


struct SmithingTemplate(Equatable, ImplicitlyCopyable, Item):
    """An item used in smithing tables to alter tools and armour."""

    comptime BASE_HASH: UInt64 = item_hash("SmithingTemplate")
    """`item_hash("SmithingTemplate")`."""

    var template: SmithingTemplateType
    """The template."""

    def __init__(
        out self, *, template: SmithingTemplateType = SmithingTemplateType(0)
    ):
        """Creates the item; omitted fields take Go zero values."""
        self.template = template

    def __eq__(self, other: Self) -> Bool:
        """Compares two items."""
        return self.template == other.template

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.template == SmithingTemplateType.NETHERITE_UPGRADE:
            return EncodedItem(
                "minecraft:netherite_upgrade_smithing_template", 0
            )
        return EncodedItem(
            String(
                "minecraft:",
                self.template.name(),
                "_armor_trim_smithing_template",
            ),
            0,
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the template's index."""
        return UInt64(self.template.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(template=SmithingTemplateType(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every template."""
        var out = List[Self]()
        for t in smithing_templates():
            out.append(Self(template=t))
        return out^
