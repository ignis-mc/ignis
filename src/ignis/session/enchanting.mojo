"""Enchanting tables, ported from Dragonfly `server/session/handler_enchanting.go`
(`sendEnchantmentOptions`, `determineAvailableEnchantments`,
`createEnchantments`, `searchBookshelves`) and `enchantment_texts.go`.

The offers come from a `Rand` seeded with the player's enchantment seed, the
same PCG Go uses, so a seed gives Go's offers. Go keeps the seed on the
player (and saves it); here the session keeps it for the connection.
"""

from minecraft.protocol.enchant import EnchantmentInstance, EnchantmentOption
from minecraft.protocol.packet.player_enchant_options import (
    PlayerEnchantOptions,
)

from ..block.air import Air
from ..block.bookshelf import Bookshelf
from ..block.cube.pos import Pos
from ..internal.enum import enum_name
from ..internal.rand import Rand
from ..item.book import Book
from ..item.enchanting import compatible_with_item
from ..item.enchantment import (
    CURSE_OF_VANISHING_ID,
    MENDING_ID,
    SOUL_SPEED_ID,
    SWIFT_SNEAK_ID,
)
from ..item.enchantment.register import VanillaEnchantments
from ..item.register import VanillaItems
from ..item.stack import Enchantment, Stack
from ..world.world import World, WorldTypes

comptime _ENCHANT_NAMES = (
    "aabstractt,abimek,aericio,aimjel,akmal"
    " fairuz,alvin0319,andreashgk,assassin ghost"
    " yt,atm85,azvyl,blackjack200,cetfu,cjmustard,cooldogedev,cqdetdev,da pig"
    " guy,daft0175,dasciam,deniel world,didntpot,driftlgtm,eminarican,emirhan"
    " olgn,endermanbugzjfc,erkam246,ethaniccc,fdutch,flonja,game"
    " parrot,gewinum,hashim the arab,hochbaum,hydzilla,im da real"
    " ani,inotflying,ipad54,its zodia x,ivan craft623,javier leon9966,just tal"
    " develops,k4ties,kaedendev,luciano"
    " mejia,manab-pr,memoxiiii,mmm545,mohamed587100,myma qc,natuyasai"
    " natuo,nonono697,nope not dark,provsalt,restart"
    " fu,riccskn,robertdudaa,royal"
    " mcpe,sallypemdas,sandertv,schphe,sculas,sergittos,smell-of-curry,sqmatheus,ssaini123456,studgi,superomarking,t14"
    " raptor,tadhunt,theaddonn,theboss9345,thicksunny,thunder33345,tripple"
    " awap,tristanmorgan,trix new,twisted asylum mc,unickorn,unknown"
    " ore,uramnoil,wqrro,x natsuri,x rookie fight,x superr,x"
    " toast-dev,x4caa,xd-pro,zaydanmd"
)
"""Go `enchantNames`, shown in the Standard Galactic Alphabet."""
comptime ENCHANT_NAME_COUNT = 87
"""The number of names in `_ENCHANT_NAMES`."""


def enchant_name(i: Int) -> String:
    """Returns one of Go's option names."""
    return String(enum_name(_ENCHANT_NAMES, i))


def treasure(id: Int) -> Bool:
    """Reports whether an enchantment is a treasure, never offered by tables
    (Go's `treasureEnchantment`: Mending, Soul Speed, Swift Sneak and Curse of
    Vanishing)."""
    return (
        id == MENDING_ID
        or id == SOUL_SPEED_ID
        or id == SWIFT_SNEAK_ID
        or id == CURSE_OF_VANISHING_ID
    )


def search_bookshelves[T: WorldTypes](mut tx: World[T], pos: Pos) -> Int:
    """Counts the bookshelves that power a table, up to 15 (Go
    `searchBookshelves`)."""
    var shelves = 0
    for x in range(-1, 2):
        for z in range(-1, 2):
            for y in range(0, 2):
                if x == 0 and z == 0:
                    continue
                if not tx.block_as[Air](pos.add(Pos(x, y, z))):
                    continue
                if tx.block_as[Bookshelf](pos.add(Pos(x * 2, y, z * 2))):
                    shelves += 1
                if x != 0 and z != 0:
                    if tx.block_as[Bookshelf](pos.add(Pos(x * 2, y, z))):
                        shelves += 1
                    if tx.block_as[Bookshelf](pos.add(Pos(x, y, z * 2))):
                        shelves += 1
                if shelves >= 15:
                    return 15
    return shelves


@fieldwise_init
struct EnchantOffers(Copyable):
    """The three offers of a table (Go `determineAvailableEnchantments`)."""

    var costs: List[Int]
    """The level each offer needs."""
    var enchants: List[List[Enchantment]]
    """The enchantments of each offer."""


