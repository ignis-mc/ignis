// Command cmd writes test vectors for Ignis's command framework from
// Dragonfly v0.11.6: the output of executing sample command lines, the usage
// strings of the sample commands, and the AvailableCommands packets that
// session.BuildAvailableCommands builds for them.
//
// Usage (from the repository root):
//
//	(cd interop/cmd && go run . -out ../../test/data/cmd)
package main

import (
	"bytes"
	"encoding/hex"
	"flag"
	"fmt"
	"math"
	"math/rand/v2"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"

	"github.com/df-mc/dragonfly/server/cmd"
	"github.com/df-mc/dragonfly/server/session"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/go-gl/mathgl/mgl64"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"golang.org/x/text/language"
)

// source is the command source: an operator or a plain user.
type source struct {
	name string
	op   bool
	out  *cmd.Output
}

func (s *source) Position() mgl64.Vec3            { return mgl64.Vec3{1, 2, 3} }
func (s *source) Name() string                    { return s.name }
func (s *source) SendCommandOutput(o *cmd.Output) { s.out = o }
func isOp(src cmd.Source) bool                    { s, ok := src.(*source); return ok && s.op }
func f64(f float64) string                        { return fmt.Sprintf("%016x", math.Float64bits(f)) }
func f32(f float32) string                        { return fmt.Sprintf("%08x", math.Float32bits(f)) }
func targets(t []cmd.Target) string               { return fmt.Sprint(len(t)) }
func optTargets(t cmd.Optional[[]cmd.Target]) string {
	v, ok := t.Load()
	if !ok {
		return "unset"
	}
	return targets(v)
}

// GameMode is an Enum parameter.
type GameMode string

func (GameMode) Type() string { return "GameMode" }
func (GameMode) Options(cmd.Source) []string {
	return []string{"survival", "creative", "adventure", "spectator"}
}

// Item is an Enum whose options depend on the source; it is sent as a soft
// enum in one of the packets.
type Item string

func (Item) Type() string { return "Item" }
func (Item) Options(src cmd.Source) []string {
	if isOp(src) {
		return []string{"apple", "bread", "diamond", "creative"}
	}
	return []string{"apple", "bread"}
}

// Coord is a Parameter: a number optionally prefixed with ~.
type Coord string

func (Coord) Type() string                                { return "coord" }
func (Coord) Parse(line *cmd.Line, v reflect.Value) error { return parseCoord(line, v) }

// parseCoord accepts an optional ~ followed by decimal digits.
func parseCoord(line *cmd.Line, v reflect.Value) error {
	arg, ok := line.Next()
	if !ok {
		return line.UsageError()
	}
	for _, c := range strings.TrimPrefix(arg, "~") {
		if c < '0' || c > '9' {
			return cmd.MessageNumberInvalid.F(arg)
		}
	}
	v.SetString(arg)
	return nil
}

type GameModeSet struct {
	Mode   GameMode                   `cmd:"mode"`
	Player cmd.Optional[[]cmd.Target] `cmd:"player"`
}

func (c GameModeSet) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("gamemode set %v %v", c.Mode, optTargets(c.Player))
}

type GameModeInt struct {
	Mode   int                        `cmd:"mode"`
	Player cmd.Optional[[]cmd.Target] `cmd:"player"`
}

func (c GameModeInt) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("gamemode int %v %v", c.Mode, optTargets(c.Player))
}

type TpPos struct {
	Destination mgl64.Vec3 `cmd:"destination"`
}

func (c TpPos) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("tp pos %v %v %v", f64(c.Destination[0]), f64(c.Destination[1]), f64(c.Destination[2]))
}

type TpTargets struct {
	Victim      []cmd.Target `cmd:"victim"`
	Destination []cmd.Target `cmd:"destination"`
}

func (c TpTargets) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("tp targets %v %v", targets(c.Victim), targets(c.Destination))
}

type Say struct {
	Message cmd.Varargs `cmd:"message"`
}

func (c Say) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("say [%v]", c.Message)
}

type XpLevels struct {
	Amount int32                      `cmd:"amount,L"`
	Player cmd.Optional[[]cmd.Target] `cmd:"player"`
}

func (c XpLevels) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("xp levels %v %v", c.Amount, optTargets(c.Player))
}

type XpPoints struct {
	Amount int32                      `cmd:"amount"`
	Player cmd.Optional[[]cmd.Target] `cmd:"player"`
}

func (c XpPoints) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("xp points %v %v", c.Amount, optTargets(c.Player))
}

type ConfigSet struct {
	Set   cmd.SubCommand `cmd:"set"`
	Key   string         `cmd:"key"`
	Value float64        `cmd:"value"`
}

func (c ConfigSet) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("config set [%v] %v", c.Key, f64(c.Value))
}

type ConfigGet struct {
	Get cmd.SubCommand `cmd:"get"`
	Key string         `cmd:"key"`
}

func (c ConfigGet) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("config get [%v]", c.Key)
}

