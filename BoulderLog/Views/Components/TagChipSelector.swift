import SwiftUI

struct TagChipSelector<T: CaseIterable & Hashable & Identifiable>: View where T.AllCases: RandomAccessCollection, T: RawRepresentable, T.RawValue == String {
    let title: String
    @Binding var selected: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(T.allCases), id: \.id) { tag in
                        let isSelected = selected.contains(tag)
                        Button(label(tag)) {
                            if isSelected {
                                selected.removeAll { $0 == tag }
                            } else {
                                selected.append(tag)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isSelected ? .blue : .gray)
                    }
                }
            }
        }
    }
}
