package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/df-mc/dragonfly/server/player/bossbar"
	"github.com/df-mc/dragonfly/server/player/chat"
	"github.com/df-mc/dragonfly/server/player/dialogue"
	"github.com/df-mc/dragonfly/server/player/form"
	"github.com/df-mc/dragonfly/server/player/scoreboard"
	"github.com/df-mc/dragonfly/server/player/skin"
	"github.com/df-mc/dragonfly/server/player/title"
	"github.com/df-mc/dragonfly/server/world"
	"github.com/go-gl/mathgl/mgl64"
	"github.com/sandertv/gophertunnel/minecraft/protocol"
	"github.com/sandertv/gophertunnel/minecraft/protocol/packet"
	"github.com/sandertv/gophertunnel/minecraft/text"
	"golang.org/x/text/language"
)

// lines collects "key hex(value)" lines in order; values are hex so that any
// bytes survive.
type lines struct{ b strings.Builder }

func (l *lines) put(key string, v []byte) {
	l.b.WriteString(key + " " + hex.EncodeToString(v) + "\n")
}
func (l *lines) str(key, v string) { l.put(key, []byte(v)) }

// --- Colourf, Clean, ANSI ------------------------------------------------

type colourCase struct {
	format string
	args   []any
}

var colourCases = []colourCase{
	{"", nil},
	{"plain text", nil},
	{"<red>Hello</red> <bold>World</bold>!", nil},
	{"<red>Hello <bold>World</bold>!</red>", nil},
	{"<red><green>a</red>b</green>c", nil},
	{"<RED>upper</RED><Dark-Blue>x</dark-BLUE>", nil},
	{"<unknown>tag</unknown>", nil},
	{"<red a=1 b='2' c=\"3\" d>attrs</red>", nil},
	{"<red/>self<br/>closing<p a=/>x", nil},
	{"a<!-- comment -->b<!--->c<!-->d<!---->e", nil},
	{"a<!DOCTYPE html>b<!doctype>c<!x>d<?xml v?>e", nil},
	{"a</>b</ x>c</1>d", nil},
	{"a < b <1> <-> <", nil},
	{"unterminated <red", nil},
	{"unterminated </red", nil},
	{"end <!-- open", nil},
	{"&amp; &lt; &gt; &quot; &apos; &nbsp;|", nil},
	{"&copy &copy; &copyx &notit; &notin; &amp &ampx &ZZZ;", nil},
	{"&#65;&#x41;&#X42;&#0;&#128;&#159;&#xD800;&#1114112;&#99999999999;&#;&#x;&#65", nil},
	{"&NotEqualTilde; &acE; &", nil},
	{"line\r\nbreak\rhere\n", nil},
	{"nul\x00byte<red>\x00</red>", nil},
	{"<script>a<red>b</red>&amp;</script>c", nil},
	{"<title>x &amp; <red>y</red></title>z", nil},
	{"<textarea>a&lt;b</TEXTAREA>c", nil},
	{"<style>s</stylex></style>t", nil},
	{"<plaintext><red>all</red>", nil},
	{"<xmp>x</xmp ><red>y</red>", nil},
	{"§aalready§r <b>coded</b> é ✓ 日本", nil},
	{"<yellow>%v</yellow>", []any{"%multiplayer.player.joined"}},
	{"%v joined %s with %d%%", []any{"Steve", "us", 5}},
	{"missing %v %v", []any{"one"}},
	{"extra %v", []any{"one", "two", "three"}},
	{"<red>%v</red>", []any{"<bold>injected</bold> &amp;"}},
	{"trailing %", nil},
	{"<i>i</i><b>b</b><obfuscated>o</obfuscated><resin>r</resin><orange>o</orange>", nil},
}

var cleanCases = []string{"", "§aGreen§r text", "§wnot a code §", "§§ab", "§zz§v§0", "plain"}

