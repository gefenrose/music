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

    enum WheelRegion {
        case center, top, right, bottom, left
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerR = size / 2
            let innerR = size * 0.315

            ZStack {
                // ── Outer ring ──
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.84)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 5)
                    .shadow(color: .white.opacity(0.8), radius: 3, x: -1, y: -1)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.98), Color(white: 0.65)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )

                // ── Button labels ──

                // MENU
                VStack {
                    Text("MENU")
                        .font(.system(size: size * 0.072, weight: .bold, design: .default))
                        .foregroundColor(pressedRegion == .top ? Color(white: 0.15) : Color(white: 0.3))
                    Spacer()
                }
                .frame(width: size, height: size)
                .padding(.top, size * 0.075)

                // |<< and >>|
                HStack {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: size * 0.1, weight: .semibold))
                        .foregroundColor(pressedRegion == .left ? Color(white: 0.1) : Color(white: 0.3))
                    Spacer()
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: size * 0.1, weight: .semibold))
                        .foregroundColor(pressedRegion == .right ? Color(white: 0.1) : Color(white: 0.3))
                }
                .frame(width: size, height: size)
                .padding(.horizontal, size * 0.075)

                // Play/Pause
                VStack {
                    Spacer()
                    Image(systemName: "playpause.fill")
                        .font(.system(size: size * 0.1, weight: .semibold))
                        .foregroundColor(pressedRegion == .bottom ? Color(white: 0.1) : Color(white: 0.3))
                }
                .frame(width: size, height: size)
                .padding(.bottom, size * 0.075)

                // ── Center button ──
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: pressedRegion == .center ? 0.86 : 0.95),
                                Color(white: pressedRegion == .center ? 0.76 : 0.84)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.33),
                            startRadius: 2,
                            endRadius: innerR
                        )
                    )
                    .frame(width: innerR * 2, height: innerR * 2)
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 2, x: -1, y: -1)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.9), Color(white: 0.62)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                            .frame(width: innerR * 2, height: innerR * 2)
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = sqrt(dx * dx + dy * dy)

                        if startLocation == nil {
                            startLocation = value.location
                            totalRotation = 0
                        }

                        if dist > innerR + 4 {
                            // On the ring — scroll
                            let angle = atan2(dy, dx)
                            if let last = lastAngle {
                                var delta = angle - last
                                if delta > .pi { delta -= 2 * .pi }
                                if delta < -.pi { delta += 2 * .pi }
                                totalRotation += delta
                                onScroll(delta)
                            }
                            lastAngle = angle
                            pressedRegion = nil
                        } else {
                            // Center
                            pressedRegion = .center
                        }
                    }
                    .onEnded { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let dist = sqrt(dx * dx + dy * dy)

                        let moved = startLocation.map {
                            sqrt(pow(value.location.x - $0.x, 2) + pow(value.location.y - $0.y, 2))
                        } ?? 0

                        // Fire button action only if it was a tap (not a drag scroll)
                        if moved < 14 && abs(totalRotation) < 0.12 {
                            if dist <= innerR {
                                onCenter()
                            } else if dist <= outerR {
                                let angle = atan2(dy, dx) * 180 / .pi
                                let norm = angle < 0 ? angle + 360 : angle
                                if norm >= 315 || norm < 45 {
                                    onMenu()
                                } else if norm >= 45 && norm < 135 {
                                    onNext()
                                } else if norm >= 135 && norm < 225 {
                                    onPlayPause()
                                } else {
                                    onPrevious()
                                }
                            }
                        }

                        lastAngle = nil
                        startLocation = nil
                        totalRotation = 0
                        withAnimation(.easeOut(duration: 0.12)) { pressedRegion = nil }
                    }
            )
        }
    }

    private func regionFor(angle: Double) -> WheelRegion {
        let norm = angle < 0 ? angle + 360 : angle
        if norm >= 315 || norm < 45 { return .top }
        if norm >= 45 && norm < 135 { return .right }
        if norm >= 135 && norm < 225 { return .bottom }
        return .left
    }
}
