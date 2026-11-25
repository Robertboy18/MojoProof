# The layout conformance test on runtime leaves: a CPU program, compiled and run. Every extent and
# stride below is a runtime value (a `Scalar` leaf) except where `Idx` makes it static; each is
# offset by the first command-line argument, which the run passes as 0, so the compiler cannot
# fold them. The program prints one line per value: the case, the scalar coordinate or the
# word `size` or `cosize`, and the value.
from std.sys import argv
from layout import Idx, Coord
from layout.layout import Layout, upcast


def main() raises:
    var args = argv()
    var k = atol(args[1])
    var a2 = Int64(2 + k)
    var a3 = Int64(3 + k)
    var a4 = Int64(4 + k)
    var a8 = Int64(8 + k)
    var a0 = Int64(0 + k)
    var a1 = Int64(1 + k)
    var a6 = Int64(6 + k)

    # c0: (3, 4):(1, 3)
    var l0 = Layout(Coord(a3, a4), Coord(a1, a3))
    for v in range(12):
        print("c0", v, l0(Int64(v)))
    print("c0 size", l0.size())
    print("c0 cosize", l0.cosize())

    # c1: (2, 3, 2):(6, 1, 0), a stride 0
    var l1 = Layout(Coord(a2, a3, a2), Coord(a6, a1, a0))
    for v in range(12):
        print("c1", v, l1(Int64(v)))
    print("c1 size", l1.size())
    print("c1 cosize", l1.cosize())

    # c2: (2, (2, 3)):(1, (2, 4)), nested
    var l2 = Layout(Coord(a2, Coord(a2, a3)), Coord(a1, Coord(a2, a4)))
    for v in range(12):
        print("c2", v, l2(Int64(v)))
    print("c2 size", l2.size())
    print("c2 cosize", l2.cosize())

    # c3: (2, 3):(3, 1), the extent 2 and the stride 1 static
    var l3 = Layout(Coord(Idx[2], a3), Coord(a3, Idx[1]))
    for v in range(6):
        print("c3", v, l3(Int64(v)))
    print("c3 size", l3.size())
    print("c3 cosize", l3.cosize())

    # c4: upcast[2] of (4, 8):(8, 1), the docstring's row_major[4, 8]
    var l4 = upcast[factor=2](Layout(Coord(a4, a8), Coord(a8, a1)))
    for v in range(l4.size()):
        print("c4", v, l4(Int64(v)))
    print("c4 size", l4.size())
    print("c4 cosize", l4.cosize())

    # c5: upcast[2] of (3):(1), whose extent 3 the factor 2 does not divide
    var l5 = upcast[factor=2](Layout(Coord(a3), Coord(a1)))
    for v in range(l5.size()):
        print("c5", v, l5(Int64(v)))
    print("c5 size", l5.size())
    print("c5 cosize", l5.cosize())

    # c6: upcast[2] of (4, 3):(3, 1), whose stride 3 and the factor 2 do not divide each other
    var l6 = upcast[factor=2](Layout(Coord(a4, a3), Coord(a3, a1)))
    for v in range(l6.size()):
        print("c6", v, l6(Int64(v)))
    print("c6 size", l6.size())
    print("c6 cosize", l6.cosize())

    # c7: upcast[2] of (4):(0), a stride 0: shape_div(2, 0) takes a remainder by 0
    var l7 = upcast[factor=2](Layout(Coord(a4), Coord(a0)))
    for v in range(l7.size()):
        print("c7", v, l7(Int64(v)))
    print("c7 size", l7.size())
    print("c7 cosize", l7.cosize())

    # c8: (0, 2):(1, 10) at the points 1 and 5, past its size 0: Mojo's divmod by the extent 0
    # gives (0, 0)
    var l8 = Layout(Coord(a0, a2), Coord(a1, Int64(10 + k)))
    for v in range(1, 6, 4):
        print("c8", v, l8(Int64(v)))
    print("c8 size", l8.size())
    print("c8 cosize", l8.cosize())
