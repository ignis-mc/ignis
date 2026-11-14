"""Go's pure-Go `math.Sin` and `math.Cos` (Go 1.24 `math/sin.go`, the
Cephes algorithm), which differ from the C library in the last bits.

Dragonfly runs these on amd64 (no assembly versions there), so porting them
keeps values such as `cube.Rotation.vec3` bit-identical. Arguments at or
beyond Go's `reduceThreshold` (2^29), which Go reduces with Payne-Hanek, use
the standard library instead; Dragonfly never passes such angles.
"""

from std.math import cos as std_cos, isinf, isnan, nan, pi, sin as std_sin

comptime _REDUCE_THRESHOLD: Float64 = 1 << 29
comptime _PI4A: Float64 = 7.85398125648498535156e-1
comptime _PI4B: Float64 = 3.77489470793079817668e-8
comptime _PI4C: Float64 = 2.69515142907905952645e-15


def _sin_poly(z: Float64, zz: Float64) -> Float64:
    return z + z * zz * (
        (
            (
                (
                    (
                        (1.58962301576546568060e-10 * zz)
                        - 2.50507477628578072866e-8
                    )
                    * zz
                    + 2.75573136213857245213e-6
                )
                * zz
                - 1.98412698295895385996e-4
            )
            * zz
            + 8.33333333332211858878e-3
        )
        * zz
        - 1.66666666666666307295e-1
    )


def _cos_poly(zz: Float64) -> Float64:
    return (
        1.0
        - 0.5 * zz
        + zz
        * zz
        * (
            (
                (
                    (
                        (
                            (-1.13585365213876817300e-11 * zz)
                            + 2.08757008419747316778e-9
                        )
                        * zz
                        - 2.75573141792967388112e-7
                    )
                    * zz
                    + 2.48015872888517045348e-5
                )
                * zz
                - 1.38888888888730564116e-3
            )
            * zz
            + 4.16666666666665929218e-2
        )
    )


def _reduce(x: Float64) -> Tuple[UInt64, Float64]:
    var j = UInt64(x * (4 / pi))
    var y = Float64(j)
    if j & 1 == 1:
        j += 1
        y += 1
    j &= 7
    return (j, ((x - y * _PI4A) - y * _PI4B) - y * _PI4C)


def go_sin(x: Float64) -> Float64:
    """Returns the sine of `x` as Go's `math.Sin` computes it."""
    if x == 0 or isnan(x):
        return x
    if isinf(x):
        return nan[DType.float64]()
    var sign = False
    var a = x
    if a < 0:
        a = -a
        sign = True
    if a >= _REDUCE_THRESHOLD:
        return std_sin(x)
    var r = _reduce(a)
    var j = r[0]
    var z = r[1]
    if j > 3:
        sign = not sign
        j -= 4
    var zz = z * z
    var y: Float64
    if j == 1 or j == 2:
        y = _cos_poly(zz)
    else:
        y = _sin_poly(z, zz)
    return -y if sign else y


def go_cos(x: Float64) -> Float64:
    """Returns the cosine of `x` as Go's `math.Cos` computes it."""
    if isnan(x) or isinf(x):
        return nan[DType.float64]()
    var sign = False
    var a = abs(x)
    if a >= _REDUCE_THRESHOLD:
        return std_cos(x)
    var r = _reduce(a)
    var j = r[0]
    var z = r[1]
    if j > 3:
        j -= 4
        sign = not sign
    if j > 1:
        sign = not sign
    var zz = z * z
    var y: Float64
    if j == 1 or j == 2:
        y = _sin_poly(z, zz)
    else:
        y = _cos_poly(zz)
    return -y if sign else y