def available_enchantments[
    T: WorldTypes
](mut tx: World[T], pos: Pos, s: Stack, seed: Int64) -> Optional[EnchantOffers]:
    """Returns the offers for an item on the table at `pos`; None for items
    that cannot be enchanted or already are (Go
    `determineAvailableEnchantments`)."""
    return offers_for(s, seed, search_bookshelves(tx, pos))


def offers_for(s: Stack, seed: Int64, shelves: Int) -> Optional[EnchantOffers]:
    """Returns the offers for an item with `shelves` bookshelves around the
    table (the body of Go `determineAvailableEnchantments`)."""
    if s.empty() or len(s.enchantments()) > 0:
        return None
    var it = s.item().value()
    if it.block:
        return None
    var value = VanillaItems.enchantment_value(it.kind, it.hash)
    if not value:
        return None
    var r = Rand(UInt64(seed), UInt64(seed))
    var base = r.int_n(8) + 1 + (shelves >> 1) + r.int_n(shelves + 1)
    var upper = max(base // 3, 1)
    var middle = base * 2 // 3 + 1
    var lower = max(base, shelves * 2)
    var enchants = List[List[Enchantment]]()
    enchants.append(create_enchantments(r, s, value.value(), upper))
    enchants.append(create_enchantments(r, s, value.value(), middle))
    enchants.append(create_enchantments(r, s, value.value(), lower))
    return EnchantOffers([upper, middle, lower], enchants^)


def _round(x: Float64) -> Int:
    # Go `math.Round`: halves away from zero.
    if x < 0:
        return -Int(-x + 0.5)
    return Int(x + 0.5)


def create_enchantments(
    mut r: Rand, s: Stack, value: Int, level: Int
) -> List[Enchantment]:
    """Picks the enchantments of one offer (Go `createEnchantments`)."""
    var bonus = (r.float64() + r.float64() - 1.0) * 0.15
    var cost = level + 1 + r.int_n(value // 4 + 1) + r.int_n(value // 4 + 1)
    cost = max(_round(Float64(cost) + Float64(cost) * bonus), 1)
    var book = Bool(s.item_as[Book]())
    var ids = VanillaEnchantments.ids()
    sort(ids)
    var available = List[Enchantment]()
    for id in ids:
        if treasure(id):
            continue
        if not book and not compatible_with_item(id, s):
            continue
        var lvl = VanillaEnchantments.max_level(id).or_else(0)
        while lvl > 0:
            var c = VanillaEnchantments.cost(id, lvl).value()
            if cost >= c[0] and cost <= c[1]:
                available.append(Enchantment(Int16(id), lvl))
                break
            lvl -= 1
    var selected = List[Enchantment]()
    if len(available) == 0:
        return selected^
    var e = _weighted(r, available)
    selected.append(e)
    _remove(available, e)
    while r.int_n(50) <= cost:
        var last = Int(selected[len(selected) - 1].id)
        var kept = List[Enchantment]()
        for a in available:
            if VanillaEnchantments.compatible(last, Int(a.id)):
                kept.append(a)
        available = kept^
        if len(available) == 0:
            break
        e = _weighted(r, available)
        selected.append(e)
        _remove(available, e)
        cost //= 2
    return selected^


def _weight(e: Enchantment) -> Int:
    if case .Some(r) = VanillaEnchantments.rarity(Int(e.id)):
        return r.weight()
    return 1


def _weighted(mut r: Rand, enchants: List[Enchantment]) -> Enchantment:
    # Go `weightedRandomEnchantment`.
    var total = 0
    for e in enchants:
        total += _weight(e)
    var n = r.int_n(total)
    for e in enchants:
        n -= _weight(e)
        if n < 0:
            return e
    return enchants[len(enchants) - 1]


def _remove(mut l: List[Enchantment], e: Enchantment):
    for i in range(len(l)):
        if l[i] == e:
            _ = l.pop(i)
            return


def enchant_options_packet(
    offers: EnchantOffers, mut names: Rand
) -> PlayerEnchantOptions:
    """Returns the offers as Go's `PlayerEnchantOptions` (Go
    `sendEnchantmentOptions`), with a random name each."""
    var pk = PlayerEnchantOptions()
    for i in range(3):
        var o = EnchantmentOption()
        o.name = enchant_name(names.int_n(ENCHANT_NAME_COUNT))
        o.cost = UInt8(offers.costs[i])
        o.recipe_network_id = UInt32(i)
        o.enchantments.slot = Int32(i)
        for e in offers.enchants[i]:
            var inst = EnchantmentInstance()
            inst.type = UInt8(e.id)
            inst.level = UInt8(e.level)
            o.enchantments.enchantments[1].append(inst^)
        pk.options.append(o^)
    return pk^
