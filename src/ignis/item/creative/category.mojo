"""`Category`, ported from Dragonfly `server/item/creative/category.go`."""


@fieldwise_init
struct Category(Equatable, ImplicitlyCopyable, Writable):
    """A tab of the creative inventory (Go `creative.Category`)."""

    var _v: UInt8

    comptime CONSTRUCTION = Category(1)
    """Blocks that fall in no other category (Go `ConstructionCategory`)."""
    comptime NATURE = Category(2)
    """Blocks and items found in nature (Go `NatureCategory`)."""
    comptime EQUIPMENT = Category(3)
    """Tools, armour, food and other equipment (Go `EquipmentCategory`)."""
    comptime ITEMS = Category(4)
    """Miscellaneous items (Go `ItemsCategory`)."""

    def uint8(self) -> UInt8:
        """Returns the category as sent in `CreativeContent` (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the category's number."""
        writer.write(self._v)
