// Command ui writes test vectors for Ignis's player UI packages from
// Dragonfly v0.11.6 and gophertunnel v1.63.0.
//
// Usage (from the repository root):
//
//	(cd interop/ui && go run . -out ../../test/data/ui)
//	(cd interop/ui && go run . -entities ../../src/ignis/text/entity.mojo)
package main

import (
	"flag"
)

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	out := flag.String("out", "../../test/data/ui", "output directory")
	entities := flag.String("entities", "", "write the HTML entity table to this file instead")
	flag.Parse()
	if *entities != "" {
		writeEntities(*entities)
		return
	}
	writeVectors(*out)
}
