"""Item stacks, ported from Dragonfly `server/item/stack.go`.

Differences from Go:

- A stack holds an `AnyItem` and the `ItemInfo` of its type (maximum count,
  durability), computed when the stack is created, instead of asking the
  item through interfaces on every call.
- Go gives every new stack a unique network ID from a global counter.
  Ignis has no globals: stacks start with ID 0 and the layer that sends
  them assigns IDs (`with_id`).
- Not ported yet: user values (`WithValue`, gob-encoded as
  `dragonflyData`), compatibility checks of `WithEnchantments` (only
  `with_forced_enchantments` exists, taking enchantment IDs), nameable
  items (`WithCustomName` renaming containers), `AttackDamage`, and the
  `BrokenItem` a durable item turns into (every ported item breaks into
  nothing).
- `comparable` compares items by type and hash rather than by encoded name;
  they differ only for distinct values that encode to the same name.
- Go's stack holds the item value. Ignis holds its `AnyItem` (type and
  hash) and, for `NBTer` items, the item's `EncodeNBT` as a `Tree`, which
  `item_as` decodes back into the value.
"""

from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.nbt.tree import Tree
from std.os import abort

from ..world.block import NBTer
from ..world.item import AnyItem, Item, ItemInfo, RegisteredItem
from .item import item_info


@fieldwise_init
struct Enchantment(Equatable, ImplicitlyCopyable, Writable):
    """An enchantment on a stack (Go `Enchantment`), identified by its
    enchantment ID until enchantment types are ported."""

    var id: Int16
    """The enchantment ID (Go `EnchantmentID`)."""
    var level: Int
    """The level."""


