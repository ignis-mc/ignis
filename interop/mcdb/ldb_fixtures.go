package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"

	"github.com/df-mc/goleveldb/leveldb/comparer"
	"github.com/df-mc/goleveldb/leveldb/filter"
	"github.com/df-mc/goleveldb/leveldb/journal"
	"github.com/df-mc/goleveldb/leveldb/opt"
	"github.com/df-mc/goleveldb/leveldb/table"
)

// icmp is goleveldb's unexported internal-key comparer (comparer.go),
// copied so that table.Writer can be driven with internal keys.
type icmp struct{}

func ukey(k []byte) []byte { return k[:len(k)-8] }
func knum(k []byte) uint64 { return binary.LittleEndian.Uint64(k[len(k)-8:]) }
func (icmp) Name() string  { return "leveldb.BytewiseComparator" }
func (icmp) Compare(a, b []byte) int {
	if x := bytes.Compare(ukey(a), ukey(b)); x != 0 {
		return x
	}
	if m, n := knum(a), knum(b); m > n {
		return -1
	} else if m < n {
		return 1
	}
	return 0
}

var maxNum = func() []byte {
	b := make([]byte, 8)
	binary.LittleEndian.PutUint64(b, (uint64(1)<<56-1)<<8|1)
	return b
}()

func (icmp) Separator(dst, a, b []byte) []byte {
	ua, ub := ukey(a), ukey(b)
	dst = comparer.DefaultComparer.Separator(dst, ua, ub)
	if dst != nil && len(dst) < len(ua) && bytes.Compare(ua, dst) < 0 {
		return append(dst, maxNum...)
	}
	return nil
}

func (icmp) Successor(dst, b []byte) []byte {
	ub := ukey(b)
	dst = comparer.DefaultComparer.Successor(dst, ub)
	if dst != nil && len(dst) < len(ub) && bytes.Compare(ub, dst) < 0 {
		return append(dst, maxNum...)
	}
	return nil
}

// ifilter is goleveldb's unexported iFilter (filter.go): the DB wraps the
// configured filter so that it hashes user keys only.
type ifilter struct{ filter.Filter }

func (f ifilter) Contains(flt, key []byte) bool { return f.Filter.Contains(flt, ukey(key)) }
func (f ifilter) NewGenerator() filter.FilterGenerator {
	return igen{f.Filter.NewGenerator()}
}

type igen struct{ filter.FilterGenerator }

func (g igen) Add(key []byte) { g.FilterGenerator.Add(ukey(key)) }

// ikey builds an internal key.
func ikey(u []byte, seq uint64, kt byte) []byte {
	return binary.LittleEndian.AppendUint64(append([]byte(nil), u...), seq<<8|uint64(kt))
}

// tableEntries are the entries of the table fixtures, mirrored by
// test/ignis/leveldb/test_table.mojo: 600 keys with shared prefixes, two
// versions of every 10th key and a deletion of every 7th.
func tableEntries() (keys, values [][]byte) {
	seq := uint64(1000)
	for i := 0; i < 600; i++ {
		u := []byte(fmt.Sprintf("key-%05d-%s", i*3, bytes.Repeat([]byte{'x'}, i%13)))
		if i%7 == 0 {
			keys = append(keys, ikey(u, seq, 0))
			values = append(values, nil)
			seq--
		}
		if i%10 == 0 {
			keys = append(keys, ikey(u, seq, 1))
			values = append(values, []byte(fmt.Sprintf("new-%d", i)))
			seq--
		}
		v := make([]byte, i%97)
		for j := range v {
			v[j] = byte(i + j*j)
		}
		keys = append(keys, ikey(u, seq, 1))
		values = append(values, v)
		seq--
	}
	return
}

// ldbFixtures writes the table and journal fixtures to dir.
func ldbFixtures(dir string) error {
	keys, values := tableEntries()
	for _, c := range []struct {
		name   string
		comp   opt.Compression
		filter bool
	}{
		{"table-none.ldb", opt.NoCompression, false},
		{"table-none-bloom.ldb", opt.NoCompression, true},
		{"table-snappy.ldb", opt.SnappyCompression, false},
		{"table-flate-bloom.ldb", opt.FlateCompression, true},
	} {
		var buf bytes.Buffer
		o := &opt.Options{Comparer: icmp{}, Compression: c.comp, BlockSize: 1024}
		if c.filter {
			o.Filter = ifilter{filter.NewBloomFilter(10)}
		}
		w := table.NewWriter(&buf, o)
		for i := range keys {
			if err := w.Append(keys[i], values[i]); err != nil {
				return err
			}
		}
		if err := w.Close(); err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(dir, c.name), buf.Bytes(), 0644); err != nil {
			return err
		}
	}
	var buf bytes.Buffer
	jw := journal.NewWriter(&buf)
	for _, n := range journalRecordSizes() {
		w, err := jw.Next()
		if err != nil {
			return err
		}
		rec := make([]byte, n)
		for i := range rec {
			rec[i] = byte(n + i)
		}
		if _, err := w.Write(rec); err != nil {
			return err
		}
	}
	if err := jw.Close(); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "journal.log"), buf.Bytes(), 0644)
}

// journalRecordSizes exercise full, first/middle/last chunks, an empty
// record and block tails of exactly 7 and fewer than 7 bytes.
func journalRecordSizes() []int {
	return []int{0, 1, 100, 32768 - 7 - 107 - 7 - 7, 0, 40000, 32768 * 2, 32768 - 7 - 5, 10}
}
