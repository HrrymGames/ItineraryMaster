import SwiftUI

/// Draws only the given countries' outlines (no world map), each in its own colour.
/// Pinch to zoom, drag to pan, tap a country to open it.
struct CountryOutlineMap: View {
    let codes: [String]
    var counts: [String: Int] = [:]
    var onTap: (String) -> Void

    private let shapes: [CountryShape]
    private let bounds: CGRect

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    struct CountryShape: Identifiable {
        let code: String
        let rings: [[CGPoint]]
        let label: CGPoint
        let colorIndex: Int
        var id: String { code }
    }

    init(codes: [String], counts: [String: Int] = [:], onTap: @escaping (String) -> Void) {
        self.codes = codes
        self.counts = counts
        self.onTap = onTap
        let built = Self.build(codes)
        self.shapes = built.shapes
        self.bounds = built.bounds
    }

    /// Projects lon/lat to a flat plane (equirectangular, scaled by the mid latitude).
    private static func build(_ codes: [String]) -> (shapes: [CountryShape], bounds: CGRect) {
        let raw = codes.compactMap { c in CountryShapes.all[c].map { (c, $0) } }
        var lats: [Double] = []
        for (_, rings) in raw {
            for ring in rings {
                for p in ring where p.count > 1 { lats.append(p[1]) }
            }
        }
        let midLat = lats.isEmpty ? 0 : (lats.min()! + lats.max()!) / 2
        let k = cos(midLat * .pi / 180)
        var shapes: [CountryShape] = []
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for (i, (code, rings)) in raw.enumerated() {
            var projected: [[CGPoint]] = []
            var bestArea = -1.0
            var label = CGPoint.zero
            for ring in rings {
                let pts = ring.compactMap { p -> CGPoint? in
                    guard p.count >= 2 else { return nil }
                    return CGPoint(x: p[0] * k, y: -p[1])
                }
                guard pts.count >= 3 else { continue }
                var rMinX = Double.infinity, rMinY = Double.infinity, rMaxX = -Double.infinity, rMaxY = -Double.infinity
                for p in pts {
                    rMinX = min(rMinX, p.x); rMaxX = max(rMaxX, p.x)
                    rMinY = min(rMinY, p.y); rMaxY = max(rMaxY, p.y)
                }
                minX = min(minX, rMinX); maxX = max(maxX, rMaxX)
                minY = min(minY, rMinY); maxY = max(maxY, rMaxY)
                let area = (rMaxX - rMinX) * (rMaxY - rMinY)
                if area > bestArea {
                    bestArea = area
                    label = CGPoint(x: (rMinX + rMaxX) / 2, y: (rMinY + rMaxY) / 2)
                }
                projected.append(pts)
            }
            if !projected.isEmpty {
                shapes.append(CountryShape(code: code, rings: projected, label: label, colorIndex: i))
            }
        }
        guard minX.isFinite else { return ([], .zero) }
        return (shapes, CGRect(x: minX, y: minY, width: max(0.1, maxX - minX), height: max(0.1, maxY - minY)))
    }

    var body: some View {
        GeometryReader { geo in
            let t = transform(for: geo.size)
            ZStack {
                Canvas { ctx, _ in
                    for s in shapes {
                        let path = Self.path(for: s, t)
                        let color = Theme.countryPalette[s.colorIndex % Theme.countryPalette.count]
                        ctx.fill(path, with: .color(color.opacity(0.85)))
                        ctx.stroke(path, with: .color(.white), lineWidth: 1.2)
                    }
                }
                ForEach(shapes) { s in
                    let p = t(s.label)
                    VStack(spacing: 0) {
                        Text(CountryStore.shared.flag(s.code)).font(.title3)
                        if let n = counts[s.code], n > 0 {
                            Text("\(n)").font(.caption2.bold())
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.white.opacity(0.9), in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    .position(p)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    for s in shapes.reversed() where Self.path(for: s, t).contains(value.location) {
                        onTap(s.code)
                        return
                    }
                }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in zoom = min(8, max(1, lastZoom * v)) }
                    .onEnded { _ in lastZoom = zoom }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in pan = CGSize(width: lastPan.width + v.translation.width, height: lastPan.height + v.translation.height) }
                    .onEnded { _ in lastPan = pan }
            )
        }
        .overlay(alignment: .topTrailing) {
            if zoom > 1.01 || pan != .zero {
                Button {
                    withAnimation { zoom = 1; lastZoom = 1; pan = .zero; lastPan = .zero }
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .padding(8)
                        .background(.thinMaterial, in: Circle())
                }
                .padding(8)
            }
        }
        .overlay {
            if shapes.isEmpty {
                ContentUnavailableView("No countries yet", systemImage: "globe.asia.australia",
                                       description: Text("Save videos that mention a place, or add stops to your route."))
            }
        }
        .clipped()
    }

    private func transform(for size: CGSize) -> (CGPoint) -> CGPoint {
        let pad: CGFloat = 16
        let w = max(1, size.width - pad * 2), h = max(1, size.height - pad * 2)
        let scale = min(w / bounds.width, h / bounds.height) * zoom
        let ox = (size.width - bounds.width * scale) / 2 + pan.width
        let oy = (size.height - bounds.height * scale) / 2 + pan.height
        let b = bounds
        return { p in CGPoint(x: (p.x - b.minX) * scale + ox, y: (p.y - b.minY) * scale + oy) }
    }

    private static func path(for s: CountryShape, _ t: (CGPoint) -> CGPoint) -> Path {
        var path = Path()
        for ring in s.rings {
            path.addLines(ring.map(t))
            path.closeSubpath()
        }
        return path
    }
}
