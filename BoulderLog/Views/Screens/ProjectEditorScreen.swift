import SwiftUI
import SwiftData

struct NewProjectWizardScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let session: SessionEntity

    @StateObject private var vm = NewProjectWizardViewModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(vm.step.title).font(.headline)
                stepView
                footer
            }
            .padding()
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView { data in
                    vm.sourceImageData = data
                }
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch vm.step {
        case .photo:
            VStack(spacing: 16) {
                if let source = vm.sourceImage {
                    Image(uiImage: source)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 220)
                        .overlay { Text("Select a wall photo") }
                }

                HStack {
                    PhotoImportButton { data in vm.sourceImageData = data }
                    Button("Capture Camera", systemImage: "camera") {
                        showCamera = true
                    }
                }
            }
        case .crop:
            if let image = vm.sourceImage {
                CropStepView(image: image, normalizedRect: $vm.cropRectNormalized)
                    .onChange(of: vm.cropRectNormalized) { _, _ in
                        vm.applyCrop()
                    }
                    .onAppear { vm.applyCrop() }
            }
        case .holds:
            if let image = vm.croppedImage {
                VStack(spacing: 10) {
                    Toggle("Ordering mode", isOn: $vm.orderingMode)

                    HoldEditorCanvas(
                        image: image,
                        holds: $vm.draft.holds,
                        selectedHoldID: $vm.selectedHoldID,
                        onTapImage: { point in vm.addHold(at: point) },
                        onTapHold: { id in vm.selectOrAssignOrder(holdID: id) },
                        onLongPressHold: { id in vm.deleteHold(id: id) }
                    )
                    .frame(maxHeight: 430)

                    if let binding = vm.selectedHoldBinding() {
                        HoldDraftEditor(hold: binding)
                    }
                }
            }
        case .metadata:
            Form {
                TextField("Name", text: $vm.draft.name)

                Picker("Grade", selection: $vm.draft.grade) {
                    ForEach(GradeScale.presets, id: \.self) { grade in
                        Text(grade).tag(grade)
                    }
                }
                TextField("Custom grade", text: $vm.draft.grade)

                Picker("Status", selection: $vm.draft.status) {
                    ForEach(EntryStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }

                Stepper("Attempts: \(vm.draft.attempts)", value: $vm.draft.attempts, in: 1...99)

                Picker("Wall Angle", selection: $vm.draft.wallAngle) {
                    ForEach(WallAngle.allCases) { angle in
                        Text(angle.title).tag(angle)
                    }
                }

                TagChipSelector(title: "Style", selected: $vm.draft.styleTags, label: { $0.title })
                TagChipSelector(title: "Hold Type", selected: $vm.draft.holdTypeTags, label: { $0.title })
                TagChipSelector(title: "Technique", selected: $vm.draft.techniqueTags, label: { $0.title })

                TextField("Gym", text: $vm.draft.gym)
                TextField("Notes", text: $vm.draft.notes, axis: .vertical)
                    .lineLimit(4...8)
            }
        case .save:
            VStack(alignment: .leading, spacing: 12) {
                Text("Review")
                    .font(.headline)
                Text("Name: \(vm.draft.name.isEmpty ? "Untitled" : vm.draft.name)")
                Text("Grade: \(vm.draft.grade)")
                Text("Status: \(vm.draft.status.title)")
                Text("Holds: \(vm.draft.holds.count)")
                Text("Attempts: \(vm.draft.attempts)")

                if let image = vm.croppedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Save Project") {
                    saveProject()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            if vm.step != .photo {
                Button("Back") { vm.goBack() }
            }
            Spacer()
            if vm.step != .save {
                Button("Next") { vm.goNext() }
                    .disabled(!vm.canProceed())
            }
        }
    }

    private func saveProject() {
        let repo = ProjectRepository(context: context)
        try? repo.createEntry(in: session, draft: vm.draft)
        dismiss()
    }
}

private struct CropStepView: View {
    let image: UIImage
    @Binding var normalizedRect: CGRect
    @State private var dragStartRect: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let imageRect = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)
            let cropViewRect = CGRect(
                x: imageRect.minX + normalizedRect.minX * imageRect.width,
                y: imageRect.minY + normalizedRect.minY * imageRect.height,
                width: normalizedRect.width * imageRect.width,
                height: normalizedRect.height * imageRect.height
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                Rectangle()
                    .path(in: cropViewRect)
                    .stroke(Color.yellow, lineWidth: 3)
                    .background(Rectangle().path(in: cropViewRect).fill(Color.yellow.opacity(0.15)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartRect == .zero { dragStartRect = normalizedRect }
                                let dx = value.translation.width / imageRect.width
                                let dy = value.translation.height / imageRect.height
                                normalizedRect.origin.x = min(max(0, dragStartRect.origin.x + dx), 1 - normalizedRect.width)
                                normalizedRect.origin.y = min(max(0, dragStartRect.origin.y + dy), 1 - normalizedRect.height)
                            }
                            .onEnded { _ in dragStartRect = .zero }
                    )

                VStack {
                    Spacer()
                    VStack {
                        Text("Resize")
                        HStack {
                            Text("W")
                            Slider(value: Binding(get: { normalizedRect.width }, set: { normalizedRect.size.width = min(max(0.2, $0), 1) }), in: 0.2...1)
                        }
                        HStack {
                            Text("H")
                            Slider(value: Binding(get: { normalizedRect.height }, set: { normalizedRect.size.height = min(max(0.2, $0), 1) }), in: 0.2...1)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
