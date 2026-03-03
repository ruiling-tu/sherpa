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
    @State private var showHoldsHelp = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    HStack(alignment: .top, spacing: DojoSpace.md) {
                        VStack(alignment: .leading, spacing: DojoSpace.xs) {
                            Text(vm.step.title)
                                .font(DojoType.title)
                            Text("Step \(vm.step.rawValue + 1) of \(NewProjectWizardViewModel.Step.allCases.count)")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }

                        Spacer()

                        if vm.step == .holds {
                            Button {
                                showHoldsHelp = true
                            } label: {
                                Label("Help", systemImage: "questionmark.circle")
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.accentPrimary)
                                    .padding(.horizontal, DojoSpace.sm)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.white.opacity(0.75))
                                            .overlay(Capsule(style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
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
            .alert("Annotate Holds Guide", isPresented: $showHoldsHelp) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Turn on Annotate holds, then tap inside the photo to add markers. Drag markers to move them, long-press to delete, and choose start/finish roles in the editor.")
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
                VStack(alignment: .leading, spacing: DojoSpace.sm) {
                    DojoSurface {
                        CropStepView(image: image, normalizedRect: $vm.cropRectNormalized)
                            .frame(maxHeight: 520)
                            .onChange(of: vm.cropRectNormalized) { _, _ in
                                vm.applyCrop()
                            }
                            .onAppear { vm.applyCrop() }
                    }
                    HStack(spacing: DojoSpace.sm) {
                        Text("Drag the crop box or its corners. Drag outside the box to create a new crop.")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                        Spacer()
                        Button("Reset") {
                            vm.cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                            vm.applyCrop()
                        }
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.accentPrimary)
                    }
                }
            }
        case .holds:
            if let image = vm.croppedImage {
                VStack(spacing: DojoSpace.md) {
                    DojoSurface(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: DojoSpace.sm) {
                            HStack(spacing: DojoSpace.sm) {
                                Toggle("Annotate holds", isOn: $vm.annotateMode)
                                    .tint(DojoTheme.accentPrimary)
                                    .font(DojoType.body)

                                Spacer(minLength: DojoSpace.sm)

                                Menu {
                                    ForEach(GradeScale.presets, id: \.self) { grade in
                                        Button(vm.draft.grade == grade ? "\(grade) ✓" : grade) {
                                            vm.draft.grade = grade
                                        }
                                    }
                                } label: {
                                    Text("Grade \(vm.draft.grade)")
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

                                if vm.annotateMode {
                                    Button("Clear All") {
                                        vm.clearHolds()
                                    }
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                                    .disabled(vm.draft.holds.isEmpty)
                                }
                            }

                            Text(vm.annotateMode ? "Tap to add holds. Drag to move. Long-press a marker to delete." : "Turn on Annotate holds to place route markers.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }

                    ScrollView {
                        VStack(spacing: DojoSpace.md) {
                            DojoSurface {
                                HoldEditorCanvas(
                                    image: image,
                                    holds: $vm.draft.holds,
                                    selectedHoldID: $vm.selectedHoldID,
                                    annotationEnabled: vm.annotateMode,
                                    onTapImage: { point in vm.addHold(at: point) },
                                    onTapHold: { id in vm.selectOrAssignOrder(holdID: id) },
                                    onLongPressHold: { id in vm.deleteHold(id: id) }
                                )
                                .frame(height: 620)
                            }

                            if vm.annotateMode, let binding = vm.selectedHoldBinding() {
                                DojoSurface(cornerRadius: 14) {
                                    HoldDraftEditor(hold: binding)
                                }
                            }
                        }
                    }
                }
            }
        case .preview:
            if let image = vm.croppedImage {
                DojoSurface {
                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        DojoSectionHeader(title: "2D Problem Card Preview", subtitle: "Uses annotated holds and selected grade for generation")

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
                        .frame(maxWidth: .infinity)
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        .frame(maxHeight: 420)
                    }
                }
            }
        case .metadata:
            DojoSurface {
                ScrollView {
                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        TextField("Project name", text: $vm.draft.name)
                            .textFieldStyle(.roundedBorder)

                        Text("Grade from Step 3: \(vm.draft.grade)")
                            .font(DojoType.body)
                            .foregroundStyle(DojoTheme.textSecondary)

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
                VStack(alignment: .leading, spacing: DojoSpace.lg) {
                    DojoSectionHeader(title: "Review")

                    ReviewSummaryGrid(draft: vm.draft)

                    if let image = vm.croppedImage {
                        ReviewCardMediaSection(sourceImage: image, generatedImage: generatedPreviewImage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var generatedPreviewImage: UIImage? {
        let holds = HoldRenderSpec.fromDrafts(vm.draft.holds)
        let signature = ProblemCardPromptFactory.cacheSignature(
            grade: vm.draft.grade,
            holds: holds,
            model: selectedPreviewModel
        )
        return ProblemCardImageStore.load(entryID: ProblemCardImageStore.previewDraftEntryID, signature: signature)
    }

    private func saveProject() {
        let repo = ProjectRepository(context: context)
        try? repo.createEntry(in: session, draft: vm.draft)
        dismiss()
    }
}

private struct ReviewCardMediaSection: View {
    let sourceImage: UIImage
    let generatedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.md) {
            DojoSectionHeader(title: "Images")

            HStack(alignment: .top, spacing: DojoSpace.md) {
                mediaCard(title: "Original", image: sourceImage)
                if let generatedImage {
                    mediaCard(title: "2D Problem Card", image: generatedImage)
                } else {
                    pendingCard(title: "2D Problem Card")
                }
            }
        }
    }

    private func mediaCard(title: String, image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .topLeading)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(2 / 3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .frame(height: 248)
    }

    private func pendingCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .topLeading)

            VStack(spacing: DojoSpace.xs) {
                ProgressView()
                    .tint(DojoTheme.accentPrimary)
                Text("Preview not ready")
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .frame(height: 248)
    }
}

private struct ReviewSummaryGrid: View {
    let draft: EntryDraft

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DojoSpace.sm), GridItem(.flexible(), spacing: DojoSpace.sm)], spacing: DojoSpace.sm) {
            summaryCard(title: "Name", value: draft.name.isEmpty ? "Untitled" : draft.name)
            summaryCard(title: "Grade", value: draft.grade)
            summaryCard(title: "Status", value: draft.status.title)
            summaryCard(title: "Wall", value: draft.wallAngle.title)
            summaryCard(title: "Holds", value: "\(draft.holds.count)")
            summaryCard(title: "Attempts", value: "\(draft.attempts)")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(value)
                .font(DojoType.body)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
        )
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
    @State private var newSelectionStart: CGPoint?
    @State private var activeHandle: CropHandle?

    private let minCropSize: CGFloat = 0.18

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

                CropDimmedOverlay(cutoutRect: cropViewRect)
                    .fill(Color.black.opacity(0.24), style: FillStyle(eoFill: true))
                    .frame(width: geo.size.width, height: geo.size.height)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DojoTheme.accentPrimary, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DojoTheme.accentPrimary.opacity(0.14))
                    )
                    .frame(width: cropViewRect.width, height: cropViewRect.height)
                    .position(x: cropViewRect.midX, y: cropViewRect.midY)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard imageRect.width > 0, imageRect.height > 0 else { return }
                                if dragStartRect == .zero { dragStartRect = normalizedRect }
                                let dx = value.translation.width / imageRect.width
                                let dy = value.translation.height / imageRect.height
                                var next = dragStartRect
                                next.origin.x = dragStartRect.origin.x + dx
                                next.origin.y = dragStartRect.origin.y + dy
                                normalizedRect = clampNormalizedRect(next)
                            }
                            .onEnded { _ in
                                dragStartRect = .zero
                            }
                    )

                ForEach(CropHandle.allCases, id: \.self) { handle in
                    let point = handle.point(in: cropViewRect)
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(DojoTheme.accentPrimary, lineWidth: 2)
                        )
                        .position(point)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard imageRect.width > 0, imageRect.height > 0 else { return }
                                    if dragStartRect == .zero {
                                        dragStartRect = normalizedRect
                                        activeHandle = handle
                                    }
                                    let dx = value.translation.width / imageRect.width
                                    let dy = value.translation.height / imageRect.height
                                    normalizedRect = clampNormalizedRect(resizedRect(from: dragStartRect, handle: handle, dx: dx, dy: dy))
                                }
                                .onEnded { _ in
                                    dragStartRect = .zero
                                    activeHandle = nil
                                }
                        )
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard imageRect.contains(value.startLocation),
                              imageRect.contains(value.location),
                              !cropViewRect.contains(value.startLocation),
                              activeHandle == nil else { return }

                        if newSelectionStart == nil {
                            newSelectionStart = value.startLocation
                        }
                        guard let start = newSelectionStart else { return }
                        let rect = CGRect(
                            x: min(start.x, value.location.x),
                            y: min(start.y, value.location.y),
                            width: abs(value.location.x - start.x),
                            height: abs(value.location.y - start.y)
                        )
                        let normalized = normalizedRectFromViewRect(rect, imageRect: imageRect)
                        if normalized.width > 0.03, normalized.height > 0.03 {
                            normalizedRect = clampNormalizedRect(normalized)
                        }
                    }
                    .onEnded { _ in
                        newSelectionStart = nil
                    }
            )
        }
    }

    private func normalizedRectFromViewRect(_ viewRect: CGRect, imageRect: CGRect) -> CGRect {
        guard imageRect.width > 0, imageRect.height > 0 else { return normalizedRect }
        return CGRect(
            x: (viewRect.minX - imageRect.minX) / imageRect.width,
            y: (viewRect.minY - imageRect.minY) / imageRect.height,
            width: viewRect.width / imageRect.width,
            height: viewRect.height / imageRect.height
        )
    }

    private func clampNormalizedRect(_ rect: CGRect) -> CGRect {
        var next = rect.standardized
        next.origin.x = min(max(0, next.origin.x), 1)
        next.origin.y = min(max(0, next.origin.y), 1)
        next.size.width = min(max(minCropSize, next.width), 1 - next.origin.x)
        next.size.height = min(max(minCropSize, next.height), 1 - next.origin.y)
        return next
    }

    private func resizedRect(from start: CGRect, handle: CropHandle, dx: CGFloat, dy: CGFloat) -> CGRect {
        var next = start
        switch handle {
        case .topLeading:
            next.origin.x = start.origin.x + dx
            next.origin.y = start.origin.y + dy
            next.size.width = start.size.width - dx
            next.size.height = start.size.height - dy
        case .topTrailing:
            next.origin.y = start.origin.y + dy
            next.size.width = start.size.width + dx
            next.size.height = start.size.height - dy
        case .bottomLeading:
            next.origin.x = start.origin.x + dx
            next.size.width = start.size.width - dx
            next.size.height = start.size.height + dy
        case .bottomTrailing:
            next.size.width = start.size.width + dx
            next.size.height = start.size.height + dy
        }
        return next
    }
}

private enum CropHandle: CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeading: return CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

private struct CropDimmedOverlay: Shape {
    let cutoutRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: cutoutRect, cornerSize: CGSize(width: 8, height: 8))
        return path
    }
}