func writeColour(l *lines) {
	for i, c := range colourCases {
		l.str(fmt.Sprintf("colourf.%d.format", i), c.format)
		var args []string
		for _, a := range c.args {
			args = append(args, fmt.Sprint(a))
		}
		l.str(fmt.Sprintf("colourf.%d.args", i), strings.Join(args, "\x1f"))
		l.str(fmt.Sprintf("colourf.%d.out", i), text.Colourf(c.format, c.args...))
	}
	for i, c := range cleanCases {
		l.str(fmt.Sprintf("clean.%d.in", i), c)
		l.str(fmt.Sprintf("clean.%d.clean", i), text.Clean(c))
		l.str(fmt.Sprintf("clean.%d.ansi", i), text.ANSI(c))
	}
}

// --- encoding/json -------------------------------------------------------

var floats = []float64{0, 1, -1, 0.5, 2.5, 10, 100, 1e20, 1e21, 1.5e21, 123456789, 1e-6, 1e-7, 1.25e-7, 0.1, 1.0 / 3, -2.25, 5e-324, 1.7976931348623157e308, 12345678901234567890, 0.000123, 3e100}

var quoteCases = []string{"", "plain", `quote " back \ slash`, "<html> & 'x'", "\n\r\t\b\f\x00\x01\x1f\x7f", "é ✓ 日本 🎉", "  ", "bad \xff\xfe utf8 \xc3", "\xed\xa0\x80 surrogate", "§aformat"}

func writeJSON(l *lines) {
	for i, f := range floats {
		b, _ := json.Marshal(f)
		l.str(fmt.Sprintf("float.%d.in", i), strconv.FormatUint(mathFloat64bits(f), 16))
		l.put(fmt.Sprintf("float.%d.out", i), b)
	}
	for i, s := range quoteCases {
		b, _ := json.Marshal(s)
		l.str(fmt.Sprintf("quote.%d.in", i), s)
		l.put(fmt.Sprintf("quote.%d.out", i), b)
	}
}

// --- Forms ---------------------------------------------------------------

type recorder struct{ log []string }

func (r *recorder) SendForm(form.Form) {}
func (r *recorder) CloseForm()         {}

var rec = &recorder{}

func jsonFloat(f float64) string { b, _ := json.Marshal(f); return string(b) }

type survey struct {
	Header form.Header
	Name   form.Input
	Agree  form.Toggle
	Volume form.Slider
	Colour form.Dropdown
	Size   form.StepSlider
	note   string
}

func (s survey) Submit(form.Submitter, *world.Tx) {
	rec.log = append(rec.log, fmt.Sprintf("%v|%v|%v|%v|%v|%v", s.Name.Value(), s.Agree.Value(), jsonFloat(s.Volume.Value()), s.Colour.Value(), s.Size.Value(), s.note))
}
func (s survey) Close(form.Submitter, *world.Tx) { rec.log = append(rec.log, "closed") }

func newSurvey() survey {
	return survey{
		Header: form.NewHeader("Questions"),
		Name:   form.NewInput("Name", "Steve", "your name"),
		Agree:  form.NewToggle("Agree", true),
		Volume: form.NewSlider("Volume", 0, 10, 0.5, 2.5),
		Colour: form.NewDropdown("Colour", []string{"red", "green"}, 1),
		Size:   form.NewStepSlider("Size", []string{"S", "M", "L"}, 0),
		note:   "n",
	}
}

type tooltips struct {
	Div    form.Divider
	Label  form.Label
	Name   form.Input
	Agree  form.Toggle
	Volume form.Slider
	Colour form.Dropdown
	Size   form.StepSlider
}

func (tooltips) Submit(form.Submitter, *world.Tx) {}

func newTooltips() tooltips {
	return tooltips{
		Label:  form.NewLabel("<b>&\"  §aé"),
		Name:   form.NewInput("", "", "").WithTooltip("tip1"),
		Agree:  form.NewToggle("t", false).WithTooltip("tip2"),
		Volume: form.NewSlider("s", -1.5, 1e21, 1e-7, 0.1).WithTooltip("tip3"),
		Colour: form.NewDropdown("d", []string{}, 0).WithTooltip("tip4"),
		Size:   form.NewStepSlider("ss", []string{"<a>"}, 0).WithTooltip("tip5"),
	}
}

