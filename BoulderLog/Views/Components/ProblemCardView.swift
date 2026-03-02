import SwiftUI

struct ProblemCard2DView: View {
    let holds: [HoldEntity]
    let onTapHold: (HoldEntity) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )

                ForEach(holds) { hold in
                    DojoHoldMarker(
                        role: hold.role,
                        diameter: 18,
                        orderText: hold.orderIndex.map(String.init)
                    )
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
}
