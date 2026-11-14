package main

import (
	"bufio"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"os"
	"sort"

	"github.com/df-mc/goleveldb/leveldb"
	"github.com/df-mc/goleveldb/leveldb/opt"
)

// rng is the xorshift64 generator mirrored by interop/mcdb/ldbtool.mojo.
type rng struct{ s uint64 }

func (r *rng) next() uint64 {
	r.s ^= r.s << 13
	r.s ^= r.s >> 7
	r.s ^= r.s << 17
	return r.s
}

type op struct {
	del        bool
	key, value []byte
}

// genBatches returns the deterministic workload: batches of puts and deletes
// over text keys, chunk-style binary keys and player keys, with values from
// empty to 40 KiB (larger than a journal block). The last batch is a single
// small put so that an unclean-stop test can tear it off.
func genBatches(seed uint64, n int) [][]op {
	r := &rng{s: seed}
	var batches [][]op
	for i := 0; i < n; {
		size := 1 + int(r.next()%5)
		var b []op
		for j := 0; j < size && i < n; j, i = j+1, i+1 {
			x := r.next()
			k := x % 2000
			var key []byte
			switch (x >> 11) % 3 {
			case 0:
				key = []byte(fmt.Sprintf("key-%05d", k))
			case 1:
				key = binary.LittleEndian.AppendUint32(nil, uint32(int32(k)-1000))
				key = binary.LittleEndian.AppendUint32(key, uint32(int32(k%37)-18))
				key = append(key, 0x2f, byte(int8(k%24)-4))
			default:
				key = []byte(fmt.Sprintf("player_%d", k))
			}
			if (x>>20)%10 >= 8 {
				b = append(b, op{del: true, key: key})
				continue
			}
			vlen := int(r.next() % 3000)
			if (x>>30)%50 == 0 {
				vlen = 40000
			}
			base := r.next()
			v := make([]byte, vlen)
			for t := range v {
				v[t] = byte(base>>((t%8)*8)) ^ byte(t/16)
			}
			b = append(b, op{key: key, value: v})
		}
		batches = append(batches, b)
	}
	batches = append(batches, []op{{key: []byte("last-key"), value: []byte("last-value")}})
	return batches
}

func apply(m map[string][]byte, b []op) {
	for _, o := range b {
		if o.del {
			delete(m, string(o.key))
		} else {
			m[string(o.key)] = o.value
		}
	}
}

func writeDump(path string, m map[string][]byte) error {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	w := bufio.NewWriter(f)
	for _, k := range keys {
		fmt.Fprintf(w, "%s\t%s\n", hex.EncodeToString([]byte(k)), hex.EncodeToString(m[k]))
	}
	if err := w.Flush(); err != nil {
		return err
	}
	return f.Close()
}

// ldbOptions are the small buffers both writers use so that a few thousand
// operations go through many flushes and compactions over several levels.
func ldbOptions() *opt.Options {
	return &opt.Options{
		BlockSize:           16 * opt.KiB,
		WriteBuffer:         64 * opt.KiB,
		CompactionTableSize: 32 * opt.KiB,
		CompactionTotalSize: 128 * opt.KiB,
	}
}

// ldbExpect writes the expected dumps of the workload: after every batch
// (expected.txt) and without the last batch (expected-torn.txt).
func ldbExpect(seed uint64, n int, out string) error {
	batches := genBatches(seed, n)
	m := map[string][]byte{}
	for _, b := range batches[:len(batches)-1] {
		apply(m, b)
	}
	if err := writeDump(out+"/expected-torn.txt", m); err != nil {
		return err
	}
	apply(m, batches[len(batches)-1])
	return writeDump(out+"/expected.txt", m)
}

// ldbWrite runs the workload against goleveldb. With unclean set it exits
// without closing the database, leaving the journal unflushed to tables.
func ldbWrite(dir string, seed uint64, n int, unclean bool) error {
	db, err := leveldb.OpenFile(dir, ldbOptions())
	if err != nil {
		return err
	}
	for _, b := range genBatches(seed, n) {
		batch := new(leveldb.Batch)
		for _, o := range b {
			if o.del {
				batch.Delete(o.key)
			} else {
				batch.Put(o.key, o.value)
			}
		}
		if err := db.Write(batch, nil); err != nil {
			return err
		}
	}
	if unclean {
		os.Exit(0)
	}
	return db.Close()
}

// ldbDump opens a database with goleveldb and dumps every key and value.
func ldbDump(dir, out string) error {
	db, err := leveldb.OpenFile(dir, ldbOptions())
	if err != nil {
		return err
	}
	m := map[string][]byte{}
	it := db.NewIterator(nil, nil)
	for it.Next() {
		m[string(it.Key())] = append([]byte(nil), it.Value()...)
	}
	it.Release()
	if err := it.Error(); err != nil {
		return err
	}
	// Point lookups must agree with the iterator.
	for k, v := range m {
		got, err := db.Get([]byte(k), nil)
		if err != nil || string(got) != string(v) {
			return fmt.Errorf("get %x disagrees with the iterator: %v", k, err)
		}
	}
	if err := writeDump(out, m); err != nil {
		return err
	}
	return db.Close()
}
