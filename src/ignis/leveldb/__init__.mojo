"""A LevelDB implementation that reads and writes the on-disk format of
`github.com/df-mc/goleveldb` v1.1.9 (Dragonfly's fork of syndtr/goleveldb)
and of Mojang's LevelDB fork used by Minecraft: Bedrock Edition worlds.

Ported from goleveldb's `leveldb/` sources, one module per Go file or
package:

| Go (`df-mc/goleveldb/leveldb/`) | Mojo |
| --- | --- |
| `key.go`, `comparer.go`, `comparer/` | `key.mojo` |
| `util/hash.go`, `util/crc32.go`, varints | `util.mojo` |
| `table/writer.go` and `reader.go` block compression | `compress.mojo` |
| `journal/journal.go` | `journal.mojo` |
| `batch.go` | `batch.mojo` |
| `memdb/memdb.go` | `memdb.mojo` |
| `filter/bloom.go`, `filter.go` | `filter.mojo` |
| `table/` | `table.mojo` |
| `session_record.go` | `session_record.mojo` |
| `version.go`, `session_compaction.go` | `version.mojo` |
| `storage/file_storage.go` | `storage.mojo` |
| `db*.go`, `session*.go` | `db.mojo` |
| `db_iter.go`, `iterator/merged_iter.go` | `iterator.mojo` |
| `opt/options.go` | `options.mojo` |

Ignis is single-threaded, so the port drops goroutines, locks and
snapshots: writes go to the journal and the memtable, a full memtable is
flushed to a level-0 table synchronously, and compaction runs in bounded
steps (`DB.compact_once`) that the caller schedules.
"""
