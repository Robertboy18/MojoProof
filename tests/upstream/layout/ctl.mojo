from layout.layout import Layout, ComposedLayout
from layout.coord import Coord, ComptimeInt
comptime A = Layout[
    Coord[ComptimeInt[6], ComptimeInt[2]].element_types,
    Coord[ComptimeInt[1], ComptimeInt[6]].element_types,
]
comptime B = Layout[
    Coord[ComptimeInt[3]].element_types,
    Coord[ComptimeInt[4]].element_types,
]
def main():
    comptime assert ComposedLayout[A, B].static_stride[0] == 4, "control: stride is not 4"
    print(1)