type menu struct {
	Profile  form.Button
	Settings form.Button
}

func (m menu) Submit(_ form.Submitter, pressed form.Button, _ *world.Tx) {
	rec.log = append(rec.log, "pressed "+pressed.Text)
}
func (m menu) Close(form.Submitter, *world.Tx) { rec.log = append(rec.log, "closed") }

func newMenu() form.Menu {
	return form.NewMenu(menu{
		Profile:  form.NewButton("Profile", "textures/ui/icon"),
		Settings: form.NewButton("Settings", "https://example.com/s.png"),
	}, "Menu").WithBody("Pick one").AddDivider(form.Divider{}).AddHeader(form.NewHeader("More")).AddLabel(form.NewLabel("Text")).AddButton(form.NewButton("Extra", "http:x"))
}

type modal struct {
	Yes form.Button
	No  form.Button
}

func (m modal) Submit(_ form.Submitter, pressed form.Button, _ *world.Tx) {
	rec.log = append(rec.log, "pressed "+pressed.Text)
}

func newModal() form.Modal {
	return form.NewModal(modal{Yes: form.YesButton(), No: form.NoButton()}, "Modal").WithBody("Sure?\n")
}

var surveyResponses = []string{
	`[null,"Alex",false,7.5,0,2]`,
	`[null,"Alex",false,11,0,2]`,
	`[null,"Alex",false]`,
	`[1,"Alex",true,0,1,1]`,
	`[null,5,false,1,0,0]`,
	`[null,"A",1,1,0,0]`,
	`[null,"A",true,"1",0,0]`,
	`[null,"A",true,1,1.0,0]`,
	`[null,"A",true,1e0,1,0]`,
	`[null,"A",true,1,-1,0]`,
	`[null,"A",true,1,0,3]`,
	`null`,
	`{}`,
	`"x"`,
	`[null,"A",true,1,0,0,"extra"]`,
	"<nil>",
	`[null,"é\ud800x",true,1,0,0]`,
	`[null,"A",true,-0,0,-0]`,
	`[null,"A",true,01,0,0]`,
	`[null,"A",true,1.5e400,0,0]`,
	`[null,"A",true,1,9223372036854775808,0]`,
	`[null,"A",true,1,0,1e0]`,
	"[null,\"bad \xff\",true,1,0,0]",
	`[null, "spaced" , true , 2.25 , 1 , 2 ]`,
	`[null,"A",true,0.5,0,0`,
}

var menuResponses = []string{"0", "1", "2", "3", "-1", "1.0", "null", " 2 ", `"1"`, "1e0", "<nil>", "18446744073709551616", "true"}
var modalResponses = []string{"true", "false", "null", "1", `"true"`, "<nil>", " true ", "tru"}

func submit(l *lines, key string, f form.Form, resp string) {
	rec.log = nil
	var data []byte
	if resp != "<nil>" {
		data = []byte(resp)
	}
	err := f.SubmitJSON(data, rec, nil)
	out := strings.Join(rec.log, ";")
	if err != nil {
		out = "error"
	}
	l.str(key+".in", resp)
	l.str(key+".out", out)
}

func writeForms(l *lines) {
	sv := form.New(newSurvey(), "Survey\n")
	b, _ := json.Marshal(sv)
	l.put("form.survey.json", b)
	tt := form.New(newTooltips(), "Tips", "and", 5)
	b, _ = json.Marshal(tt)
	l.put("form.tooltips.json", b)
	for i, r := range surveyResponses {
		submit(l, fmt.Sprintf("form.survey.submit.%d", i), sv, r)
	}
	m := newMenu()
	b, _ = json.Marshal(m)
	l.put("form.menu.json", b)
	for i, r := range menuResponses {
		submit(l, fmt.Sprintf("form.menu.submit.%d", i), m, r)
	}
	md := newModal()
	b, _ = json.Marshal(md)
	l.put("form.modal.json", b)
	for i, r := range modalResponses {
		submit(l, fmt.Sprintf("form.modal.submit.%d", i), md, r)
	}
}