type ConfigToggle struct {
	Toggle cmd.SubCommand     `cmd:"toggle"`
	Key    string             `cmd:"key"`
	On     cmd.Optional[bool] `cmd:"on"`
}

func (c ConfigToggle) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	v, ok := c.On.Load()
	o.Printf("config toggle [%v] %v %v", c.Key, v, ok)
}

type Give struct {
	Player []cmd.Target        `cmd:"player"`
	Item   Item                `cmd:"item"`
	Amount cmd.Optional[uint8] `cmd:"amount"`
	Data   cmd.Optional[int16] `cmd:"data"`
}

func (c Give) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("give %v %v %v %v", targets(c.Player), c.Item, c.Amount.LoadOr(1), c.Data.LoadOr(-1))
}

type Num struct {
	I8  int8    `cmd:"i8"`
	U16 uint16  `cmd:"u16"`
	I64 int64   `cmd:"i64"`
	F32 float32 `cmd:"f32"`
	U   uint    `cmd:"u"`
}

func (c Num) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("num %v %v %v %v %v", c.I8, c.U16, c.I64, f32(c.F32), c.U)
}

type Secret struct{}

func (Secret) Allow(src cmd.Source) bool { return isOp(src) }
func (Secret) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Print("secret")
}

type Mark struct {
	Pos  Coord                     `cmd:"pos"`
	Note cmd.Optional[cmd.Varargs] `cmd:"note"`
}

func (c Mark) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("mark [%v] [%v]", c.Pos, c.Note.LoadOr("none"))
}

type Flag struct {
	On bool `cmd:"on"`
}

func (c Flag) Run(_ cmd.Source, o *cmd.Output, _ *world.Tx) {
	o.Printf("flag %v", c.On)
}

var commands = []cmd.Command{
	cmd.New("gamemode", "Sets a player's game mode.", []string{"gm", "GMode"}, GameModeSet{}, GameModeInt{}),
	cmd.New("tp", "Teleports entities.", []string{"teleport"}, TpPos{}, TpTargets{}),
	cmd.New("say", "Broadcasts a message.", nil, Say{}),
	cmd.New("xp", "Adds experience.", nil, XpLevels{}, XpPoints{}),
	cmd.New("config", "Changes a setting.", nil, ConfigSet{}, ConfigGet{}, ConfigToggle{}),
	cmd.New("give", "Gives an item.", nil, Give{}),
	cmd.New("num", "Parses numbers.", nil, Num{}),
	cmd.New("SECRET", "Operators only.", []string{"hidden"}, Secret{}),
	cmd.New("mark", "Marks a coordinate.", nil, Mark{}),
	cmd.New("flag", "Parses a bool.", nil, Flag{}),
}

var op = &source{name: "Op", op: true}
var user = &source{name: "User"}

// cases are command lines executed as the named source.
var cases = []struct {
	src  *source
	line string
}{
	{op, "gamemode creative"},
	{op, "gamemode CREATIVE"},
	{op, "gamemode 1"},
	{op, "gamemode 1 Steve"},
	{op, "gamemode 1 @a"},
	{op, "gamemode hardcore"},
	{op, "gamemode"},
	{op, "gamemode creative Steve extra"},
	{op, "gm survival"},
	{op, "tp 1 2 3"},
	{op, "tp 1.5 -2e3 .25"},
	{op, "tp 1 2"},
	{op, "tp 1 x 3"},
	{op, "tp Steve Alex"},
	{op, "tp @s @p"},
	{op, "tp inf NaN -Infinity"},
	{op, "tp 1_0 2 3"},
	{op, "tp 0x1p4 2 3"},
	{op, "say hello world"},
	{op, "say"},
	{op, `say "quoted words" and more`},
	{op, `say a"b c`},
	{op, `say "a ""b"" c" d`},
	{op, `say "unterminated words`},
	{op, "say  two  spaces "},
	{op, "say line\nbreak"},
	{op, "say \"multi\nline\" x"},
	{op, "say crlf\r\n"},
	{op, "xp 10"},
	{op, "xp 10 @a"},
	{op, "xp -5"},
	{op, "xp 2147483648"},
	{op, "xp ten"},
	{op, "config set volume 0.5"},
	{op, "config SET volume 1e400"},
	{op, "config get volume"},
	{op, "config toggle music"},
	{op, "config toggle music false"},
	{op, "config toggle music maybe"},
	{op, "config remove volume"},
	{op, "config"},
	{op, "config get"},
	{op, "give Steve apple"},
	{op, "give @a apple"},
	{op, "give Steve DIAMOND 64"},
	{user, "give Steve diamond"},
	{op, "give Steve apple 256"},
	{op, "give Steve apple 3 -7"},
	{op, "give Steve apple 3 40000"},
	{op, "num -128 65535 -9223372036854775808 3.4028235e38 18446744073709551615"},
	{op, "num 128 0 0 0 0"},
	{op, "num -129 0 0 0 0"},
	{op, "num 0 65536 0 0 0"},
	{op, "num 0 -1 0 0 0"},
	{op, "num 0 +1 +5 +1.5 +3"},
	{op, "num 0 0 9223372036854775808 0 0"},
	{op, "num 0 0 0 3.5e38 0"},
	{op, "num 0 0 0 1e-50 0"},
	{op, "num 0 0 0 0 -1"},
	{op, "num 0 0 0 0 18446744073709551616"},
	{op, "num 007 0 0 0 0"},
	{op, "num 1 2 3 4"},
	{op, "secret"},
	{user, "secret"},
	{op, "mark ~5"},
	{op, "mark ~5 a note here"},
	{op, "mark 12 x"},
	{op, "mark abc"},
	{op, "flag true"},
	{op, "flag T"},
	{op, "flag 0"},
	{op, "flag False"},
	{op, "flag yes"},
	{op, "flag "},
	{op, "flag \n"},
}

