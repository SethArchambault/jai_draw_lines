// Port of https://github.com/mapbox/earcut


// Example use:
#if 0 {
    main :: () {
        triangles, result := triangulate(
            // Contour of the polygon
            Vector2.[ .{0,0}, .{100,0}, .{100,100}, .{0,100} ],
            .[
                // Contour of the hole
                .[ .{20,20}, .{80,20}, .{80,80}, .{20,80} ]
            ]
        ,, temp);
        assert(result == .SUCCESS);
        for triangles log("%", it);
    }
    #import "Basic";
    #import "Math";
    #import "Earcut";
}


// This module could use a big rewrite -- it currently mostly matches the original API, except for
// the following triangulate() procedure, which seems like a better API.

// In places where original API functions were only invoked in a single location, I've moved those
// procedures to be inlined, and local to their required scope. Ugly, but it works, and helps track
// down implementation issues.


// (Maybe(?)) better API:
triangulate :: (contour: [] Vector2, hole_indices:[]int) -> triangles: [][3] Vector2, result: enum {
    SUCCESS;
    FAILURE_BAD_POLYGON;
} {
    if contour.count < 3 then return .[], .FAILURE_BAD_POLYGON;

    for hole_indices {
      if it >= contour.count {
        array_ordered_remove_by_index(*hole_indices, it_index);
      }
    }

    triangles:    [..] [3] Vector2; // Allocator intentionally omitted
    data:         [..] float;         data.allocator = temp;

    // Since we're preprocessing the data for earcut() and our vertices are $T/interface Vector2,
    // we know we only need 2 dimensions.
    DIMENSIONS :: 2;

    for contour array_add(*data, it.x, it.y);

    output := earcut(data, hole_indices, DIMENSIONS,, temp);
    if output.count == 0 then return .[], .FAILURE_BAD_POLYGON;

    i := 0;
    while i < output.count {
        i0, i1, i2 :=
            output[i+0]*DIMENSIONS,
            output[i+1]*DIMENSIONS,
            output[i+2]*DIMENSIONS;
        array_add(*triangles, .[
            .{data[i0], data[i0+1]},
            .{data[i1], data[i1+1]},
            .{data[i2], data[i2+1]}
        ]);
        i += 3;
    }
    return triangles, .SUCCESS;
}