// --- Dialogue ------------------------------------------------------------

type talk struct {
	Hello dialogue.Button
	Bye   dialogue.Button
}

func (talk) Submit(dialogue.Submitter, dialogue.Button, *world.Tx) {}

func writeDialogue(l *lines) {
	d := dialogue.New(talk{Hello: dialogue.Button{Text: "Hello"}, Bye: dialogue.Button{Text: "<Bye>"}}, "NPC").WithBody("Hi\n").WithButtons(dialogue.Button{Text: "Extra"})
	b, _ := json.Marshal(d)
	l.put("dialogue.json", b)
	l.str("dialogue.title", d.Title())
	l.str("dialogue.body", d.Body())
	disp := dialogue.DisplaySettings{EntityScale: mgl64.Vec3{1.5, 2, 0.5}, EntityOffset: mgl64.Vec3{0.1, 1.62, -3}, EntityRotation: mgl64.Vec3{10, 45, 0}}
	b, _ = json.Marshal(map[string]any{"portrait_offsets": disp})
	l.put("dialogue.display", b)
	b, _ = json.Marshal(map[string]any{"portrait_offsets": dialogue.DisplaySettings{}})
	l.put("dialogue.display_zero", b)
}

// --- Scoreboard, boss bar, title, chat -------------------------------------

func writeScoreboard(l *lines) {
	sb := scoreboard.New("Test Board")
	_, _ = sb.WriteString("a\nbbbbbbbbbbbbbbbb")
	sb.Set(4, "x\n\n")
	l.str("scoreboard.name", sb.Name())
	l.str("scoreboard.lines", strings.Join(sb.Lines(), "\x1f"))
	sb.SetDescending()
	l.str("scoreboard.desc", strings.Join(sb.Lines(), "\x1f"))
	sb.RemovePadding()
	l.str("scoreboard.nopad", strings.Join(sb.Lines(), "\x1f"))
	sb.Remove(0)
	l.str("scoreboard.removed", strings.Join(sb.Lines(), "\x1f"))
	full := scoreboard.New("F")
	_, err := full.WriteString(strings.Repeat("l\n", 14))
	l.str("scoreboard.full_err", fmt.Sprint(err != nil))
	l.str("scoreboard.full_lines", fmt.Sprint(len(full.Lines())))
}

func writeChat(l *lines) {
	tr := chat.MessageJoin.F("Steve")
	l.str("chat.join.string", tr.String())
	l.str("chat.join.resolve", tr.Resolve(language.English))
	l.str("chat.join.params", strings.Join(tr.Params(language.English), "\x1f"))
	sl := chat.MessageSleeping.F("Alex", 3)
	l.str("chat.sleeping.string", sl.String())
	l.str("chat.sleeping.resolve", sl.Resolve(language.English))
	l.str("chat.sleeping.params", strings.Join(sl.Params(language.English), "\x1f"))
	l.str("chat.bed.string", chat.MessageBedTooFar.F().String())
	l.str("chat.bed.resolve", chat.MessageBedTooFar.Resolve(language.English))
}

// --- Packets -------------------------------------------------------------

func encode(pk packet.Packet) []byte {
	buf := bytes.NewBuffer(nil)
	(&packet.Header{PacketID: pk.ID()}).Write(buf)
	pk.Marshal(protocol.NewWriter(buf, 0))
	return buf.Bytes()
}

// session mirrors the parts of Dragonfly's session/text.go and player.go
// that write UI packets, recording the encoded packets.
type session struct {
	out          [][]byte
	currentName  string
	currentLines []string
}

func (s *session) write(pk packet.Packet) { s.out = append(s.out, encode(pk)) }