func main() {
	out := flag.String("out", ".", "output directory")
	flag.Parse()
	for _, c := range commands {
		cmd.Register(c)
	}

	var b strings.Builder
	for _, c := range commands {
		fmt.Fprintf(&b, "usage\t%v\t%v\n", c.Name(), esc(c.Usage()))
		fmt.Fprintf(&b, "aliases\t%v\t%v\n", c.Name(), strings.Join(c.Aliases(), ","))
	}
	for _, c := range cases {
		name, args, _ := strings.Cut(c.line, " ")
		fmt.Fprintf(&b, "case\t%v\t%v\t%v\n", c.src.name, name, esc(args))
		command, ok := cmd.ByAlias(name)
		if !ok {
			panic("unknown command " + name)
		}
		c.src.out = nil
		command.Execute(args, c.src, nil)
		for _, m := range c.src.out.Messages() {
			writeMessage(&b, "ok", m)
		}
		for _, e := range c.src.out.Errors() {
			writeMessage(&b, "err", e)
		}
		b.WriteString("end\n")
	}

	// Go map iteration is random, so each packet is rebuilt until its commands
	// come out in name order, the order Ignis uses.
	soft := map[string]struct{}{"Item": {}}
	packets := []struct {
		src   *source
		names []string
		soft  bool
	}{
		{op, []string{"say"}, false},
		{op, []string{"gamemode"}, false},
		{op, []string{"tp"}, false},
		{op, []string{"xp"}, false},
		{op, []string{"config"}, false},
		{op, []string{"give"}, false},
		{op, []string{"give"}, true},
		{user, []string{"give"}, false},
		{op, []string{"num"}, false},
		{op, []string{"secret"}, false},
		{user, []string{"secret"}, false},
		{op, []string{"mark"}, false},
		{op, []string{"flag"}, false},
		{op, []string{"flag", "gamemode", "give"}, true},
		{op, []string{"config", "xp", "tp"}, false},
		{user, []string{"flag", "secret", "say"}, false},
	}
	for _, p := range packets {
		var softEnums map[string]struct{}
		if p.soft {
			softEnums = soft
		} else {
			softEnums = map[string]struct{}{}
		}
		sorted := slices.Clone(p.names)
		slices.Sort(sorted)
		for {
			// Small Go maps iterate in a rotation of their slot order, so the
			// insertion order is shuffled too.
			m := map[string]cmd.Command{}
			for _, i := range rand.Perm(len(p.names)) {
				c, _ := cmd.ByAlias(p.names[i])
				m[c.Name()] = c
				for _, a := range c.Aliases() {
					m[a] = c
				}
			}
			pk, _ := session.BuildAvailableCommands(m, p.src, softEnums)
			names := make([]string, 0, len(pk.Commands))
			for _, c := range pk.Commands {
				names = append(names, c.Name)
			}
			if !slices.IsSorted(names) {
				continue
			}
			buf := bytes.NewBuffer(nil)
			pk.Marshal(protocol.NewWriter(buf, 0))
			fmt.Fprintf(&b, "packet\t%v\t%v\t%v\t%v\n", p.src.name, strings.Join(p.names, ","), p.soft, hex.EncodeToString(buf.Bytes()))
			break
		}
	}
	must(os.WriteFile(filepath.Join(*out, "vectors.txt"), []byte(b.String()), 0o644))
}

// translation is what session.SendCommandOutput reads from a translated
// message.
type translation interface {
	Resolve(l language.Tag) string
	Params(l language.Tag) []string
}

func writeMessage(b *strings.Builder, kind string, m any) {
	fields := []string{kind, esc(fmt.Sprint(m))}
	if t, ok := m.(translation); ok {
		fields = append(fields, esc(t.Resolve(language.English)))
		for _, p := range t.Params(language.English) {
			fields = append(fields, esc(p))
		}
	}
	b.WriteString(strings.Join(fields, "\t") + "\n")
}

// esc escapes backslashes, tabs, newlines and carriage returns.
func esc(s string) string {
	return strings.NewReplacer(`\`, `\\`, "\t", `\t`, "\n", `\n`, "\r", `\r`).Replace(s)
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