// Original API:
earcut :: (data: [] float, hole_indices: [] int = .[], $DIMENSIONS := 2) -> [] int {
    triangles: [..] int;  // Allocator intentionally omitted
    nodes:     [..] Node; nodes.allocator = temp;
    array_reserve(*nodes, data.count*3/2); // not sure if this is optimal, but it seems like it works?

    has_holes  := hole_indices.count > 0;
    outer_len  := ifx has_holes then hole_indices[0] * DIMENSIONS else data.count;
    outer_node := linked_list(data, *nodes, 0, outer_len, DIMENSIONS, true);

    if (!outer_node || outer_node.next == outer_node.prev) return triangles; // bad polygon

    eliminate_holes :: inline (data: [] float, hole_indices: [] int, nodes: *Nodes, outer_node_: *Node, dim: int) -> *Node {
        eliminate_hole :: inline (nodes: *Nodes, hole: *Node, outer_node: *Node) -> *Node {
            find_hole_bridge :: inline (hole: *Node, outer_node: *Node) -> *Node {
                p := outer_node;
                hx := hole.x;
                hy := hole.y;
                qx := -FLOAT32_INFINITY;
                m: *Node;
                while true {
                    if hy <= p.y && hy >= p.next.y && p.next.y != p.y {
                        x := p.x + (hy-p.y)*(p.next.x-p.x)/(p.next.y-p.y);
                        if x <= hx && x > qx {
                            qx = x;
                            m = ifx p.x < p.next.x then p else p.next;
                            if x == hx then return m;
                        }
                    }
                    p = p.next;
                    if p == outer_node then break;
                }
                if !m then return null;

                stop := m;
                mx := m.x;
                my := m.y;
                tan_min := FLOAT32_INFINITY;
                p = m;
                while true {
                    if hx >= p.x && p.x >= mx && hx != p.x && point_is_in_triangle(
                        ifx hy < my then hx else qx, hy, mx, my, ifx hy < my then qx else hx, hy, p.x, p.y
                    ) {
                        tan := abs(hy-p.y)/(hx-p.x);
                        if is_locally_inside(p, hole) && (tan < tan_min || (tan == tan_min && (p.x > m.x || (p.x == m.x && (area(m.prev, m, p.prev) < 0 && area(p.next, m, m.next) < 0))))) {
                            m = p;
                            tan_min = tan;
                        }
                    }
                    p = p.next;
                    if p == stop then break;
                }
                return m;
            }
            bridge := find_hole_bridge(hole, outer_node);
            if !bridge then return outer_node;
            bridge_reverse := split_polygon(nodes, bridge, hole);
            filter_points(bridge_reverse, bridge_reverse.next);
            return filter_points(bridge, bridge.next);
        }

        queue: [..] *Node; queue.allocator = temp;

        for 0..hole_indices.count-1 {
            start := hole_indices[it]*dim;
            end   := ifx it < hole_indices.count-1 then hole_indices[it+1]*dim else data.count;
            list  := linked_list(data, nodes, start, end, dim, false);
            if list == list.next then list.is_steiner = true;

            get_leftmost :: inline (start: *Node) -> *Node {
                p := start;
                leftmost := start;
                while true {
                    if p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y) then leftmost = p;
                    p = p.next;
                    if p == start then break;
                }
                return leftmost;
            }
            array_add(*queue, get_leftmost(list));
        }
        quick_sort(queue, (a, b) => a.x-b.x);
        outer_node := outer_node_;
        for 0..queue.count-1 outer_node = eliminate_hole(nodes, queue[it], outer_node);
        return outer_node;
    }
    if has_holes then outer_node = eliminate_holes(data, hole_indices, *nodes, outer_node, DIMENSIONS);

    min_x, min_y, inv_size: float;

    ARBITRARY_THRESHOLD :: 80*DIMENSIONS;
    if data.count > ARBITRARY_THRESHOLD {
        min_x = FLOAT32_INFINITY;
        min_y = FLOAT32_INFINITY;
        max_x := -FLOAT32_INFINITY;
        max_y := -FLOAT32_INFINITY;
        
        i := DIMENSIONS;
        while i < outer_len {
            x := data[i];
            y := data[i+1];
            if x < min_x then min_x = x;
            if y < min_y then min_y = y;
            if x > max_x then max_x = x;
            if y > max_y then max_y = y;
            i += DIMENSIONS;
        }
        inv_size = max(max_x-min_x, max_y-min_y);
        inv_size = ifx inv_size != 0 then 1.0 / inv_size else 0;
    }
    earcut_linked(*nodes, outer_node, *triangles, DIMENSIONS, min_x, min_y, inv_size, 0);

    return triangles;
}

#scope_file //======================================================================================

