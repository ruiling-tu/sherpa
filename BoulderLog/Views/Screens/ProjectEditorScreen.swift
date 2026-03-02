import SwiftUI
import SwiftData

struct NewProjectWizardScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let session: SessionEntity

    @StateObject private var vm = NewProjectWizardViewModel()
    @State private var showCamera = false
    @AppStorage(AICardSettings.modelKey) private var selectedPreviewModel = AICardSettings.defaultModel
    @State private var previewRefreshToken = 0

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    VStack(alignment: .leading, spacing: DojoSpace.xs) {
                        Text(vm.step.title)
                            .font(DojoType.title)
                        Text("Step \(vm.step.rawValue + 1) of \(NewProjectWizardViewModel.Step.allCases.count)")
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
                VStack(spacing: DojoSpace.md) {
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

                    DojoSurface(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: DojoSpace.sm) {
                            HStack {
                                Toggle("Annotate holds", isOn: $vm.annotateMode)
                                    .tint(DojoTheme.accentPrimary)
                                    .font(DojoType.body)
                                Spacer()
                                Button("Clear") {
                                    vm.clearAnnotations()
                                }
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                            }

                            Text("When annotation is on, tap holds to set sequence order for route guidance.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }

                    DojoSurface(cornerRadius: 14) {
                        if let binding = vm.selectedHoldBinding() {
                            HoldDraftEditor(hold: binding)
                        } else {
                            Text("Tap a hold to edit role, type, and note.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        case .preview:
            if let image = vm.croppedImage {
                DojoSurface {
                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        DojoSectionHeader(title: "2D Problem Card Preview", subtitle: "Generate before filling metadata")

                        HStack(spacing: DojoSpace.sm) {
                            Menu {
                                ForEach(AICardSettings.modelPresets, id: \.id) { option in
                                    Button(selectedPreviewModel == option.id ? "\(option.title) ✓" : option.title) {
                                        selectedPreviewModel = option.id
                                        previewRefreshToken += 1
                                    }
                                }
                            } label: {
                                Text("Model: \(AICardSettings.title(for: selectedPreviewModel))")
                                    .font(DojoType.caption)
                                    .padding(.horizontal, DojoSpace.sm)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.75))
                                            .overlay(Capsule(style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
                                    )
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button("Regenerate") {
                                previewRefreshToken += 1
                            }
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.accentPrimary)
                        }

                        DraftProblemCardPreview(
                            image: image,
                            grade: vm.draft.grade,
                            holds: vm.draft.holds,
                            refreshToken: previewRefreshToken
                        )
                        .frame(height: 240)
                    }
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

private struct DraftProblemCardPreview: View {
    let image: UIImage
    let grade: String
    let holds: [HoldDraft]
    let refreshToken: Int

    private static let previewEntryID = UUID(uuidString: "00000000-0000-0000-0000-00000000D031")!

    var body: some View {
        ProblemCard2DView(
            entryID: Self.previewEntryID,
            holds: transientHolds,
            sourceImage: image,
            grade: grade,
            refreshTrigger: refreshToken,
            onTapHold: { _ in }
        )
    }

    private var transientHolds: [HoldEntity] {
        holds.map {
            HoldEntity(
                id: $0.id,
                xNormalized: $0.xNormalized,
                yNormalized: $0.yNormalized,
                radius: $0.radius,
                role: $0.role,
                orderIndex: $0.orderIndex,
                note: $0.note,
                holdType: $0.holdType
            )
        }
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
