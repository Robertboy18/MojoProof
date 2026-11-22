from layout.layout import (
    Layout, ComposedLayout, BlockedProductLayout, ZippedDivideLayout, col_major, row_major,
)
from layout.coord import Coord, ComptimeInt

comptime A = Layout[
    Coord[ComptimeInt[6], ComptimeInt[2]].element_types,
    Coord[ComptimeInt[1], ComptimeInt[6]].element_types,
]
comptime B = Layout[
    Coord[ComptimeInt[3]].element_types,
    Coord[ComptimeInt[4]].element_types,
]
comptime C = ComposedLayout[A, B]

# blocked_product with a non-compact block (2):(2): size 2, cosize 3.
comptime Blk = Layout[
    Coord[ComptimeInt[2]].element_types,
    Coord[ComptimeInt[2]].element_types,
]
comptime Til = Layout[
    Coord[ComptimeInt[2]].element_types,
    Coord[ComptimeInt[1]].element_types,
]
comptime BP = BlockedProductLayout[Blk, Til]

# zipped_divide of shape (5) by tile (2)
comptime Five = Layout[
    Coord[ComptimeInt[5]].element_types,
    Coord[ComptimeInt[1]].element_types,
]
comptime ZD = ZippedDivideLayout[Five, Coord[ComptimeInt[2]].element_types]

def main():
    comptime assert B.static_cosize == 9
    comptime assert A.static_product == 12
    comptime assert C.flat_rank == 1
    comptime assert C.static_shape[0] == 3
    comptime assert C.static_stride[0] == 6   # true A(B(i)) = 0,4,8 -> stride 4
    comptime assert Blk.static_cosize == 3
    comptime assert BP.static_stride[0] == 2
    comptime assert BP.static_stride[1] == 2  # docs: block.cosize * tiler.stride = 3
    comptime assert ZD.static_shape[0] == 2
    comptime assert ZD.static_shape[1] == 2   # 5 // 2: element 4 dropped
    comptime assert ZD.static_product == 4
    print(1)
