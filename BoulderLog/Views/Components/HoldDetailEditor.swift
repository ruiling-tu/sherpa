import SwiftUI

struct HoldDraftEditor: View {
    @Binding var hold: HoldDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            Slider(value: $hold.radius, in: 0.02...0.1) {
                Text("Size")
            }

            TextField("Hold note", text: $hold.note)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
