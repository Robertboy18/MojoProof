from layout.layout import Layout
from layout.coord import Coord, ComptimeInt, Idx
from layout.swizzle import Swizzle

comptime L = Layout[
    Coord[ComptimeInt[2], ComptimeInt[2]].element_types,
    Coord[ComptimeInt[3], ComptimeInt[1]].element_types,
]

def crd1_of(i: Int) -> Int:
    return Int(L().idx2crd(i)[1])

def sw(bits: Int, base: Int, shift: Int, x: Int) -> Int:
    return Swizzle(bits, base, shift)(x)

def main():
    # (2,2):(3,1) is injective: offsets 0,1,3,4
    comptime assert Int(L()(Coord(Idx[0], Idx[0]))) == 0
    comptime assert Int(L()(Coord(Idx[0], Idx[1]))) == 1
    comptime assert Int(L()(Coord(Idx[1], Idx[0]))) == 3
    comptime assert Int(L()(Coord(Idx[1], Idx[1]))) == 4
    # idx2crd is documented as the inverse of __call__; idx 3 = coordinate (1,0)
    comptime assert crd1_of(3) == 1   # not 0
    # Swizzle with |shift| < bits is not an involution: S(S(x)) != x
    comptime assert sw(2, 0, 1, sw(2, 0, 1, 6)) != 6
    # and with |shift| >= bits it is, on this sample
    comptime assert sw(2, 0, 3, sw(2, 0, 3, 29)) == 29
    print(1)
