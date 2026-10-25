#!/usr/bin/env python3
"""Builds App/Resources/country_shapes.json (simplified country outlines).

    curl -sSLo /tmp/ne50.geojson https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
    python3 scripts/build_shapes.py /tmp/ne50.geojson

Source: Natural Earth 1:50m Admin 0 countries (public domain).
Output: {"XX": [[[lon, lat], ...], ...]} - outer rings only, Douglas-Peucker
simplified and rounded to keep the bundle small.
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources", "country_shapes.json")
TOLERANCE = 0.04      # degrees (~4 km) - plenty for an overview map
MIN_AREA = 0.004      # drop tiny islets (square degrees), except for small countries


def perp_dist(p, a, b):
    if a == b:
        return math.dist(p, a)
    (x, y), (x1, y1), (x2, y2) = p, a, b
    return abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1) / math.hypot(x2 - x1, y2 - y1)


def simplify(points, tol):
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        s, e = stack.pop()
        best, idx = 0.0, None
        for i in range(s + 1, e):
            d = perp_dist(points[i], points[s], points[e])
            if d > best:
                best, idx = d, i
        if idx is not None and best > tol:
            keep[idx] = True
            stack.append((s, idx))
            stack.append((idx, e))
    return [p for p, k in zip(points, keep) if k]


def area(ring):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]))) / 2


def main(src):
    data = json.load(open(src, encoding="utf-8"))
    out = {}
    for f in data["features"]:
        props = f["properties"]
        code = props.get("ISO_A2_EH") or props.get("ISO_A2")
        if not code or code == "-99" or len(code) != 2:
            continue
        geom = f["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        rings = []
        total = sum(area(p[0]) for p in polys)
        for poly in polys:
            outer = poly[0]
            a = area(outer)
            if a < MIN_AREA and total > 0.05:
                continue
            tol = TOLERANCE if total > 1 else TOLERANCE / 4
            s = simplify(outer, tol)
            if len(s) < 4:
                s = outer
            rings.append([[round(x, 2), round(y, 2)] for x, y in s])
        if rings:
            out.setdefault(code, []).extend(rings)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, separators=(",", ":"))
    print(f"{len(out)} countries, {os.path.getsize(OUT) // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1])
