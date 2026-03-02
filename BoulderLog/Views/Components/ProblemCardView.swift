import SwiftUI

struct ProblemCard2DView: View {
    let holds: [HoldEntity]
    let onTapHold: (HoldEntity) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))

                ForEach(holds) { hold in
                    Circle()
                        .fill(color(for: hold.role).opacity(0.22))
                        .overlay(Circle().stroke(color(for: hold.role), lineWidth: 2))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if let idx = hold.orderIndex {
                                Text("\(idx)").font(.system(size: 9, weight: .bold))
                            }
                        }
                        .position(
                            x: geo.size.width * hold.xNormalized,
                            y: geo.size.height * hold.yNormalized
                        )
                        .onTapGesture {
                            onTapHold(hold)
                        }
                }
            }
        }
        .frame(height: 220)
    }

    private func color(for role: HoldRole) -> Color {
        switch role {
        case .normal: return .blue
        case .start: return .green
        case .finish: return .red
        }
    }
}
