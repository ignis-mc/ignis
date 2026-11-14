package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	_ "embed"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/df-mc/dragonfly/server/world"
	"github.com/df-mc/dragonfly/server/world/chunk"
	"github.com/sandertv/gophertunnel/minecraft/nbt"
)

type legacyEntry struct {
	Legacy struct {
		Name string `nbt:"name"`
		Meta int16  `nbt:"meta"`
	} `nbt:"legacy"`
	Updated struct {
		Name    string         `nbt:"name"`
		States  map[string]any `nbt:"states"`
		Version int32          `nbt:"version"`
	} `nbt:"updated"`
}

func fmtProps(m map[string]any) string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	for i, k := range keys {
		if i > 0 {
			b.WriteByte(',')
		}
		switch v := m[k].(type) {
		case byte:
			fmt.Fprintf(&b, "%s=b:%d", k, v)
		case int32:
			fmt.Fprintf(&b, "%s=i:%d", k, v)
		case string:
			fmt.Fprintf(&b, "%s=s:%s", k, v)
		default:
			fmt.Fprintf(&b, "%s=?%v", k, v)
		}
	}
	return b.String()
}

// upgradeVectors decodes stored block states with Dragonfly's
// BlockPaletteEncoding and writes one line per case:
// "<kind>|<name>|<version>|<meta or props>|<runtime ID or ERR>|<legacy>".
// Cases: every pre-1.13 entry of legacy_states.nbt by name and meta, every
// flattened state of that file at its version, and every registered state
// at the current block version. The full listing is hashed; see below.
func upgradeVectors(legacyPath, out string) error {
	data, err := os.ReadFile(legacyPath)
	if err != nil {
		return err
	}
	var full bytes.Buffer
	w := bufio.NewWriter(&full)
	br := world.DefaultBlockRegistry
	br.Finalize()
	// decode stores the entry as the single palette entry of a sub-chunk
	// and decodes it with chunk.DiskDecode, the only exported path that
	// reports the legacy flag.
	r := world.Overworld.Range()
	decode := func(m map[string]any) string {
		entry, err := nbt.MarshalEncoding(m, nbt.LittleEndian)
		if err != nil {
			panic(err)
		}
		sub := append([]byte{9, 1, byte(r[0] >> 4), 0}, entry...)
		subs := make([][]byte, (r.Height()>>4)+1)
		subs[0] = sub
		c, err := chunk.DiskDecode(br, chunk.SerialisedData{SubChunks: subs}, r)
		if err != nil {
			return "ERR|0"
		}
		l := 0
		if c.LegacyStates() {
			l = 1
		}
		return fmt.Sprintf("%d|%d", c.Block(0, int16(r[0]), 0, 0), l)
	}
	dec := nbt.NewDecoder(bytes.NewBuffer(data))
	var entries []legacyEntry
	for {
		var e legacyEntry
		if err := dec.Decode(&e); err != nil {
			break
		}
		entries = append(entries, e)
	}
	for _, e := range entries {
		m := map[string]any{"name": e.Legacy.Name, "val": e.Legacy.Meta, "version": int32(17694720)}
		fmt.Fprintf(w, "L|%s|%d|%d|%s\n", e.Legacy.Name, 17694720, e.Legacy.Meta, decode(m))
	}
	for _, e := range entries {
		states := map[string]any{}
		for k, v := range e.Updated.States {
			states[k] = v
		}
		m := map[string]any{"name": e.Updated.Name, "states": states, "version": e.Updated.Version}
		fmt.Fprintf(w, "U|%s|%d|%s|%s\n", e.Updated.Name, e.Updated.Version, fmtProps(e.Updated.States), decode(m))
	}
	for rid := uint32(0); ; rid++ {
		name, props, ok := br.RuntimeIDToState(rid)
		if !ok {
			break
		}
		states := map[string]any{}
		for k, v := range props {
			states[k] = v
		}
		m := map[string]any{"name": name, "states": states, "version": chunk.CurrentBlockVersion}
		fmt.Fprintf(w, "C|%s|%d|%s|%s\n", name, chunk.CurrentBlockVersion, fmtProps(props), decode(m))
	}
	if err := w.Flush(); err != nil {
		return err
	}
	// The listing is several MiB, so only its hash, its line count and
	// every 61st line are committed.
	lines := strings.Split(strings.TrimSuffix(full.String(), "\n"), "\n")
	var o strings.Builder
	fmt.Fprintf(&o, "sha256 %x\ncount %d\n", sha256.Sum256(full.Bytes()), len(lines))
	for i := 0; i < len(lines); i += 61 {
		fmt.Fprintf(&o, "%d %s\n", i, lines[i])
	}
	return os.WriteFile(out, []byte(o.String()), 0644)
}
