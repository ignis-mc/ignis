package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"github.com/df-mc/dragonfly/server/block/cube"
	"github.com/df-mc/dragonfly/server/block/cube/trace"
	"github.com/go-gl/mathgl/mgl64"
)

// cubeLines collects "op<TAB>args<TAB>result" lines: floats are the hex of
// their IEEE bits, ints decimal, bools 0/1, all comma separated. The Mojo
// test parses the arguments, runs the same operation and compares.
type cubeLines struct{ b strings.Builder }

func f64(f float64) string { return fmt.Sprintf("%016x", math.Float64bits(f)) }

func vecS(v mgl64.Vec3) string { return f64(v[0]) + "," + f64(v[1]) + "," + f64(v[2]) }

func boxS(b cube.BBox) string { return vecS(b.Min()) + "," + vecS(b.Max()) }

func boolS(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

func (c *cubeLines) add(op string, args []string, result string) {
	c.b.WriteString(op + "\t" + strings.Join(args, ",") + "\t" + result + "\n")
}

func cubeVectors(out string) {
	var c cubeLines
	boxes := []cube.BBox{
		cube.Box(0, 0, 0, 1, 1, 1),
		cube.Box(0.25, 0, 0.1, 0.9, 1.5, 0.75),
		cube.Box(4, 5, 6, -1, -2, -3),
		cube.Box(0.3125, 0.125, 0.3125, 0.6875, 0.625, 0.6875),
		cube.Box(1, 0, 0, 2, 1, 1),
		cube.Box(0.5, 0.9999995, 0.5, 1.5, 2, 1.5),
	}
	vecs := []mgl64.Vec3{{0, 0, 0}, {0.3, -0.2, 1.7}, {-1.5, 2.25, -0.125}, {0.5, 0.5, 0.5}, {1, 0.5, 0.5}, {-0.3, 1.2, 0.6}}
	scalars := []float64{0.3, -0.2, 0, 1.5, -0.0625}
	for _, b := range boxes {
		c.add("box", []string{boxS(b)}, boxS(b))
		c.add("size", []string{boxS(b)}, f64(b.Width())+","+f64(b.Height())+","+f64(b.Length())+","+f64(b.Volume()))
		var corners []string
		for _, v := range b.Corners() {
			corners = append(corners, vecS(v))
		}
		c.add("corners", []string{boxS(b)}, strings.Join(corners, ","))
		for _, x := range scalars {
			c.add("grow", []string{boxS(b), f64(x)}, boxS(b.Grow(x)))
			c.add("mul", []string{boxS(b), f64(x)}, boxS(b.Mul(x)))
			for f := cube.Face(0); f < 7; f++ {
				c.add("extend_towards", []string{boxS(b), fmt.Sprint(int(f)), f64(x)}, boxS(b.ExtendTowards(f, x)))
				c.add("translate_towards", []string{boxS(b), fmt.Sprint(int(f)), f64(x)}, boxS(b.TranslateTowards(f, x)))
			}
			for a := cube.Axis(0); a < 3; a++ {
				c.add("stretch", []string{boxS(b), fmt.Sprint(int(a)), f64(x)}, boxS(b.Stretch(a, x)))
			}
		}
		for _, v := range vecs {
			c.add("grow_vec3", []string{boxS(b), vecS(v)}, boxS(b.GrowVec3(v)))
			c.add("extend", []string{boxS(b), vecS(v)}, boxS(b.Extend(v)))
			c.add("translate", []string{boxS(b), vecS(v)}, boxS(b.Translate(v)))
			c.add("within", []string{boxS(b), vecS(v)}, boolS(b.Vec3Within(v))+","+boolS(b.Vec3WithinYZ(v))+","+boolS(b.Vec3WithinXZ(v))+","+boolS(b.Vec3WithinXY(v)))
		}
		for _, o := range boxes {
			c.add("intersects", []string{boxS(b), boxS(o)}, boolS(b.IntersectsWith(o))+","+boolS(cube.AnyIntersections([]cube.BBox{o}, b)))
			for _, d := range []float64{2, -2, 0.5, -0.5, 0} {
				c.add("offset", []string{boxS(b), boxS(o), f64(d)}, f64(b.XOffset(o, d))+","+f64(b.YOffset(o, d))+","+f64(b.ZOffset(o, d)))
			}
		}
	}

	rots := []cube.Rotation{{0, 0}, {90, 45}, {-90, -45}, {180, 90}, {-180, -90}, {270, 100}, {-450, 200}, {44.9, 0}, {45, 0}, {135, 0}, {135.1, 0}, {-135, 0}, {-11.25, 0}, {-11.26, 0}, {348.75, 0}, {math.Copysign(0, -1), math.Copysign(0, -1)}, {720.5, -181}}
	for _, r := range rots {
		args := []string{f64(r[0]), f64(r[1])}
		o, n := r.Opposite(), r.Neg()
		c.add("rotation", args, f64(o[0])+","+f64(o[1])+","+f64(n[0])+","+f64(n[1])+","+fmt.Sprint(int(r.Direction()))+","+fmt.Sprint(int(r.Orientation()))+","+vecS(r.Vec3()))
		for _, r2 := range rots[:5] {
			s := r.Add(r2)
			c.add("rotation_add", []string{f64(r[0]), f64(r[1]), f64(r2[0]), f64(r2[1])}, f64(s[0])+","+f64(s[1]))
		}
	}
	for _, yaw := range []float64{0, 11.25, 11.24, 22.5, 359, 360, 370, -90, -11.25, -191.25, 1000} {
		o := cube.OrientationFromYaw(yaw)
		c.add("orientation", []string{f64(yaw)}, fmt.Sprint(int(o))+","+f64(o.Yaw())+","+fmt.Sprint(int(o.Opposite()))+","+fmt.Sprint(int(o.RotateLeft()))+","+fmt.Sprint(int(o.RotateRight())))
	}

	posS := func(p cube.Pos) string { return fmt.Sprintf("%d,%d,%d", p[0], p[1], p[2]) }
	ps := []cube.Pos{{0, 0, 0}, {1, -2, 3}, {-5, 64, 7}}
	for _, p := range ps {
		c.add("pos_string", []string{posS(p)}, p.String())
		for f := cube.Face(0); f < 7; f++ {
			c.add("pos_side", []string{posS(p), fmt.Sprint(int(f))}, posS(p.Side(f)))
		}
		for _, q := range []cube.Pos{p.Side(cube.FaceUp), p.Side(cube.FaceWest), p.Add(cube.Pos{1, 1, 0}), p} {
			f, ok := p.NeighbourFace(q)
			c.add("pos_face", []string{posS(p), posS(q)}, fmt.Sprint(int(f))+","+boolS(ok)+","+fmt.Sprint(int(p.Face(q))))
		}
		c.add("pos_within", []string{posS(p), "-1,-2,0", "1,70,7"}, boolS(p.Within(cube.Pos{-1, -2, 0}, cube.Pos{1, 70, 7})))
	}
	for _, v := range vecs {
		c.add("pos_from_vec3", []string{vecS(v)}, posS(cube.PosFromVec3(v)))
	}
	n := 0
	for range cube.Range3D(cube.Pos{2, 0, -1}, cube.Pos{-1, 1, 1}) {
		n++
	}
	c.add("range3d", []string{"2,0,-1", "-1,1,1"}, fmt.Sprint(n))

	rays := [][2]mgl64.Vec3{
		{{-1, 0.5, 0.5}, {2, 0.5, 0.5}},
		{{0.5, 3, 0.5}, {0.5, -1, 0.5}},
		{{-0.5, -0.5, -0.5}, {1.5, 1.7, 1.2}},
		{{2, 2, 2}, {3, 3, 3}},
		{{0.5, 0.5, -2}, {0.5, 0.5, 0.2}},
		{{0.1, 1.9, 0.1}, {0.9, -0.3, 0.8}},
		{{5.5, 64.2, -3.7}, {-2.25, 61, 4.5}},
		{{0.5, 0.5, 0.5}, {0.5, 0.5, 4.5}},
	}
	for _, ray := range rays {
		var visited []string
		trace.TraverseBlocks(ray[0], ray[1], func(p cube.Pos) bool {
			visited = append(visited, posS(p))
			return len(visited) < 64
		})
		c.add("traverse", []string{vecS(ray[0]), vecS(ray[1])}, strings.Join(visited, ";"))
		for _, b := range boxes {
			args := []string{boxS(b), vecS(ray[0]), vecS(ray[1])}
			r, ok := trace.BBoxIntercept(b, ray[0], ray[1])
			res := boolS(ok)
			if ok {
				res += "," + vecS(r.Position()) + "," + fmt.Sprint(int(r.Face())) + "," + boxS(r.BBox())
			}
			c.add("intercept", args, res)
			c.add("intersects_ray", args, boolS(trace.BBoxIntersects(b, ray[0], ray[1])))
		}
	}
	for _, x := range []float64{0, math.Copysign(0, -1), 0.1, -0.7, 1, math.Pi / 2, -math.Pi, 3.9, 10, -123.456, 1e6, 5e8} {
		c.add("gomath", []string{f64(x)}, f64(math.Sin(x))+","+f64(math.Cos(x)))
	}
	must(os.WriteFile(filepath.Join(out, "cube.txt"), []byte(c.b.String()), 0o644))
}
