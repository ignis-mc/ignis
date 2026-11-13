// Command mcdb produces and checks the LevelDB and world fixtures for the
// Mojo ports in src/ignis/leveldb and src/ignis/world/mcdb.
//
//	go run . ldb-expect <seed> <n> <outdir>
//	go run . ldb-write <dir> <seed> <n> [unclean]
//	go run . ldb-dump <dir> <out.txt>
//	go run . ldb-fixtures <outdir>
//	go run . upgrade-vectors <legacy_states.nbt> <out.txt>
package main

import (
	"fmt"
	"os"
	"strconv"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func atoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		panic(err)
	}
	return n
}

func run(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("missing command")
	}
	switch args[0] {
	case "ldb-expect":
		return ldbExpect(uint64(atoi(args[1])), atoi(args[2]), args[3])
	case "ldb-write":
		return ldbWrite(args[1], uint64(atoi(args[2])), atoi(args[3]), len(args) > 4 && args[4] == "unclean")
	case "ldb-fixtures":
		return ldbFixtures(args[1])
	case "upgrade-vectors":
		return upgradeVectors(args[1], args[2])
	case "ldb-dump":
		return ldbDump(args[1], args[2])
	}
	return fmt.Errorf("unknown command %q", args[0])
}