earcut_linked :: (nodes: *Nodes, ear: *Node, triangles: *[..] int, dim: int, min_x: float, min_y: float, inv_size: float, pass: int) {
    index_curve :: inline (start: *Node, min_x: float, min_y: float, inv_size: float) {
        p := start;
        while true {
            if p.z == 0 then p.z = z_order(p.x, p.y, min_x, min_y, inv_size);
            p.prev_z = p.prev;
            p.next_z = p.next;
            p = p.next;
            if p == start then break;
        }
        p.prev_z.next_z = null;
        p.prev_z = null;

        sort_linked :: inline (list_: *Node) -> *Node {
            num_merges: int;
            in_size := 1;

            list := list_;
            while true {
                p := list;
                e: *Node;
                list = null;
                tail: *Node;
                num_merges := 0;

                while p {
                    num_merges += 1;
                    q := p;
                    p_size := 0;
                    for 0..in_size-1 {
                        p_size += 1;
                        q = q.next_z;
                        if !q then break;
                    }
                    q_size := in_size;
                    while p_size > 0 || (q_size > 0 && q) {
                        if p_size != 0 && (q_size == 0 || !q || p.z <= q.z) {
                            e = p;
                            p = p.next_z;
                            p_size -= 1;
                        } else {
                            e = q;
                            q = q.next_z;
                            q_size -= 1;
                        }
                        if tail
                            then tail.next_z = e;
                            else list = e;
                        e.prev_z = tail;
                        tail = e;
                    }
                    p = q;
                }
                tail.next_z = null;
                in_size *= 2;
                if num_merges <= 1 then break;
            }
            return list;
        }
        sort_linked(p);
    }
    split_earcut :: inline (nodes: *Nodes, start: *Node, triangles: *[..] int, dim: int, min_x: float, min_y: float, inv_size: float) {
        is_valid_diagonal :: inline (a: *Node, b: *Node) -> bool {
            intersects_polygon :: inline (a: *Node, b: *Node) -> bool {
                p := a;
                while true {
                    if p.i != a.i && p.next.i != a.i && p.i != b.i && p.next.i != b.i && intersects(p, p.next, a, b) then return true;
                    p = p.next;
                    if p == a then break;
                }
                return false;
            }
            is_middle_inside :: inline (a: *Node, b: *Node) -> bool {
                p := a;
                inside := false;
                px := (a.x+b.x)/2;
                py := (a.y+b.y)/2;
                while true {
                    if ((p.y > py) != (p.next.y > py)) && p.next.y != p.y && (px < (p.next.x-p.x)*(py-p.y)/(p.next.y-p.y)+p.x) then inside = !inside;
                    p = p.next;
                    if p == a then break;
                }
                return inside;
            }
            return a.next.i != b.i && a.prev.i != b.i && !intersects_polygon(a, b) && (
                is_locally_inside(a, b) && is_locally_inside(b, a) && is_middle_inside(a, b) &&
                (area(a.prev, a, b.prev) != 0 || area(a, b.prev, b) != 0) ||
                equals(a, b) && area(a.prev, a, a.next) > 0 && area(b.prev, b, b.next) > 0
            );
        }
        a := start;
        while true {
            b := a.next.next;
            while b != a.prev {
                if a.i != b.i && is_valid_diagonal(a, b) {
                    c := split_polygon(nodes, a, b);
                    a = filter_points(a, a.next);
                    c = filter_points(c, c.next);
                    earcut_linked(nodes, a, triangles, dim, min_x, min_y, inv_size, 0);
                    earcut_linked(nodes, c, triangles, dim, min_x, min_y, inv_size, 0);
                    return;
                }
                b = b.next;
            }
            a = a.next;
            if a == start then break;
        }
    }
    cure_local_intersections :: inline (start_: *Node, triangles: *[..] int) -> *Node {
        start := start_;
        p := start;
        while true {
            a, b := p.prev, p.next.next;

            if !equals(a, b) && intersects(a, p, p.next, b) && is_locally_inside(a, b) && is_locally_inside(b, a) {
                array_add(triangles, a.i, p.i, b.i);
                remove_node(p);
                remove_node(p.next);
                start = b;
                p = start;
            }
            p = p.next;
            if p == start then break;
        }
        return filter_points(p);
    }
    is_ear_hashed :: inline (ear: Node, min_x: float, min_y: float, inv_size: float) -> bool {
        a, b, c := ear.prev, ear, ear.next;
        if area(a, b, c) >= 0 then return false;
        ax, bx, cx, ay, by, cy := a.x, b.x, c.x, a.y, b.y, c.y;
        x0, y0, x1, y1 :=
            ifx ax < bx then ifx ax < cx then ax else cx else ifx bx < cx then bx else cx,
            ifx ay < by then ifx ay < cy then ay else cy else ifx by < cy then by else cy,
            ifx ax > bx then ifx ax > cx then ax else cx else ifx bx > cx then bx else cx,
            ifx ay > by then ifx ay > cy then ay else cy else ifx by > cy then by else cy;

        min_z, max_z := z_order(x0, y0, min_x, min_y, inv_size), z_order(x1, y1, min_x, min_y, inv_size);

        p := ear.prev_z;
        n := ear.next_z;

        while p && p.z >= min_z && n && n.z <= max_z {
            if p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1 && p != a && p != c && point_is_in_triangle(ax, ay, bx, by, cx, cy, p.x, p.y) && area(p.prev, p, p.next) >= 0 then return false;
            p = p.prev_z;
            if n.x >= x0 && n.x <= x1 && n.y >= y0 && n.y <= y1 && p != a && p != c && point_is_in_triangle(ax, ay, bx, by, cx, cy, n.x, n.y) && area(n.prev, p, n.next) >= 0 then return false;
            n = n.next_z;
        }
        while p && p.z >= min_z {
            if p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1 && p != a && p != c && point_is_in_triangle(ax, ay, bx, by, cx, cy, p.x, p.y) && area(p.prev, p, p.next) >= 0 then return false;
            p = p.prev_z;
        }
        while n && n.z <= max_z {
            if n.x >= x0 && n.x <= x1 && n.y >= y0 && n.y <= y1 && p != a && p != c && point_is_in_triangle(ax, ay, bx, by, cx, cy, n.x, n.y) && area(n.prev, p, n.next) >= 0 then return false;
            n = n.next_z;
        }
        return true;
    }
    if !ear then return;
    if !pass && inv_size != 0 then index_curve(ear, min_x, min_y, inv_size);
    stop := ear;
    while ear.prev != ear.next {
        prev := ear.prev;
        next := ear.next;
        if ifx inv_size != 0 then is_ear_hashed(ear, min_x, min_y, inv_size) else is_ear(ear) {
            array_add(triangles, prev.i, ear.i, next.i);
            remove_node(ear);
            ear = next.next;
            stop = next.next;
            continue;
        }
        ear = next;
        if ear == stop {
            if pass == {
            case 0;
                earcut_linked(nodes, filter_points(ear), triangles, dim, min_x, min_y, inv_size, 1);
            case 1;
                ear = cure_local_intersections(filter_points(ear), triangles);
                earcut_linked(nodes, ear, triangles, dim, min_x, min_y, inv_size, 2);
            case 2;
                split_earcut(nodes, ear, triangles, dim, min_x, min_y, inv_size);
            }
            break;
        }
    }
}

