// Command session writes the session data Ignis sends that Dragonfly v0.11.6
// computes from packages Ignis has not ported yet:
//
//   - biome_definitions.bin: the payload of the BiomeDefinitionList packet
//     Dragonfly's session sends on join (Session.sendBiomes over every
//     vanilla biome registered by server/world/biome).
//
// Usage (from the repository root):
//
//	(cd interop/session && go run . -out ../../resources)
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/df-mc/dragonfly/server/world"
	_ "github.com/df-mc/dragonfly/server/world/biome"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
)

func main() {
	out := flag.String("out", "../../resources", "the directory to write to")
	flag.Parse()

	definitions, stringList := world.BiomeDefinitions()
	pk := &packet.BiomeDefinitionList{BiomeDefinitions: definitions, StringList: stringList}
	buf := bytes.NewBuffer(nil)
	pk.Marshal(protocol.NewWriter(buf, 0))
	path := filepath.Join(*out, "biome_definitions.bin")
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		panic(err)
	}
	sum := sha256.Sum256(buf.Bytes())
	fmt.Printf("%s: %d biomes, %d strings, %d bytes, sha256 %s\n", path, len(definitions), len(stringList), buf.Len(), hex.EncodeToString(sum[:]))
}
