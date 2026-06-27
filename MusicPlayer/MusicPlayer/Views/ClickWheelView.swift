import SwiftUI

struct ClickWheelView: View {
    var onMenu: () -> Void
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onPlayPause: () -> Void
    var onCenter: () -> Void
    var onScroll: (CGFloat) -> Void

    @State private var lastAngle: CGFloat? = nil
    @State private var startLocation: CGPoint? = nil
    @State private var totalRotation: CGFloat = 0
    @State private var pressedRegion: WheelRegion? = nil

    enum WheelRegion { case center, top, right, bottom, left }

    var body: some View {
        GeometryReader { geo in
            let side   = min(geo.size.width, geo.size.height)
            let cx     = geo.size.width  / 2
            let cy     = geo.size.height / 2
            let center = CGPoint(x: cx, y: cy)
            let outerR = side / 2
            let innerR = side * 0.318   // centre button radius

            ZStack {
                outerWheel(side: side, outerR: outerR)
                wheelLabels(side: side, innerR: innerR)
                centerButton(side: side, innerR: innerR)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        handleChanged(v, center: center, innerR: innerR)
                    }
                    .onEnded { v in
                        handleEnded(v, center: center, outerR: outerR, innerR: innerR)
                    }
            )
        }
    }

    // MARK: - Sub-views

    private func outerWheel(side: CGFloat, outerR: CGFloat) -> some View {
        // The iPod Classic wheel is a smooth, slightly shiny white disc
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.960),
                        Color(white: 0.880),
                        Color(white: 0.830)
                    ],
                    startPoint: .topLeading,
                    endPoint:   .bottomTrailing
                )
            )
            // Outer ridge / bevel
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.96), Color(white: 0.55)],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            // Drop shadow
            .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.12), radius:  4, x: 0, y: 2)
            // Specular highlight along top-left arc
            .overlay(
                Circle()
                    .trim(from: 0.60, to: 0.90)          // top-left arc
                    .stroke(Color.white.opacity(0.55), lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            )
    }

    private func wheelLabels(side: CGFloat, innerR: CGFloat) -> some View {
        let iconSize:   CGFloat = side * 0.095
        let labelInset: CGFloat = side * 0.072
        let menuSize:   CGFloat = side * 0.066
        let tint = Color(white: 0.28)

        return ZStack {
            // MENU – top
            VStack {
                Text("MENU")
                    .font(.system(size: menuSize, weight: .bold, design: .default))
                    .foregroundColor(pressedRegion == .top ? Color(white: 0.05) : tint)
                    .kerning(0.5)
                Spacer()
            }
            .frame(width: side, height: side)
            .padding(.top, labelInset)

            // |<< – left
            HStack {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(pressedRegion == .left ? Color(white: 0.05) : tint)
                Spacer()
            }
            .frame(width: side, height: side)
            .padding(.leading, labelInset)

            // >>| – right
            HStack {
                Spacer()
                Image(systemName: "forward.end.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(pressedRegion == .right ? Color(white: 0.05) : tint)
            }
            .frame(width: side, height: side)
            .padding(.trailing, labelInset)

            // ▶︎/⏸ – bottom
            VStack {
                Spacer()
                Image(systemName: "playpause.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(pressedRegion == .bottom ? Color(white: 0.05) : tint)
            }
            .frame(width: side, height: side)
            .padding(.bottom, labelInset)
        }
    }

    private func centerButton(side: CGFloat, innerR: CGFloat) -> some View {
        let diam = innerR * 2
        let pressed = pressedRegion == .center
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        pressed ? Color(white: 0.80) : Color(white: 0.955),
                        pressed ? Color(white: 0.70) : Color(white: 0.840)
                    ],
                    center:      UnitPoint(x: 0.36, y: 0.30),
                    startRadius: 0,
                    endRadius:   innerR
                )
            )
            .frame(width: diam, height: diam)
            // Inner bevel ring
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.92), Color(white: 0.52)],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: diam, height: diam)
            )
            .shadow(color: .black.opacity(0.20), radius: 5, x: 0, y: 2)
            .shadow(color: .white.opacity(0.80), radius: 2, x: -1, y: -1)
    }

    // MARK: - Gesture handling

    private func handleChanged(_ v: DragGesture.Value, center: CGPoint, innerR: CGFloat) {
        let dx = v.location.x - center.x
        let dy = v.location.y - center.y
        let dist = hypot(dx, dy)

        if startLocation == nil {
            startLocation  = v.location
            totalRotation  = 0
        }

        if dist > innerR + 6 {
            // Ring – compute rotation delta for scroll
            let angle = atan2(dy, dx)
            if let last = lastAngle {
                var delta = angle - last
                if delta >  .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                totalRotation += delta
                onScroll(delta)
            }
            lastAngle     = angle
            pressedRegion = nil
        } else {
            pressedRegion = .center
            lastAngle     = nil
        }
    }

    private func handleEnded(_ v: DragGesture.Value, center: CGPoint, outerR: CGFloat, innerR: CGFloat) {
        let dx   = v.location.x - center.x
        let dy   = v.location.y - center.y
        let dist = hypot(dx, dy)

        let travelDist = startLocation.map { s in
            hypot(v.location.x - s.x, v.location.y - s.y)
        } ?? 0

        // Fire a button only if gesture was a short tap (no real scroll movement)
        if travelDist < 14 && abs(totalRotation) < 0.10 {
            if dist <= innerR {
                onCenter()
            } else if dist <= outerR {
                let deg  = atan2(dy, dx) * 180 / .pi
                let norm = deg < 0 ? deg + 360 : deg
                switch norm {
                case 315...360, 0..<45:  onMenu()
                case 45..<135:           onNext()
                case 135..<225:          onPlayPause()
                default:                 onPrevious()
                }
            }
        }

        lastAngle     = nil
        startLocation = nil
        totalRotation = 0
        withAnimation(.easeOut(duration: 0.10)) { pressedRegion = nil }
    }
}