is_ear :: (ear: Node) -> bool {
    a, b, c := ear.prev, ear, ear.next;
    if area(a, b, c) >= 0 then return false;
    ax, bx, cx, ay, by, cy := a.x, b.x, c.x, a.y, b.y, c.y;
    x0, y0, x1, y1 :=
        ifx ax < bx then ifx ax < cx then ax else cx else ifx bx < cx then bx else cx,
        ifx ay < by then ifx ay < cy then ay else cy else ifx by < cy then by else cy,
        ifx ax > bx then ifx ax > cx then ax else cx else ifx bx > cx then bx else cx,
        ifx ay > by then ifx ay > cy then ay else cy else ifx by > cy then by else cy;
    p := c.next;
    while p != a {
        if p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1 && point_is_in_triangle(ax, ay, bx, by, cx, cy, p.x, p.y) && area(p.prev, p, p.next) >= 0 then return false;
        p = p.next;
    }
    return true;
}

z_order :: (x: float, y: float, min_x: float, min_y: float, inv_size: float) -> int {
    xi := 32767 * cast(int)(x-min_x) * cast(int)(inv_size);
    yi := 32767 * cast(int)(y-min_y) * cast(int)(inv_size);

    xi = (xi | (xi << 8)) & 0x00FF_00FF;
    xi = (xi | (xi << 4)) & 0x0F0F_0F0F;
    xi = (xi | (xi << 2)) & 0x3333_3333;
    xi = (xi | (xi << 1)) & 0x5555_5555;

    yi = (yi | (yi << 8)) & 0x00FF_00FF;
    yi = (yi | (yi << 4)) & 0x0F0F_0F0F;
    yi = (yi | (yi << 2)) & 0x3333_3333;
    yi = (yi | (yi << 1)) & 0x5555_5555;

    return xi | (yi << 1);
}

