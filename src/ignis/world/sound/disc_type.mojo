"""`DiscType`, ported from Dragonfly `server/world/sound/disc_type.go`."""

from ...internal.enum import enum_name


struct DiscType(Equatable, ImplicitlyCopyable, Writable):
    """A type of music disc (Go `sound.DiscType`)."""

    var _v: UInt8

    comptime DISC_13 = DiscType(0)
    """Go `Disc13()`."""
    comptime CAT = DiscType(1)
    """Go `DiscCat()`."""
    comptime BLOCKS = DiscType(2)
    """Go `DiscBlocks()`."""
    comptime CHIRP = DiscType(3)
    """Go `DiscChirp()`."""
    comptime FAR = DiscType(4)
    """Go `DiscFar()`."""
    comptime MALL = DiscType(5)
    """Go `DiscMall()`."""
    comptime MELLOHI = DiscType(6)
    """Go `DiscMellohi()`."""
    comptime STAL = DiscType(7)
    """Go `DiscStal()`."""
    comptime STRAD = DiscType(8)
    """Go `DiscStrad()`."""
    comptime WARD = DiscType(9)
    """Go `DiscWard()`."""
    comptime DISC_11 = DiscType(10)
    """Go `Disc11()`."""
    comptime WAIT = DiscType(11)
    """Go `DiscWait()`."""
    comptime OTHERSIDE = DiscType(12)
    """Go `DiscOtherside()`."""
    comptime PIGSTEP = DiscType(13)
    """Go `DiscPigstep()`."""
    comptime DISC_5 = DiscType(14)
    """Go `Disc5()`."""
    comptime RELIC = DiscType(15)
    """Go `DiscRelic()`."""
    comptime CREATOR = DiscType(16)
    """Go `DiscCreator()`."""
    comptime CREATOR_MUSIC_BOX = DiscType(17)
    """Go `DiscCreatorMusicBox()`."""
    comptime PRECIPICE = DiscType(18)
    """Go `DiscPrecipice()`."""
    comptime TEARS = DiscType(19)
    """Go `DiscTears()`."""
    comptime LAVA_CHICKEN = DiscType(20)
    """Go `DiscLavaChicken()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `DiscType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "13,cat,blocks,chirp,far,mall,mellohi,stal,strad,ward,11,"
                    "wait,otherside,pigstep,5,relic,creator,"
                    "creator_music_box,precipice,tears,lava_chicken"
                ),
                Int(self._v),
            )
        )

    def display_name(self) -> String:
        """Returns the name shown for the disc (Go `DisplayName`, which title
        cases the names of discs after `otherside`)."""
        if self._v == 17:
            return "Creator (Music Box)"
        if self._v == 20:
            return "Lava Chicken"
        var s = String(self)
        if self._v > 12:
            var b = s.as_bytes()
            return String(chr(Int(b[0]) - 32)) + String(s[byte=1:])
        return s^

    def author(self) -> StaticString:
        """Returns the composer of the disc (Go `Author`)."""
        if self._v <= 11:
            return "C418"
        if self._v == 12 or self._v == 13 or self._v == 16 or self._v == 17:
            return "Lena Raine"
        if self._v == 14:
            return "Samuel Åberg"
        if self._v == 15 or self._v == 18:
            return "Aaron Cherof"
        if self._v == 19:
            return "Amos Roddy"
        return "Hyper Potions"


def music_discs() -> List[DiscType]:
    """Returns every music disc (Go `MusicDiscs`)."""
    var out = List[DiscType](capacity=21)
    for i in range(21):
        out.append(DiscType(i))
    return out^