struct Stack(Copyable, Defaultable, Equatable, Writable):
    """A stack of items of one type with a count (Go `Stack`)."""

    var _id: Int32
    var _item: AnyItem
    var _info: ItemInfo
    var _count: Int
    var _custom_name: String
    var _lore: List[String]
    var _damage: Int
    var _unbreakable: Bool
    var _anvil_cost: Int
    var _enchantments: List[Enchantment]
    var _nbt: Tree

    def __init__(out self):
        """Creates an empty stack (Go `Stack{}`)."""
        self._id = 0
        self._item = AnyItem(0, 0, False)
        self._info = ItemInfo()
        self._info.air = True
        self._count = 0
        self._custom_name = String()
        self._lore = List[String]()
        self._damage = 0
        self._unbreakable = False
        self._anvil_cost = 0
        self._enchantments = List[Enchantment]()
        self._nbt = Tree()

    def __init__[T: Item](out self, it: T, count: Int):
        """Creates a stack of a typed item (Go `NewStack`). Aborts if the
        count is negative, as Go panics.

        Parameters:
            T: The item type.

        Args:
            it: The item.
            count: The count.
        """
        self = Self(RegisteredItem(AnyItem.of(it), item_info(it)), count)
        comptime if conforms_to(T, NBTer):
            try:
                _encode_nbt(it, self._nbt)
            except e:
                abort(String(t"cannot encode item NBT: {e}"))

    def __init__(out self, it: RegisteredItem, count: Int):
        """Creates a stack of an item of unknown type, as found in the
        `ItemRegistry`. Aborts if the count is negative.

        Args:
            it: The item and its info.
            count: The count.
        """
        if count < 0:
            abort("cannot use negative count for item stack")
        self = Self()
        self._item = it.item
        self._info = it.info
        self._count = count

    def __eq__(self, other: Self) -> Bool:
        """Reports whether two stacks are equal (Go `Equal`): comparable,
        with the same count and damage.

        Args:
            other: The other stack.

        Returns:
            True if equal.
        """
        return (
            self.comparable(other)
            and self._count == other._count
            and self._damage == other._damage
        )

    def id(self) -> Int32:
        """Returns the stack's network ID (Go's unexported `id`).

        Returns:
            The ID set with `with_id`, or 0.
        """
        return self._id

    def with_id(self, id: Int32) -> Self:
        """Returns a copy of the stack with a network ID.

        Args:
            id: The ID.

        Returns:
            The stack.
        """
        var s = self.copy()
        s._id = id
        return s^

    def count(self) -> Int:
        """Returns the number of items on the stack (Go `Count`).

        Returns:
            The count; never negative.
        """
        return self._count

    def max_count(self) -> Int:
        """Returns the maximum count of the stack (Go `MaxCount`).

        Returns:
            The item's `MaxCount`, or 64.
        """
        return self._info.max_count

    def info(self) -> ItemInfo:
        """Returns what the stack knows about its item type.

        Returns:
            The item info.
        """
        return self._info

    def grow(self, n: Int) -> Self:
        """Returns the stack with its count changed by `n`, never below 0
        (Go `Grow`).

        Args:
            n: The change; negative to shrink.

        Returns:
            The stack.
        """
        var s = self.copy()
        s._count = max(s._count + n, 0)
        # Go gives the result a new network ID; 0 lets the inventory assign
        # the next one.
        s._id = 0
        return s^

    def durability(self) -> Int:
        """Returns the current durability (Go `Durability`).

        Returns:
            The durability left, or -1 if the item is not durable.
        """
        if not self._info.durable():
            return -1
        return self._info.max_durability - self._damage

    def max_durability(self) -> Int:
        """Returns the maximum durability (Go `MaxDurability`).

        Returns:
            The maximum durability, or -1 if the item is not durable.
        """
        return self._info.max_durability

    def damage(self, d: Int) -> Self:
        """Returns the stack damaged by `d` (Go `Damage`). A negative `d`
        repairs. At durability 0 the item breaks into an empty stack unless
        it is persistent; durability never exceeds the maximum.

        Args:
            d: The damage.

        Returns:
            The stack.
        """
        if not self._info.durable() or self._unbreakable:
            return self.copy()
        var durability = self.durability()
        if durability - d <= 0:
            if self._info.persistent:
                return self.copy()
            return Self()
        var s = self.copy()
        var dd = d
        if durability - d > self._info.max_durability:
            s._damage = 0
            dd = 0
        s._damage += dd
        return s^

    def with_durability(self, d: Int) -> Self:
        """Returns the stack with durability `d` (Go `WithDurability`).

        Args:
            d: The durability; 0 breaks the item, above the maximum repairs
                it fully.

        Returns:
            The stack.
        """
        if not self._info.durable():
            return self.copy()
        var s = self.copy()
        if d > self._info.max_durability:
            s._damage = 0
            return s^
        if d == 0:
            return Self()
        s._damage = self._info.max_durability - d
        return s^

    def unbreakable(self) -> Bool:
        """Reports whether the stack is unbreakable (Go `Unbreakable`).

        Returns:
            The flag.
        """
        return self._unbreakable

    def as_unbreakable(self) -> Self:
        """Returns the stack marked unbreakable if the item is durable (Go
        `AsUnbreakable`).

        Returns:
            The stack.
        """
        var s = self.copy()
        if s._info.durable():
            s._unbreakable = True
        return s^

    def as_breakable(self) -> Self:
        """Returns the stack without the unbreakable mark if the item is
        durable (Go `AsBreakable`).

        Returns:
            The stack.
        """
        var s = self.copy()
        if s._info.durable():
            s._unbreakable = False
        return s^

    def empty(self) -> Bool:
        """Reports whether the stack is empty: no items, or air (Go
        `Empty`).

        Returns:
            True if empty.
        """
        return self._count == 0 or self._info.air

    def item(self) -> Optional[AnyItem]:
        """Returns the item of the stack (Go `Item`).

        Returns:
            The item, or None if the stack is empty.
        """
        if self.empty():
            return None
        return self._item

    def item_as[T: Item](self) -> Optional[T]:
        """Returns the item as a `T` (Go `s.Item().(T)`).

        Parameters:
            T: The item type.

        Returns:
            The item, or None if the stack is empty or holds another type.
        """
        if self.empty():
            return None
        var it = self._item.get[T]()
        comptime if conforms_to(T, NBTer):
            if it and has_nbt(self._nbt):
                try:
                    return _decode_nbt(it.value(), self._nbt)
                except:
                    return it^
        return it^

    def item_nbt(self) -> Tree:
        """Returns the NBT of the item value (Go `s.Item().(world.NBTer)
        .EncodeNBT()`); an empty compound for other items."""
        return self._nbt.copy()

    def with_item_nbt(self, var data: Tree) -> Self:
        """Returns the stack with the item's NBT replaced (Go: a stack of
        the item after `DecodeNBT`)."""
        var s = self.copy()
        s._nbt = data^
        return s^

    def with_custom_name(self, name: String) -> Self:
        """Returns the stack with a custom name (Go `WithCustomName`).

        Args:
            name: The name; empty to clear it.

        Returns:
            The stack.
        """
        var s = self.copy()
        s._custom_name = name
        return s^

    def custom_name(self) -> String:
        """Returns the custom name (Go `CustomName`).

        Returns:
            The name, or an empty string.
        """
        return self._custom_name

    def with_lore(self, var lines: List[String]) -> Self:
        """Returns the stack with lore lines, top first (Go `WithLore`).

        Args:
            lines: The lines; empty to clear the lore.

        Returns:
            The stack.
        """
        var s = self.copy()
        s._lore = lines^
        return s^

    def lore(self) -> List[String]:
        """Returns the lore lines (Go `Lore`).

        Returns:
            The lines; none if the stack is empty.
        """
        if self.empty():
            return List[String]()
        return self._lore.copy()

    def with_forced_enchantments(self, enchants: List[Enchantment]) -> Self:
        """Returns the stack with enchantments added or replaced, without
        compatibility checks (Go `WithForcedEnchantments`).

        Args:
            enchants: The enchantments.

        Returns:
            The stack.
        """
        var s = self.copy()
        for e in enchants:
            var replaced = False
            for i in range(len(s._enchantments)):
                if s._enchantments[i].id == e.id:
                    s._enchantments[i] = e
                    replaced = True
            if not replaced:
                s._enchantments.append(e)
        return s^

    def without_enchantments(self, ids: List[Int16]) -> Self:
        """Returns the stack without the enchantments passed (Go
        `WithoutEnchantments`).

        Args:
            ids: The enchantment IDs to remove.

        Returns:
            The stack.
        """
        var s = self.copy()
        var kept = List[Enchantment]()
        for e in s._enchantments:
            if e.id not in ids:
                kept.append(e)
        s._enchantments = kept^
        return s^

    def enchantment(self, id: Int16) -> Optional[Enchantment]:
        """Returns an enchantment of the stack (Go `Enchantment`).

        Args:
            id: The enchantment ID.

        Returns:
            The enchantment, or None.
        """
        if self.empty():
            return None
        for e in self._enchantments:
            if e.id == id:
                return e
        return None

    def enchantments(self) -> List[Enchantment]:
        """Returns the enchantments sorted by ID (Go `Enchantments`).

        Returns:
            The enchantments; none if the stack is empty.
        """
        var out = List[Enchantment]()
        if self.empty():
            return out^
        for e in self._enchantments:
            var i = len(out)
            while i > 0 and out[i - 1].id > e.id:
                i -= 1
            out.insert(i, e)
        return out^

    def anvil_cost(self) -> Int:
        """Returns the anvil cost (Go `AnvilCost`).

        Returns:
            The experience levels added to anvil uses.
        """
        return self._anvil_cost

    def with_anvil_cost(self, anvil_cost: Int) -> Self:
        """Returns the stack with an anvil cost, if the item is repairable
        (Go `WithAnvilCost`).

        Args:
            anvil_cost: The cost.

        Returns:
            The stack.
        """
        var s = self.copy()
        if s._info.repairable:
            s._anvil_cost = anvil_cost
        return s^

    def add_stack(self, s2: Self) -> Tuple[Self, Self]:
        """Moves as many items of `s2` onto the stack as fit (Go
        `AddStack`).

        Args:
            s2: The stack to take items from.

        Returns:
            The filled stack and what is left of `s2`; both unchanged if
            the stacks are not comparable or the stack is full.
        """
        if self._count >= self.max_count() or not self.comparable(s2):
            return (self.copy(), s2.copy())
        var diff = min(self.max_count() - self._count, s2._count)
        var a = self.copy()
        var b = s2.copy()
        a._count += diff
        b._count -= diff
        # Go gives both new network IDs.
        a._id = 0
        b._id = 0
        return (a^, b^)

    def comparable(self, s2: Self) -> Bool:
        """Reports whether two stacks hold the same item with the same
        properties, ignoring count and damage, or one is empty (Go
        `Comparable`).

        Args:
            s2: The other stack.

        Returns:
            True if comparable.
        """
        if self.empty() or s2.empty():
            return True
        if (
            self._item != s2._item
            or self._anvil_cost != s2._anvil_cost
            or self._custom_name != s2._custom_name
            or self._lore != s2._lore
            or len(self._enchantments) != len(s2._enchantments)
        ):
            return False
        for e in self._enchantments:
            if case .Some(other) = s2.enchantment(e.id):
                if other != e:
                    return False
            else:
                return False
        try:
            return (
                to_nbt(self._nbt, LITTLE_ENDIAN).raw
                == to_nbt(s2._nbt, LITTLE_ENDIAN).raw
            )
        except:
            return False

    def write_to(self, mut writer: Some[Writer]):
        """Writes the stack for debugging (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            "Stack<",
            self._item,
            ">(custom name='",
            self._custom_name,
            "', damage=",
            self._damage,
            ", anvilCost=",
            self._anvil_cost,
            ") x",
            self._count,
        )


def _encode_nbt[T: NBTer](it: T, mut out: Tree) raises:
    it.encode_nbt(out, out.root())


def _decode_nbt[T: NBTer](it: T, data: Tree) raises -> T:
    return it.decode_nbt(data, data.root())


def has_nbt(t: Tree) -> Bool:
    """Reports whether a compound tree has at least one entry."""
    try:
        return len(t.children(t.root())) != 0
    except:
        return False
