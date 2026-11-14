"""The set of live tables per level and compaction picking, ported from
goleveldb `version.go` and `session_compaction.go` (simplified: no
snapshots, no seek-triggered compactions, no grandparent splitting).

Level 0 tables may overlap and are kept newest first (by file number);
tables of the other levels do not overlap and are sorted by key.
"""

from .key import compare_internal, ukey
from .session_record import AddedTable, SessionRecord
from .storage import table_path
from .table import Table
from .util import compare_bytes

comptime NUM_LEVELS = 7
"""The number of levels (C++ `config::kNumLevels`, goleveldb's default)."""


def _overlaps(
    t: Table, umin: Span[mut=False, UInt8, _], umax: Span[mut=False, UInt8, _]
) -> Bool:
    return not (
        compare_bytes(ukey(Span(t.imax)), umin) < 0
        or compare_bytes(ukey(Span(t.imin)), umax) > 0
    )


struct Version(Copyable, Movable):
    """The tables of every level (Go `version`)."""

    var levels: List[List[Table]]
    """The tables of each level."""

    def __init__(out self):
        """Creates an empty version."""
        self.levels = List[List[Table]]()
        for _ in range(NUM_LEVELS):
            self.levels.append(List[Table]())

    def table_count(self) -> Int:
        """Returns the number of tables in every level."""
        var n = 0
        for l in self.levels:
            n += len(l)
        return n

    def level_size(self, level: Int) -> Int:
        """Returns the total file size of a level."""
        var n = 0
        for t in self.levels[level]:
            n += t.size
        return n

    def has_table(self, num: Int) -> Bool:
        """Reports whether a file number is a live table."""
        for l in self.levels:
            for t in l:
                if t.num == num:
                    return True
        return False

    def apply(mut self, rec: SessionRecord, dir: StringSlice) raises:
        """Applies an edit: removes deleted tables and opens added ones."""
        for d in rec.deleted:
            if d[0] < 0 or d[0] >= NUM_LEVELS:
                raise Error(t"leveldb: invalid level {d[0]}")
            ref l = self.levels[d[0]]
            for i in range(len(l)):
                if l[i].num == d[1]:
                    _ = l.pop(i)
                    break
        for a in rec.added:
            self.add_at(a.level, open_table(dir, a))

    def add_at(mut self, level: Int, var t: Table) raises:
        """Inserts an open table into a level, keeping the level's order."""
        if level < 0 or level >= NUM_LEVELS:
            raise Error(t"leveldb: invalid level {level}")
        ref l = self.levels[level]
        var i = 0
        if level == 0:
            while i < len(l) and l[i].num > t.num:
                i += 1
        else:
            while (
                i < len(l)
                and compare_internal(Span(l[i].imin), Span(t.imin)) < 0
            ):
                i += 1
        l.insert(i, t^)

    def overlapping(
        self,
        level: Int,
        umin: Span[mut=False, UInt8, _],
        umax: Span[mut=False, UInt8, _],
    ) -> List[Int]:
        """Returns the indices of the tables of a level whose user key range
        intersects `[umin, umax]`."""
        var out = List[Int]()
        for i in range(len(self.levels[level])):
            if _overlaps(self.levels[level][i], umin, umax):
                out.append(i)
        return out^

    def base_level_for_key(
        self, level: Int, uk: Span[mut=False, UInt8, _]
    ) -> Bool:
        """Reports whether no level deeper than `level` may hold `uk`, so a
        deletion marker for it can be dropped."""
        for l in range(level + 1, NUM_LEVELS):
            for t in self.levels[l]:
                if not (
                    compare_bytes(ukey(Span(t.imax)), uk) < 0
                    or compare_bytes(ukey(Span(t.imin)), uk) > 0
                ):
                    return False
        return True


def open_table(dir: StringSlice, a: AddedTable) raises -> Table:
    """Opens the table an edit adds."""
    return Table(
        a.num, a.size, table_path(dir, a.num), a.imin.copy(), a.imax.copy()
    )
