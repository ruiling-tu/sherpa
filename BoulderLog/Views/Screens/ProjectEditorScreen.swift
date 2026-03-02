import SwiftUI
import SwiftData

struct NewProjectWizardScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let session: SessionEntity

    @StateObject private var vm = NewProjectWizardViewModel()
    @State private var showCamera = false
    @State private var orderingPanelOffset: CGSize = .zero
    @State private var orderingPanelCollapsed = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    VStack(alignment: .leading, spacing: DojoSpace.xs) {
                        Text(vm.step.title)
                            .font(DojoType.title)
                        Text("Step \(vm.step.rawValue + 1) of 5")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    stepView
                        .frame(maxHeight: .infinity)

                    if vm.step != .photo {
                        DojoButtonSecondary(title: "Back") { vm.goBack() }
                    }

                    DojoButtonPrimary(
                        title: vm.step == .save ? "Save Project" : "Continue",
                        disabled: !vm.canProceed()
                    ) {
                        if vm.step == .save {
                            saveProject()
                        } else {
                            vm.goNext()
                        }
                    }
                }
                .padding(.vertical, DojoSpace.lg)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(DojoTheme.textSecondary)
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
            DojoSurface {
                VStack(spacing: DojoSpace.lg) {
                    if let source = vm.sourceImage {
                        Image(uiImage: source)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        DojoEmptyState(title: "Select a wall photo", subtitle: "Capture with camera or import from Photos.", icon: "photo")
                    }

                    HStack(spacing: DojoSpace.md) {
                        PhotoImportButton { data in vm.sourceImageData = data }
                            .tint(DojoTheme.accentSecondary)
                        Button {
                            showCamera = true
                        } label: {
                            Label("Capture", systemImage: "camera")
                                .font(DojoType.body)
                        }
                        .foregroundStyle(DojoTheme.textPrimary)
                    }
                }
            }
        case .crop:
            if let image = vm.sourceImage {
                DojoSurface {
                    CropStepView(image: image, normalizedRect: $vm.cropRectNormalized)
                        .frame(maxHeight: 520)
                        .onChange(of: vm.cropRectNormalized) { _, _ in
                            vm.applyCrop()
                        }
                        .onAppear { vm.applyCrop() }
                }
            }
        case .holds:
            if let image = vm.croppedImage {
                ZStack(alignment: .bottomTrailing) {
                    DojoSurface {
                        HoldEditorCanvas(
                            image: image,
                            holds: $vm.draft.holds,
                            selectedHoldID: $vm.selectedHoldID,
                            onTapImage: { point in vm.addHold(at: point) },
                            onTapHold: { id in vm.selectOrAssignOrder(holdID: id) },
                            onLongPressHold: { id in vm.deleteHold(id: id) }
                        )
                        .frame(maxHeight: 500)
                    }

                    OrderingFloatingPanel(
                        orderingMode: $vm.orderingMode,
                        collapsed: $orderingPanelCollapsed,
                        offset: $orderingPanelOffset
                    ) {
                        if let binding = vm.selectedHoldBinding() {
                            HoldDraftEditor(hold: binding)
                        } else {
                            Text("Tap a hold to edit role, type, and note.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }
                    .padding(.trailing, DojoSpace.md)
                    .padding(.bottom, DojoSpace.md)
                }
            }
        case .metadata:
            DojoSurface {
                ScrollView {
                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        TextField("Project name", text: $vm.draft.name)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: DojoSpace.md) {
                            Picker("Grade", selection: $vm.draft.grade) {
                                ForEach(GradeScale.presets, id: \.self) { grade in
                                    Text(grade).tag(grade)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("Custom", text: $vm.draft.grade)
                                .textFieldStyle(.roundedBorder)
                        }

                        Picker("Status", selection: $vm.draft.status) {
                            ForEach(EntryStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper("Attempts: \(vm.draft.attempts)", value: $vm.draft.attempts, in: 1...99)

                        Picker("Wall Angle", selection: $vm.draft.wallAngle) {
                            ForEach(WallAngle.allCases) { angle in
                                Text(angle.title).tag(angle)
                            }
                        }
                        .pickerStyle(.segmented)

                        TagChipSelector(title: "Style", selected: $vm.draft.styleTags, label: { $0.title })
                        TagChipSelector(title: "Hold Type", selected: $vm.draft.holdTypeTags, label: { $0.title })
                        TagChipSelector(title: "Technique", selected: $vm.draft.techniqueTags, label: { $0.title })

                        TextField("Gym", text: $vm.draft.gym)
                            .textFieldStyle(.roundedBorder)

                        TextField("Notes", text: $vm.draft.notes, axis: .vertical)
                            .lineLimit(4...8)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        case .save:
            DojoSurface {
                VStack(alignment: .leading, spacing: DojoSpace.md) {
                    DojoSectionHeader(title: "Review")
                    Text("Name: \(vm.draft.name.isEmpty ? "Untitled" : vm.draft.name)")
                        .font(DojoType.body)
                    Text("Grade: \(vm.draft.grade)")
                        .font(DojoType.body)
                    Text("Status: \(vm.draft.status.title)")
                        .font(DojoType.body)
                    Text("Holds: \(vm.draft.holds.count)")
                        .font(DojoType.body)
                    Text("Attempts: \(vm.draft.attempts)")
                        .font(DojoType.body)

                    if let image = vm.croppedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func saveProject() {
        let repo = ProjectRepository(context: context)
        try? repo.createEntry(in: session, draft: vm.draft)
        dismiss()
    }
}

private struct OrderingFloatingPanel<Content: View>: View {
    @Binding var orderingMode: Bool
    @Binding var collapsed: Bool
    @Binding var offset: CGSize
    @ViewBuilder let content: () -> Content
    @State private var dragStartOffset: CGSize = .zero
    @State private var dragInitialized = false

    var body: some View {
        Group {
            if collapsed {
                DojoSurface(cornerRadius: 14) {
                    HStack(spacing: DojoSpace.sm) {
                        Text(orderingMode ? "Ordering On" : "Ordering Off")
                            .font(DojoType.caption)
                        Button {
                            collapsed = false
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                    }
                }
                .frame(width: 164)
            } else {
                DojoSurface(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: DojoSpace.sm) {
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(DojoTheme.textSecondary)
                            Text("Hold Controls")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                            Spacer()
                            Button {
                                collapsed = true
                            } label: {
                                Image(systemName: "minus")
                                    .foregroundStyle(DojoTheme.textSecondary)
                            }
                        }
                        Toggle("Ordering mode", isOn: $orderingMode)
                            .tint(DojoTheme.accentPrimary)
                            .font(DojoType.body)
                        content()
                    }
                }
                .frame(maxWidth: 320)
            }
        }
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !dragInitialized {
                        dragStartOffset = offset
                        dragInitialized = true
                    }
                    offset = CGSize(
                        width: dragStartOffset.width + value.translation.width,
                        height: dragStartOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    dragInitialized = false
                }
        )
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
                    .stroke(DojoTheme.accentPrimary, lineWidth: 2)
                    .background(Rectangle().path(in: cropViewRect).fill(DojoTheme.accentPrimary.opacity(0.16)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartRect == .zero { dragStartRect = normalizedRect }
                                let dx = value.translation.width / imageRect.width
                                let dy = value.translation.height / imageRect.height
                                normalizedRect.origin.x = min(max(0, dragStartRect.origin.x + dx), 1 - normalizedRect.width)
                                normalizedRect.origin.y = min(max(0, dragStartRect.origin.y + dy), 1 - normalizedRect.height)
                            }
                            .onEnded { _ in
                                dragStartRect = .zero
                            }
                    )

                VStack {
                    Spacer()
                    DojoSurface(cornerRadius: 14) {
                        VStack(spacing: DojoSpace.sm) {
                            HStack {
                                Text("Width")
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                                Slider(
                                    value: Binding(
                                        get: { normalizedRect.width },
                                        set: { normalizedRect.size.width = min(max(0.2, $0), 1) }
                                    ),
                                    in: 0.2...1
                                )
                                .tint(DojoTheme.accentPrimary)
                            }

                            HStack {
                                Text("Height")
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                                Slider(
                                    value: Binding(
                                        get: { normalizedRect.height },
                                        set: { normalizedRect.size.height = min(max(0.2, $0), 1) }
                                    ),
                                    in: 0.2...1
                                )
                                .tint(DojoTheme.accentPrimary)
                            }
                        }
                    }
                    .padding(.bottom, DojoSpace.sm)
                }
            }
        }
    }
}