linked_list :: (data: [] float, nodes: *Nodes, start: int, end: int, dim: int, clockwise: bool) -> *Node {
    insert_node :: (nodes: *Nodes, i: int, x: float, y: float, last: *Node) -> *Node {
        node := create_node(nodes, i, x, y);
        if !last {
            node.prev = node;
            node.next = node;
        } else {
            node.next = last.next;
            node.prev = last;
            last.next.prev = node;
            last.next = node;
        }
        return node;
    }
    signed_area :: (data: [] float, start: int, end: int, dim: int) -> float {
        sum: float;
        i := start;
        j := end-dim;
        while i < end {
            sum += (data[j]-data[i]) * (data[i+1]+data[j+1]);
            j = i;
            i += dim;
        }
        return sum;
    }
    last: *Node;
    if clockwise == (signed_area(data, start, end, dim) > 0) {
        i := start;
        while i < end {
            last = insert_node(nodes, i/dim, data[i], data[i+1], last);
            i += dim;
        }
    } else {
        i := end-dim;
        while i >= start {
            last = insert_node(nodes, i/dim, data[i], data[i+1], last);
            i -= dim;
        }
    }

    if last && equals(last, last.next) {
        remove_node(last);
        last = last.next;
    }

    return last;
}

Node :: struct {
    i:              int;
    x, y:           float;
    prev, next:     *Node;
    z:              int;
    prev_z, next_z: *Node;
    is_steiner:     bool;
}
Nodes :: #type [..] Node;

create_node :: (nodes: *Nodes, i: int, x: float, y: float) -> *Node {
    array_add(nodes, .{i=i, x=x, y=y});
    return peek_pointer(nodes.*);
}

remove_node :: (node: *Node) {
    node.next.prev = node.prev;
    node.prev.next = node.next;
    if node.prev_z then node.prev_z.next_z = node.next_z;
    if node.next_z then node.next_z.prev_z = node.prev_z;
}

filter_points :: (start_: *Node, end_: *Node = null) -> *Node {
    start, end := start_, end_;
    if !start then return null;
    if !end then end = start;
    p := start;
    while true {
        again := false;
        if !p.is_steiner && (equals(p, p.next) || area(p.prev, p, p.next) == 0) {
            remove_node(p);
            end = p.prev;
            p = end;
            if p == p.next then break;
            again = true;
        } else {
            p = p.next;
        }
        if !again || p == end then break;
    }
    return end;
}

point_is_in_triangle :: (ax: float, ay: float, bx: float, by: float, cx: float, cy: float, px: float, py: float) -> bool {
    return (cx-px)*(ay-py) >= (ax-px)*(cy-py) &&
           (ax-px)*(by-py) >= (bx-px)*(ay-py) &&
           (bx-px)*(cy-py) >= (cx-px)*(by-py) ;
}

is_locally_inside :: (a: Node, b: Node) -> bool {
    return ifx area(a.prev, a, a.next) < 0
        then area(a, b, a.next) >= 0 && area(a, a.prev, b) >= 0
        else area(a, b, a.prev) <  0 || area(a, a.next, b) <  0;
}

area :: (p: Node, q: Node, r: Node) -> float {
    return (q.y-p.y)*(r.x-q.x)-(q.x-p.x)*(r.y-q.y);
}

equals :: (p1: Node, p2: Node) -> bool { return p1.x == p2.x && p1.y == p2.y; }

intersects :: (p1: Node, q1: Node, p2: Node, q2: Node) -> bool {
    sign :: (n) => ifx n > 0 then 1 else ifx n < 0 then -1 else 0;

    o1, o2, o3, o4 :=
        sign(area(p1, q1, p2)),
        sign(area(p1, q1, q2)),
        sign(area(p2, q2, p1)),
        sign(area(p2, q2, q1));
    if o1 != o2 && o3 != o4 then return true;

    on_segment :: (p, q, r) => q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) && q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y);
    
    return
        (o1 == 0 && on_segment(p1, p2, q1)) ||
        (o2 == 0 && on_segment(p1, q2, q1)) ||
        (o3 == 0 && on_segment(p2, p1, q2)) ||
        (o4 == 0 && on_segment(p2, q1, q2));
}

split_polygon :: (nodes: *Nodes, a: *Node, b: *Node) -> *Node {
    a2 := create_node(nodes, a.i, a.x, a.y);
    b2 := create_node(nodes, b.i, b.x, b.y);

    an, bp := a.next, b.prev;

     a.next,  b.prev = b , a ;
    a2.next, an.prev = an, a2;
    b2.next, a2.prev = a2, b2;
    bp.next, b2.prev = b2, bp;

    return b2;
}


#import "Basic";
#import "Math";
#import "Sort";

/*
ISC License

Copyright (c) 2015, Mapbox

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
*/
