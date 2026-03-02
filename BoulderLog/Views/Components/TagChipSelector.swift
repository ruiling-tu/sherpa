import SwiftUI

struct TagChipSelector<T: CaseIterable & Hashable & Identifiable>: View where T.AllCases: RandomAccessCollection, T: RawRepresentable, T.RawValue == String {
    let title: String
    @Binding var selected: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.sm) {
            Text(title)
                .font(DojoType.section)
                .foregroundStyle(DojoTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DojoSpace.sm) {
                    ForEach(Array(T.allCases), id: \.id) { tag in
                        DojoTagChip(title: label(tag), selected: selected.contains(tag)) {
                            toggle(tag)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func toggle(_ tag: T) {
        if selected.contains(tag) {
            selected.removeAll { $0 == tag }
        } else {
            selected.append(tag)
        }
    }
}
