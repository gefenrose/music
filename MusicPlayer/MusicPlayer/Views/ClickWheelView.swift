import SwiftUI

struct ClickWheelView: View {
    var onMenu:      () -> Void
    var onPrevious:  () -> Void
    var onNext:      () -> Void
    var onPlayPause: () -> Void
    var onCenter:    () -> Void
    var onScroll:    (CGFloat) -> Void

    @State private var lastAngle:     CGFloat? = nil
    @State private var startLocation: CGPoint? = nil
    @State private var totalRotation: CGFloat  = 0
    @State private var pressedRegion: Region?  = nil

    enum Region { case center, top, right, bottom, left }

    // Label/icon colour – matches the gray in the screenshots
    private let labelColor = Color(white: 0.60)

    var body: some View {
        GeometryReader { geo in
            let side   = min(geo.size.width, geo.size.height)
            let cx     = geo.size.width  / 2
            let cy     = geo.size.height / 2
            let cpt    = CGPoint(x: cx, y: cy)
            let outerR = side / 2
            let innerR = side * 0.330   // centre button radius

            ZStack {
                outerRing(side: side)
                labels(side: side, innerR: innerR)
                centerButton(side: side, innerR: innerR)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in changed(v, center: cpt, innerR: innerR) }
                    .onEnded   { v in ended(v,   center: cpt, outerR: outerR, innerR: innerR) }
            )
        }
    }

    // MARK: - Sub-views

    private func outerRing(side: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            // Subtle drop shadow
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
            .shadow(color: .black.opacity(0.08), radius:  3, x: 0, y: 2)
    }

    private func labels(side: CGFloat, innerR: CGFloat) -> some View {
        let ringMid: CGFloat = (side / 2 + innerR) / 2
        let iconPt:  CGFloat = side * 0.088
        let menuPt:  CGFloat = side * 0.065
        let inset:   CGFloat = side / 2 - ringMid

        return ZStack {
            // MENU – top
            VStack {
                Text("MENU")
                    .font(.system(size: menuPt, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(pressedRegion == .top ? Color(white: 0.35) : labelColor)
                Spacer()
            }
            .frame(width: side, height: side)
            .padding(.top, inset - menuPt * 0.6)

            // |<< – left
            HStack {
                skipIcon(name: "backward.end.fill", size: iconPt,
                         pressed: pressedRegion == .left)
                Spacer()
            }
            .frame(width: side, height: side)
            .padding(.leading, inset - iconPt * 0.6)

            // >>| – right
            HStack {
                Spacer()
                skipIcon(name: "forward.end.fill", size: iconPt,
                         pressed: pressedRegion == .right)
            }
            .frame(width: side, height: side)
            .padding(.trailing, inset - iconPt * 0.6)

            // ▶⏸ – bottom
            VStack {
                Spacer()
                skipIcon(name: "playpause.fill", size: iconPt,
                         pressed: pressedRegion == .bottom)
            }
            .frame(width: side, height: side)
            .padding(.bottom, inset - iconPt * 0.6)
        }
    }

    private func skipIcon(name: String, size: CGFloat, pressed: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(pressed ? Color(white: 0.30) : labelColor)
    }

    private func centerButton(side: CGFloat, innerR: CGFloat) -> some View {
        let diam    = innerR * 2
        let pressed = pressedRegion == .center
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(white: pressed ? 0.76 : 0.865),
                        Color(white: pressed ? 0.66 : 0.780),
                    ],
                    center:      UnitPoint(x: 0.40, y: 0.36),
                    startRadius: 0,
                    endRadius:   innerR * 0.9
                )
            )
            .frame(width: diam, height: diam)
            // Inset shadow between ring and button
            .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 2)
    }

    // MARK: - Gesture handling

    private func changed(_ v: DragGesture.Value, center: CGPoint, innerR: CGFloat) {
        let dx   = v.location.x - center.x
        let dy   = v.location.y - center.y
        let dist = hypot(dx, dy)

        if startLocation == nil { startLocation = v.location; totalRotation = 0 }

        if dist > innerR + 6 {
            // Ring – scroll
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

    private func ended(_ v: DragGesture.Value, center: CGPoint, outerR: CGFloat, innerR: CGFloat) {
        let dx   = v.location.x - center.x
        let dy   = v.location.y - center.y
        let dist = hypot(dx, dy)

        let travel = startLocation.map { s in
            hypot(v.location.x - s.x, v.location.y - s.y)
        } ?? 0

        if travel < 14 && abs(totalRotation) < 0.10 {
            if dist <= innerR {
                onCenter()
            } else if dist <= outerR {
                let deg  = atan2(dy, dx) * 180 / .pi
                let norm = deg < 0 ? deg + 360 : deg
                switch norm {
                case 315...360, 0..<45: onMenu()
                case 45..<135:          onNext()
                case 135..<225:         onPlayPause()
                default:                onPrevious()
                }
            }
        }

        lastAngle     = nil
        startLocation = nil
        totalRotation = 0
        withAnimation(.easeOut(duration: 0.10)) { pressedRegion = nil }
    }
}
