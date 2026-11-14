"""Inventories, ported from Dragonfly `server/item/inventory/inventory.go`.

Differences from Go:

- No locks and no `Handler`: the loop owns the inventory.
- Go's `SlotFunc` callback becomes a list of changed slots that the owner
  drains with `take_changes` (the session sends them to the client).
- Go gives every new stack a network ID from a global counter. Here an
  inventory gives a stack the next ID of its `StackIDs`, which the
  inventories of one session share, when the stack is stored without one
  (`Stack.grow` and `add_stack` clear it, as Go draws a new one there).
- Errors raise.
"""

from std.memory import ArcPointer

from ..stack import Stack


struct StackIDs(Movable):
    """The source of stack network IDs for a set of inventories."""

    var next: Int32
    """The next ID handed out."""

    def __init__(out self):
        """Starts at 1; 0 means "no ID"."""
        self.next = 1


struct Inventory(Copyable, Writable):
    """A fixed number of item stack slots (Go `inventory.Inventory`)."""

    var _slots: List[Stack]
    var _ids: ArcPointer[StackIDs]
    var _changed: List[Int]

    def __init__(out self, size: Int):
        """Creates an empty inventory with its own ID source (Go `New`)."""
        self = Self(size, ArcPointer(StackIDs()))

    def __init__(out self, size: Int, ids: ArcPointer[StackIDs]):
        """Creates an empty inventory drawing network IDs from `ids`."""
        debug_assert(size > 0, "inventory size must be at least 1")
        self._slots = List[Stack](capacity=size)
        for _ in range(size):
            self._slots.append(Stack())
        self._ids = ids
        self._changed = List[Int]()

    def size(self) -> Int:
        """Returns the number of slots (Go `Size`)."""
        return len(self._slots)

    def _check(self, slot: Int) raises:
        if slot < 0 or slot >= len(self._slots):
            raise Error(
                "slot is out of range: must be in range 0 <= slot <"
                " inventory.Size()"
            )

    def item(self, slot: Int) raises -> Stack:
        """Returns the stack in a slot (Go `Item`)."""
        self._check(slot)
        return self._slots[slot].copy()

    def set_item(mut self, slot: Int, it: Stack) raises:
        """Sets the stack in a slot, capped at its max count (Go
        `SetItem`)."""
        self._check(slot)
        self._set(slot, it)

    def _set(mut self, slot: Int, it: Stack):
        var s: Stack
        if it.empty():
            s = Stack()
        elif it.count() > it.max_count():
            s = it.grow(it.max_count() - it.count())
        else:
            s = it.copy()
        if not s.empty() and s.id() == 0:
            s = s.with_id(self._ids[].next)
            self._ids[].next += 1
        self._slots[slot] = s^
        if slot not in self._changed:
            self._changed.append(slot)

    def take_changes(mut self) -> List[Int]:
        """Returns the slots changed since the last call (Go's `SlotFunc`
        calls) and forgets them."""
        var c = self._changed^
        self._changed = List[Int]()
        return c^

    def slots(self) -> List[Stack]:
        """Returns a copy of every slot, empty ones included (Go
        `Slots`)."""
        return self._slots.copy()

    def items(self) -> List[Stack]:
        """Returns the non-empty stacks (Go `Items`)."""
        var out = List[Stack]()
        for s in self._slots:
            if not s.empty():
                out.append(s.copy())
        return out^

    def first(self, it: Stack) -> Optional[Int]:
        """Returns the first slot holding a stack comparable with `it` (Go
        `First`)."""
        for i in range(len(self._slots)):
            if not self._slots[i].empty() and self._slots[i].comparable(it):
                return i
        return None

    def first_empty(self) -> Optional[Int]:
        """Returns the first empty slot (Go `FirstEmpty`)."""
        for i in range(len(self._slots)):
            if self._slots[i].empty():
                return i
        return None

    def swap(mut self, a: Int, b: Int) raises:
        """Swaps the stacks of two slots (Go `Swap`)."""
        self._check(a)
        self._check(b)
        var sa = self._slots[a].copy()
        var sb = self._slots[b].copy()
        self._set(a, sb)
        self._set(b, sa)

    def add_item(mut self, var it: Stack) -> Int:
        """Adds a stack, filling comparable stacks first, then empty slots
        (Go `AddItem`). Returns how many items were added; fewer than the
        stack's count if the inventory is full (Go's error)."""
        if it.empty():
            return 0
        var first = it.count()
        var empty = List[Int]()
        for slot in range(len(self._slots)):
            if self._slots[slot].empty():
                empty.append(slot)
                continue
            var r = self._slots[slot].add_stack(it)
            if r[1].count() == it.count():
                continue
            self._set(slot, r[0])
            it = r[1].copy()
            if it.empty():
                return first
        for slot in empty:
            var r = it.grow(-it.count()).add_stack(it)
            self._set(slot, r[0])
            it = r[1].copy()
            if it.empty():
                return first
        return first - it.count()

    def remove_item(mut self, it: Stack) raises:
        """Removes `it.count()` items comparable with `it` (Go
        `RemoveItem`); raises if there were fewer, after removing those."""
        var n = it.count()
        for slot in range(len(self._slots)):
            ref s = self._slots[slot]
            if s.empty() or not s.comparable(it):
                continue
            var have = s.count()
            if have - n <= 0:
                self._set(slot, Stack())
            else:
                self._set(slot, self._slots[slot].grow(-n))
            n -= have
            if n <= 0:
                break
        if n > 0:
            raise Error("could not remove all items from the inventory")

    def contains_item(self, it: Stack) -> Bool:
        """Reports whether the inventory holds at least `it.count()` items
        comparable with `it` (Go `ContainsItem`)."""
        var n = it.count()
        for s in self._slots:
            if not s.empty() and s.comparable(it):
                n -= s.count()
                if n <= 0:
                    break
        return n <= 0

    def empty(self) -> Bool:
        """Reports whether every slot is empty (Go `Empty`)."""
        for s in self._slots:
            if not s.empty():
                return False
        return True

    def clear(mut self) -> List[Stack]:
        """Empties the inventory and returns the stacks it held (Go
        `Clear`)."""
        var out = List[Stack]()
        for slot in range(len(self._slots)):
            if not self._slots[slot].empty():
                out.append(self._slots[slot].copy())
                self._set(slot, Stack())
        return out^

    def write_to(self, mut writer: Some[Writer]):
        """Writes the slots as Go's `String` does: `(a, b, ...)`."""
        writer.write("(")
        for i in range(len(self._slots)):
            if i > 0:
                writer.write(", ")
            writer.write(self._slots[i])
        writer.write(")")
