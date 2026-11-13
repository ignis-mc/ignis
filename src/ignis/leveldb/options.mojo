"""Database options, after goleveldb `opt/options.go`. Defaults are
goleveldb's, except where noted."""

from .compress import FLATE_COMPRESSION

comptime KIB = 1024
"""One kibibyte."""
comptime MIB = 1024 * KIB
"""One mebibyte."""


@fieldwise_init
struct Options(Copyable, Defaultable, Movable):
    """The tunable parameters of a `DB` (Go `opt.Options`)."""

    var block_size: Int
    """The target uncompressed size of a data block (Go `BlockSize`;
    default 4 KiB, Dragonfly's mcdb uses 16 KiB)."""
    var block_restart_interval: Int
    """Entries between restart points (Go `BlockRestartInterval`; 16)."""
    var compression: UInt8
    """The block compression type (Go `Compression`; df-mc's default is
    raw DEFLATE, type 4, as vanilla Bedrock writes)."""
    var filter_bits_per_key: Int
    """Bloom filter bits per key, 0 for none (Go `Filter`; goleveldb and
    Dragonfly default to none)."""
    var write_buffer: Int
    """The memtable size that triggers a flush to level 0 (Go
    `WriteBuffer`; 4 MiB)."""
    var compaction_table_size: Int
    """The size at which compaction output tables are split (Go
    `CompactionTableSize`; 2 MiB)."""
    var compaction_l0_trigger: Int
    """The level-0 table count that triggers a compaction (Go
    `CompactionL0Trigger`; 4)."""
    var compaction_total_size: Int
    """The total table size of level 1; level n allows this times 10^(n-1)
    (Go `CompactionTotalSize`; 10 MiB)."""
    var sync: Bool
    """Whether every write syncs the journal (Go `WriteOptions.Sync`;
    false). The manifest is always synced."""
    var strict: Bool
    """Whether corruption in the journal or manifest fails `open` instead
    of being skipped (Go `Strict`; false)."""

    def __init__(out self):
        """Creates goleveldb's default options."""
        self.block_size = 4 * KIB
        self.block_restart_interval = 16
        self.compression = FLATE_COMPRESSION
        self.filter_bits_per_key = 0
        self.write_buffer = 4 * MIB
        self.compaction_table_size = 2 * MIB
        self.compaction_l0_trigger = 4
        self.compaction_total_size = 10 * MIB
        self.sync = False
        self.strict = False