func (s *session) take() []byte {
	var b []byte
	for _, p := range s.out {
		b = append(b, byte(len(p)>>8), byte(len(p)))
		b = append(b, p...)
	}
	s.out = nil
	return b
}

var colours = [15]string{"1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

func (s *session) sendScoreboard(sb *scoreboard.Scoreboard) {
	if s.currentName != sb.Name() {
		s.removeScoreboard()
		pk := &packet.SetDisplayObjective{DisplaySlot: "sidebar", ObjectiveName: sb.Name(), DisplayName: sb.Name(), CriteriaName: "dummy"}
		if sb.Descending() {
			pk.SortOrder = packet.ScoreboardSortOrderDescending
		} else {
			pk.SortOrder = packet.ScoreboardSortOrderAscending
		}
		s.write(pk)
		s.currentName, s.currentLines = sb.Name(), append([]string(nil), sb.Lines()...)
	} else {
		pk := &packet.SetScore{}
		for i := range s.currentLines {
			pk.Entries = append(pk.Entries, protocol.ScoreboardEntry{IdentityType: protocol.ScoreboardIdentityRemove, EntryID: int64(i), ObjectiveName: s.currentName, Score: int32(i)})
		}
		if len(pk.Entries) > 0 {
			s.write(pk)
		}
	}
	pk := &packet.SetScore{}
	for k, line := range sb.Lines() {
		if len(line) == 0 {
			line = "§" + colours[k]
		}
		pk.Entries = append(pk.Entries, protocol.ScoreboardEntry{EntryID: int64(k), ObjectiveName: sb.Name(), Score: int32(k), IdentityType: protocol.ScoreboardIdentityFakePlayer, DisplayName: line})
	}
	if len(pk.Entries) > 0 {
		s.write(pk)
	}
}

func (s *session) removeScoreboard() {
	s.write(&packet.RemoveObjective{ObjectiveName: s.currentName})
	s.currentName, s.currentLines = "", nil
}

func writePackets(l *lines) {
	s := &session{}
	s.write(&packet.Text{TextType: packet.TextTypeRaw, Message: "hi §aall"})
	l.put("packet.message", s.take())
	tr := chat.MessageJoin.F("Steve")
	s.write(&packet.Text{TextType: packet.TextTypeTranslation, NeedsTranslation: true, Message: tr.Resolve(language.English), Parameters: tr.Params(language.English)})
	l.put("packet.translation", s.take())
	s.write(&packet.Text{TextType: packet.TextTypeTip, Message: "tip"})
	s.write(&packet.Text{TextType: packet.TextTypePopup, Message: "popup"})
	s.write(&packet.Text{TextType: packet.TextTypeJukeboxPopup, Message: "jukebox"})
	s.write(&packet.Text{TextType: packet.TextTypeAnnouncement, Message: "announce"})
	l.put("packet.tips", s.take())
	s.write(&packet.ToastRequest{Title: "Title", Message: "Message"})
	l.put("packet.toast", s.take())

	sb := scoreboard.New("Test")
	_, _ = sb.WriteString("a\nb\n")
	s.sendScoreboard(sb)
	l.put("packet.scoreboard.1", s.take())
	sb2 := scoreboard.New("Test")
	sb2.Set(1, "c")
	sb2.SetDescending()
	s.sendScoreboard(sb2)
	l.put("packet.scoreboard.2", s.take())
	sb3 := scoreboard.New("Other")
	_, _ = sb3.WriteString("x")
	sb3.RemovePadding()
	s.sendScoreboard(sb3)
	l.put("packet.scoreboard.3", s.take())
	s.removeScoreboard()
	l.put("packet.scoreboard.remove", s.take())

	bar := bossbar.New("Boss", "fight").WithHealthPercentage(0.25).WithColour(bossbar.Red())
	s.write(&packet.BossEvent{BossEntityUniqueID: 1, EventType: packet.BossEventHide})
	s.write(&packet.BossEvent{BossEntityUniqueID: 1, EventType: packet.BossEventShow, BossBarTitle: bar.Text(), HealthPercentage: float32(bar.HealthPercentage()), Colour: bar.Colour().Uint8()})
	l.put("packet.bossbar", s.take())
	l.str("bossbar.default", fmt.Sprintf("%q %v %v", bossbar.New("B\n").Text(), bossbar.New().HealthPercentage(), bossbar.New().Colour().Uint8()))

	sendTitle := func(t title.Title) {
		tick := time.Second / 20
		s.write(&packet.SetTitle{ActionType: packet.TitleActionSetDurations, FadeInDuration: int32(t.FadeInDuration() / tick), RemainDuration: int32(t.Duration() / tick), FadeOutDuration: int32(t.FadeOutDuration() / tick)})
		if t.Text() != "" || t.Subtitle() != "" {
			s.write(&packet.SetTitle{ActionType: packet.TitleActionSetTitle, Text: t.Text()})
			if t.Subtitle() != "" {
				s.write(&packet.SetTitle{ActionType: packet.TitleActionSetSubtitle, Text: t.Subtitle()})
			}
		}
		if t.ActionText() != "" {
			s.write(&packet.SetTitle{ActionType: packet.TitleActionSetActionBar, Text: t.ActionText()})
		}
	}
	sendTitle(title.New("Hello").WithSubtitle("Sub").WithActionText("Act").WithDuration(3 * time.Second).WithFadeInDuration(time.Second).WithFadeOutDuration(130 * time.Millisecond))
	l.put("packet.title.full", s.take())
	sendTitle(title.New().WithActionText("only action"))
	l.put("packet.title.action", s.take())
	sendTitle(title.New().WithSubtitle("sub only"))
	l.put("packet.title.sub", s.take())

	sv, _ := json.Marshal(form.New(newSurvey(), "Survey"))
	s.write(&packet.ModalFormRequest{FormID: 1, FormData: sv})
	s.write(&packet.ClientBoundCloseForm{})
	l.put("packet.form", s.take())

	d := dialogue.New(talk{Hello: dialogue.Button{Text: "Hello"}, Bye: dialogue.Button{Text: "Bye"}}, "NPC").WithBody("Hi")
	actions, _ := json.Marshal(d)
	s.write(&packet.NPCDialogue{EntityUniqueID: 5, ActionType: packet.NPCDialogueActionOpen, Dialogue: d.Body(), SceneName: "default", NPCName: d.Title(), ActionJSON: string(actions)})
	s.write(&packet.NPCDialogue{EntityUniqueID: 5, ActionType: packet.NPCDialogueActionClose})
	l.put("packet.dialogue", s.take())
}

// --- Skin ----------------------------------------------------------------

func writeSkin(l *lines) {
	cfg := skin.ModelConfig{Default: "geometry.humanoid.custom"}
	l.put("skin.model_config", cfg.Encode())
	cfg.AnimatedFace = "geometry.animated_face"
	l.put("skin.model_config_face", cfg.Encode())
	for i, in := range []string{`{"geometry":{"default":"geometry.humanoid.customSlim"}}`, `{"geometry":{"default":"a","animated_face":"b","x":1},"y":2}`, `{}`, `{"geometry":5}`, `not json`} {
		got, err := skin.DecodeModelConfig([]byte(in))
		l.str(fmt.Sprintf("skin.decode.%d.in", i), in)
		out := got.Default + "|" + got.AnimatedFace
		if err != nil {
			out = "error"
		}
		l.str(fmt.Sprintf("skin.decode.%d.out", i), out)
	}
}

func writeVectors(out string) {
	var l lines
	writeColour(&l)
	writeJSON(&l)
	writeForms(&l)
	writeDialogue(&l)
	writeScoreboard(&l)
	writeChat(&l)
	writePackets(&l)
	writeSkin(&l)
	must(os.MkdirAll(out, 0o755))
	must(os.WriteFile(filepath.Join(out, "vectors.txt"), []byte(l.b.String()), 0o644))
}

func mathFloat64bits(f float64) uint64 { return math.Float64bits(f) }
