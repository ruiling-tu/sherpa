import SwiftUI

struct HoldDraftEditor: View {
    @Binding var hold: HoldDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.sm) {
            Text("Detected confidence: \(Int(hold.confidence * 100))%")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)

            Picker("Role", selection: $hold.role) {
                ForEach(HoldRole.allCases) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.segmented)

            Picker("Hold Type", selection: $hold.holdType) {
                ForEach(HoldTypeTag.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            HStack(spacing: DojoSpace.md) {
                Text("Width \(Int(hold.widthNormalized * 100))%")
                Text("Height \(Int(hold.heightNormalized * 100))%")
            }
            .font(DojoType.caption)
            .foregroundStyle(DojoTheme.textSecondary)

            TextField("Hold note", text: $hold.note)
                .textFieldStyle(.roundedBorder)
        }
    }
}
