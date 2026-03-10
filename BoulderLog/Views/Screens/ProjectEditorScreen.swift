import SwiftData
import SwiftUI

struct NewProjectWizardScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let session: SessionEntity

    @StateObject private var vm = NewProjectWizardViewModel()
    @State private var showCamera = false
    @State private var showHoldsHelp = false
    @State private var showOptionalDetails = false
    @State private var exportFile: ExportedRouteFile?
    @State private var contourEditorTarget: HoldContourEditorTarget?

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    header
                    stepView
                        .frame(maxHeight: .infinity)
                }
                .padding(.vertical, DojoSpace.lg)
            }
            .safeAreaInset(edge: .bottom) {
                wizardActions
                    .padding(.horizontal, 22)
                    .padding(.top, DojoSpace.sm)
                    .padding(.bottom, DojoSpace.md)
                    .background(
                        LinearGradient(
                            colors: [DojoTheme.background.opacity(0), DojoTheme.background.opacity(0.88), DojoTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if vm.step != .photo {
                        Button("Back") { vm.goBack() }
                            .foregroundStyle(DojoTheme.textSecondary)
                    } else {
                        Button("Close") { dismiss() }
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.step != .photo {
                        Button("Close") { dismiss() }
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView { data in
                    vm.sourceImageData = data
                }
            }
            .sheet(item: $exportFile) { item in
                ActivityShareSheet(items: [item.url])
            }
            .fullScreenCover(item: $contourEditorTarget) { target in
                HoldContourEditorScreen(
                    image: target.image,
                    routeColor: vm.draft.routeColor,
                    title: target.title,
                    subtitle: target.subtitle,
                    initialContour: target.initialContour,
                    focusPoint: target.focusPoint
                ) { points in
                    if let holdID = target.holdID {
                        vm.updateHoldContour(id: holdID, contourPoints: points)
                        vm.selectedHoldID = holdID
                    } else {
                        vm.addHold(contourPoints: points)
                    }
                    contourEditorTarget = nil
                } onCancel: {
                    contourEditorTarget = nil
                }
            }
            .alert("Route Extraction Guide", isPresented: $showHoldsHelp) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Pick the route color and grade, run extraction, then drag holds or wall corners until the geometry looks right. Use Add Hold for missed holds, or tap a detected hold to redraw it in the zoomed contour editor. Hold notes are added in the final blueprint step.")
            }
        }
    }

    private var wizardActions: some View {
        VStack(spacing: DojoSpace.sm) {
            if vm.step != .photo {
                DojoButtonSecondary(title: "Back") { vm.goBack() }
            }

            DojoButtonPrimary(
                title: vm.step == .finish ? "Save Project" : "Continue",
                disabled: !vm.canProceed()
            ) {
                if vm.step == .finish {
                    saveProject()
                } else {
                    vm.goNext()
                }
            }
        }
    }

    private var header: some View {
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
    }

    @ViewBuilder
    private var stepView: some View {
        switch vm.step {
        case .photo:
            photoStep
        case .crop:
            cropStep
        case .holds:
            holdsStep
        case .finish:
            finishStep
        }
    }

    private var photoStep: some View {
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
    }

    @ViewBuilder
    private var cropStep: some View {
        if let image = vm.sourceImage {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                DojoSurface {
                    CropStepView(image: image, normalizedRect: $vm.cropRectNormalized) {
                        vm.applyCrop(resetGeometry: true)
                    }
                        .frame(maxHeight: 520)
                        .onAppear {
                            vm.applyCrop(resetGeometry: true)
                        }
                }
                HStack(spacing: DojoSpace.sm) {
                    Text("Crop tightly around the wall section. That gives the detector a cleaner wall boundary to work from.")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                    Spacer()
                    Button("Reset") {
                        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.84)) {
                            vm.cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
                        }
                        vm.applyCrop(resetGeometry: true)
                    }
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.accentPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var holdsStep: some View {
        if let image = vm.croppedImage {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DojoSpace.md) {
                    DojoSurface(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: DojoSpace.md) {
                            HStack(alignment: .top, spacing: DojoSpace.sm) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Route Setup")
                                        .font(DojoType.body.weight(.semibold))
                                    Text("Tune extraction, then correct the geometry.")
                                        .font(DojoType.caption)
                                        .foregroundStyle(DojoTheme.textSecondary)
                                }
                                Spacer()
                                if vm.routeColorCalibration != nil {
                                    statusPill(title: "Calibrated", tint: DojoTheme.accentSecondary, icon: "checkmark.circle.fill")
                                }
                                statusPill(title: "\(vm.draft.holds.count) holds", tint: DojoTheme.accentPrimary.opacity(0.86))
                            }

                            HStack(spacing: DojoSpace.sm) {
                                compactSelector(title: "Grade", value: vm.draft.grade, showsAccentDot: false) {
                                    ForEach(GradeScale.presets, id: \.self) { grade in
                                        Button(vm.draft.grade == grade ? "\(grade) ✓" : grade) {
                                            vm.draft.grade = grade
                                        }
                                    }
                                }

                                compactSelector(title: "Route Color", value: vm.draft.routeColor.title, accent: vm.draft.routeColor.swatch) {
                                    ForEach(RouteColor.allCases) { color in
                                        Button(vm.draft.routeColor == color ? "\(color.title) ✓" : color.title) {
                                            vm.draft.routeColor = color
                                            vm.routeColorCalibration = nil
                                            vm.isSamplingRouteColor = false
                                            vm.clearHolds()
                                            Task { await vm.detectRoute(force: true) }
                                        }
                                    }
                                }
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: DojoSpace.sm),
                                    GridItem(.flexible(), spacing: DojoSpace.sm),
                                    GridItem(.flexible(), spacing: DojoSpace.sm)
                                ],
                                spacing: DojoSpace.sm
                            ) {
                                sampleButton
                                addHoldButton(image: image)
                                extractButton
                            }

                            HStack(spacing: DojoSpace.sm) {
                                if vm.isExtractingRoute {
                                    ProgressView()
                                        .tint(DojoTheme.accentPrimary)
                                }

                                Spacer()
                            }

                            Text(vm.extractionSummary)
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }

                    DojoSurface {
                        HoldEditorCanvas(
                            image: image,
                            routeColor: vm.draft.routeColor,
                            holds: $vm.draft.holds,
                            wallOutline: $vm.draft.wallOutline,
                            selectedHoldID: $vm.selectedHoldID,
                            sampleMode: vm.isSamplingRouteColor,
                            samplePoint: vm.routeColorCalibration?.point,
                            onTapHold: { id in vm.selectOrAssignOrder(holdID: id) },
                            onTapImage: { point in
                                vm.applyRouteColorCalibration(at: point)
                                Task { await vm.detectRoute(force: true) }
                            },
                            onRequestRedrawHold: { id in
                                openContourEditor(for: id, image: image)
                            },
                            onDeleteHold: { id in vm.deleteHold(id: id) },
                            onMoveHold: { id, point in vm.moveHold(id: id, normalizedPoint: point) },
                            onMoveWallPoint: { index, point in vm.updateWallPoint(index: index, to: point) },
                            onUpdateHoldContour: { id, points in vm.updateHoldContour(id: id, contourPoints: points) }
                        )
                        .frame(height: 620)
                    }

                    Text(vm.isSamplingRouteColor
                         ? "Tap one hold from the route to calibrate the selected color."
                         : "Drag holds to reposition them. Tap a hold to redraw or delete it. Use Add Hold for any missed contour. Drag wall corners if the wall boundary is off.")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                }
                .padding(.bottom, 140)
            }
            .task(id: "\(vm.draft.routeColor.rawValue)-\(vm.croppedImageData.count)") {
                await vm.maybeAutoExtractRoute()
            }
        }
    }

    private var finishStep: some View {
        ScrollView(showsIndicators: false) {
            DojoSurface {
                VStack(alignment: .leading, spacing: DojoSpace.md) {
                    DojoSectionHeader(
                        title: "Preview and Save",
                        subtitle: "Review the route blueprint, export it as a PNG, then save the project."
                    )

                    if let image = vm.croppedImage {
                        ReviewCardMediaSection(
                            sourceImage: image,
                            draft: vm.draft,
                            selectedHoldID: $vm.selectedHoldID,
                            exportAction: exportBlueprint
                        )
                    }

                    if let holdBinding = vm.selectedHoldBinding() {
                        HoldBlueprintNoteSection(hold: holdBinding)
                    }

                    ReviewSummaryGrid(draft: vm.draft)

                    VStack(alignment: .leading, spacing: DojoSpace.xs) {
                        Text("Project name")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                        TextField("Optional name", text: $vm.draft.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    if !session.gym.isEmpty, vm.draft.gym.isEmpty {
                        Text("Uses session gym by default: \(session.gym)")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                    }

                    DisclosureGroup(isExpanded: $showOptionalDetails) {
                        VStack(alignment: .leading, spacing: DojoSpace.md) {
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

                            TextField(
                                session.gym.isEmpty ? "Gym (optional)" : "Gym override (defaults to \(session.gym))",
                                text: $vm.draft.gym
                            )
                            .textFieldStyle(.roundedBorder)

                            TextField("Notes (optional)", text: $vm.draft.notes, axis: .vertical)
                                .lineLimit(4...8)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.top, DojoSpace.sm)
                    } label: {
                        VStack(alignment: .leading, spacing: DojoSpace.xs) {
                            Text("Add more details")
                                .font(DojoType.body)
                            Text("Status, attempts, wall angle, tags, notes, or a gym override.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }
                    .tint(DojoTheme.accentPrimary)

                    ReviewMetadataSection(draft: vm.draft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 140)
        }
    }

    private func saveProject() {
        if vm.draft.gym.isEmpty {
            vm.draft.gym = session.gym
        }
        let repo = ProjectRepository(context: context)
        try? repo.createEntry(in: session, draft: vm.draft)
        dismiss()
    }

    private func exportBlueprint() {
        do {
            let url = try RouteBlueprintExportStore.exportPNG(
                holds: transientHolds,
                sourceImage: vm.croppedImage,
                wallOutline: vm.draft.wallOutline,
                grade: vm.draft.grade,
                routeColor: vm.draft.routeColor,
                wallAngle: vm.draft.wallAngle,
                name: vm.draft.name.isEmpty ? "route-blueprint" : vm.draft.name
            )
            exportFile = ExportedRouteFile(url: url)
        } catch {
            exportFile = nil
        }
    }

    private var transientHolds: [HoldEntity] {
        vm.draft.holds.map {
            HoldEntity(
                id: $0.id,
                xNormalized: $0.xNormalized,
                yNormalized: $0.yNormalized,
                radius: $0.radius,
                widthNormalized: $0.widthNormalized,
                heightNormalized: $0.heightNormalized,
                rotationRadians: $0.rotationRadians,
                role: $0.role,
                orderIndex: $0.orderIndex,
                note: $0.note,
                holdType: $0.holdType,
                contourPoints: $0.contourPoints,
                confidence: $0.confidence
            )
        }
    }

    private var extractButton: some View {
        Button {
            Task { await vm.detectRoute(force: true) }
        } label: {
            routeActionButtonBody(
                title: vm.isExtractingRoute ? "Extracting" : "Extract",
                systemImage: "viewfinder",
                fill: Color.white.opacity(0.78),
                foreground: DojoTheme.textPrimary,
                showsStroke: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Extract route again")
    }

    private var sampleButton: some View {
        Button {
            vm.beginRouteColorSampling()
        } label: {
            routeActionButtonBody(
                title: vm.isSamplingRouteColor ? "Sampling" : "Sample",
                systemImage: vm.isSamplingRouteColor ? "scope" : "eyedropper",
                fill: vm.isSamplingRouteColor ? DojoTheme.accentPrimary : Color.white.opacity(0.78),
                foreground: vm.isSamplingRouteColor ? Color.white : DojoTheme.textPrimary,
                showsStroke: !vm.isSamplingRouteColor
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sample one hold to calibrate route color")
    }

    private func addHoldButton(image: UIImage) -> some View {
        Button {
            vm.isSamplingRouteColor = false
            contourEditorTarget = HoldContourEditorTarget(
                holdID: nil,
                image: image,
                title: "Add Missing Hold",
                subtitle: "Zoom, pan, and trace a hold that the detector missed.",
                initialContour: [],
                focusPoint: vm.selectedHoldID.flatMap { id in
                    vm.draft.holds.first(where: { $0.id == id }).map {
                        CGPoint(x: $0.xNormalized, y: $0.yNormalized)
                    }
                }
            )
        } label: {
            routeActionButtonBody(
                title: "Add Hold",
                systemImage: "plus.viewfinder",
                fill: Color.white.opacity(0.78),
                foreground: DojoTheme.textPrimary,
                showsStroke: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a missing hold contour")
    }

    private func routeActionButtonBody(
        title: String,
        systemImage: String,
        fill: Color,
        foreground: Color,
        showsStroke: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: showsStroke ? 0.8 : 0)
                )
        )
    }

    private func statusPill(title: String, tint: Color, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(DojoType.caption)
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(tint)
        )
    }

    private func openContourEditor(for holdID: UUID, image: UIImage) {
        guard let hold = vm.draft.holds.first(where: { $0.id == holdID }) else { return }
        contourEditorTarget = HoldContourEditorTarget(
            holdID: holdID,
            image: image,
            title: "Refine Hold Contour",
            subtitle: "Zoom, pan, and retrace the hold outline for a cleaner contour.",
            initialContour: hold.contourPoints,
            focusPoint: CGPoint(x: hold.xNormalized, y: hold.yNormalized)
        )
    }

    private func routeSelectorCard<Items: View>(
        title: String,
        value: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            VStack(alignment: .leading, spacing: DojoSpace.xs) {
                Text(title)
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
                HStack(spacing: DojoSpace.xs) {
                    Text(value)
                        .font(DojoType.body)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DojoTheme.textSecondary)
                }
            }
            .padding(DojoSpace.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func compactSelector<Items: View>(
        title: String,
        value: String,
        accent: Color = DojoTheme.accentPrimary,
        showsAccentDot: Bool = true,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: DojoSpace.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                    Text(value)
                        .font(DojoType.body.weight(.medium))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if showsAccentDot {
                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DojoTheme.textSecondary)
            }
            .padding(.horizontal, DojoSpace.md)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DojoTheme.divider, lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewCardMediaSection: View {
    let sourceImage: UIImage
    let draft: EntryDraft
    @Binding var selectedHoldID: UUID?
    let exportAction: () -> Void
    private let cardAspectRatio: CGFloat = 2.0 / 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.md) {
            HStack {
                DojoSectionHeader(title: "Route Visuals", subtitle: "Original photo and editable route blueprint")
                Spacer()
                Button("Export PNG") {
                    exportAction()
                }
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.accentPrimary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DojoSpace.md),
                    GridItem(.flexible(), spacing: DojoSpace.md)
                ],
                spacing: DojoSpace.md
            ) {
                mediaCard(title: "Original + Geometry") {
                    AnnotatedReviewImage(image: sourceImage, draft: draft)
                }

                mediaCard(title: "Route Blueprint") {
                    DraftBlueprintPreview(
                        draft: draft,
                        sourceImage: sourceImage,
                        selectedHoldID: $selectedHoldID
                    )
                }
            }
        }
    }

    private func mediaCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .topLeading)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.48))
                content()
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DojoTheme.divider, lineWidth: 0.8)
            )
            .clipped()
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

private struct AnnotatedReviewImage: View {
    let image: UIImage
    let draft: EntryDraft

    var body: some View {
        GeometryReader { geo in
            let imageRect = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)
            let wallPoints = draft.wallOutline.map { ImageSpaceTransform.viewPoint(from: $0, imageRect: imageRect) }

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)

                Path { path in
                    guard let first = wallPoints.first else { return }
                    path.move(to: first)
                    for point in wallPoints.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                .stroke(draft.routeColor.swatch, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))

                ForEach(draft.holds) { hold in
                    let contour = hold.contourPoints.map { ImageSpaceTransform.viewPoint(from: $0, imageRect: imageRect) }
                    Path { path in
                        guard let first = contour.first else { return }
                        path.move(to: first)
                        for point in contour.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .fill(draft.routeColor.swatch.opacity(0.34))
                    .overlay {
                        Path { path in
                            guard let first = contour.first else { return }
                            path.move(to: first)
                            for point in contour.dropFirst() {
                                path.addLine(to: point)
                            }
                            path.closeSubpath()
                        }
                        .stroke(draft.routeColor.shadowSwatch, lineWidth: 1.4)
                    }
                }
            }
        }
    }
}

private struct DraftBlueprintPreview: View {
    let draft: EntryDraft
    let sourceImage: UIImage
    @Binding var selectedHoldID: UUID?

    var body: some View {
        ProblemCard2DView(
            entryID: UUID(),
            holds: transientHolds,
            sourceImage: sourceImage,
            wallOutline: draft.wallOutline,
            grade: draft.grade,
            routeColor: draft.routeColor,
            wallAngle: draft.wallAngle,
            onTapHold: { hold in
                selectedHoldID = hold.id
            }
        )
    }

    private var transientHolds: [HoldEntity] {
        draft.holds.map {
            HoldEntity(
                id: $0.id,
                xNormalized: $0.xNormalized,
                yNormalized: $0.yNormalized,
                radius: $0.radius,
                widthNormalized: $0.widthNormalized,
                heightNormalized: $0.heightNormalized,
                rotationRadians: $0.rotationRadians,
                role: $0.role,
                orderIndex: $0.orderIndex,
                note: $0.note,
                holdType: $0.holdType,
                contourPoints: $0.contourPoints,
                confidence: $0.confidence
            )
        }
    }
}

private struct HoldBlueprintNoteSection: View {
    @Binding var hold: HoldDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DojoSpace.sm) {
            DojoSectionHeader(
                title: "Hold Note",
                subtitle: "Tap a hold in the blueprint above, then add beta or grip detail for that hold."
            )

            HStack(spacing: DojoSpace.sm) {
                statChip(title: "Role", value: hold.role.title)
                statChip(title: "Confidence", value: "\(Int(hold.confidence * 100))%")
            }

            TextField("Add an optional note for this hold", text: $hold.note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
        .padding(DojoSpace.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
        )
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(value)
                .font(DojoType.body.weight(.medium))
        }
        .padding(.horizontal, DojoSpace.md)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.78))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
        )
    }
}

private struct HoldContourEditorTarget: Identifiable {
    let holdID: UUID?
    let image: UIImage
    let title: String
    let subtitle: String
    let initialContour: [CGPoint]
    let focusPoint: CGPoint?
    let id = UUID()
}

private struct HoldContourEditorScreen: View {
    enum Mode: String, CaseIterable, Identifiable {
        case navigate = "Pan & Zoom"
        case trace = "Trace"

        var id: String { rawValue }
    }

    let image: UIImage
    let routeColor: RouteColor
    let title: String
    let subtitle: String
    let initialContour: [CGPoint]
    let focusPoint: CGPoint?
    let onSave: ([CGPoint]) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .navigate
    @State private var zoom: CGFloat = 1.8
    @State private var zoomStart: CGFloat = 1.8
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var workingContour: [CGPoint]
    @State private var traceContour: [CGPoint] = []
    @State private var didInitialize = false

    init(
        image: UIImage,
        routeColor: RouteColor,
        title: String,
        subtitle: String,
        initialContour: [CGPoint],
        focusPoint: CGPoint?,
        onSave: @escaping ([CGPoint]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image = image
        self.routeColor = routeColor
        self.title = title
        self.subtitle = subtitle
        self.initialContour = initialContour
        self.focusPoint = focusPoint
        self.onSave = onSave
        self.onCancel = onCancel
        _workingContour = State(initialValue: initialContour)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let viewport = geo.size
                let baseRect = ImageSpaceTransform.fittedRect(imageSize: image.size, in: viewport)
                let imageRect = transformedRect(from: baseRect, zoom: zoom, offset: panOffset)

                ZStack(alignment: .bottom) {
                    Color(hex: "141312").ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)
                        .overlay {
                            contourPath(points: workingContour, in: imageRect)
                                .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                            contourPath(points: workingContour, in: imageRect)
                                .stroke(routeColor.swatch, style: StrokeStyle(lineWidth: 1.3, lineJoin: .round, dash: [7, 5]))

                            contourPath(points: traceContour, in: imageRect)
                                .stroke(routeColor.swatch, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        }
                        .contentShape(Rectangle())
                        .gesture(editorGesture(baseRect: baseRect, viewport: viewport, imageRect: imageRect))
                        .simultaneousGesture(magnifyGesture(baseRect: baseRect, viewport: viewport))

                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(title)
                                    .font(DojoType.section)
                                    .foregroundStyle(Color.white)
                                Text(subtitle)
                                    .font(DojoType.caption)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            Spacer()
                            zoomBadge
                        }

                        HStack(spacing: DojoSpace.sm) {
                            Picker("Editor Mode", selection: $mode) {
                                ForEach(Mode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            zoomButton(title: "1x", level: 1)
                            zoomButton(title: "2x", level: 2)
                            zoomButton(title: "3x", level: 3)
                        }

                        HStack(spacing: DojoSpace.sm) {
                            secondaryEditorButton(title: workingContour.isEmpty ? "Clear" : "Reset", systemImage: "arrow.counterclockwise") {
                                workingContour = initialContour
                                traceContour.removeAll()
                            }

                            secondaryEditorButton(title: "Center", systemImage: "scope") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    recenter(baseRect: baseRect, viewport: viewport)
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(DojoSpace.lg)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { onCancel() }
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            let points = simplifyContourPoints(workingContour, targetCount: 32)
                            guard points.count >= 8 else { return }
                            onSave(points)
                        }
                        .foregroundStyle(pointsReady ? DojoTheme.accentPrimary : Color.white.opacity(0.45))
                        .disabled(!pointsReady)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .onAppear {
                    initializeIfNeeded(baseRect: baseRect, viewport: viewport)
                }
            }
        }
    }

    private var pointsReady: Bool {
        workingContour.count >= 8
    }

    private var zoomBadge: some View {
        Text("\(zoom, specifier: "%.1f")x")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
            )
    }

    private func zoomButton(title: String, level: CGFloat) -> some View {
        Button(title) {
            withAnimation(.easeInOut(duration: 0.2)) {
                zoom = level
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.white.opacity(abs(zoom - level) < 0.15 ? 1 : 0.74))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(abs(zoom - level) < 0.15 ? 0.18 : 0.08))
        )
    }

    private func secondaryEditorButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func contourPath(points: [CGPoint], in imageRect: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: ImageSpaceTransform.viewPoint(from: first, imageRect: imageRect))
            for point in points.dropFirst() {
                path.addLine(to: ImageSpaceTransform.viewPoint(from: point, imageRect: imageRect))
            }
            if points.count > 2 {
                path.closeSubpath()
            }
        }
    }

    private func transformedRect(from baseRect: CGRect, zoom: CGFloat, offset: CGSize) -> CGRect {
        CGRect(
            x: baseRect.midX - (baseRect.width * zoom) / 2 + offset.width,
            y: baseRect.midY - (baseRect.height * zoom) / 2 + offset.height,
            width: baseRect.width * zoom,
            height: baseRect.height * zoom
        )
    }

    private func editorGesture(baseRect: CGRect, viewport: CGSize, imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if mode == .navigate {
                    if panStart == .zero { panStart = panOffset }
                    let proposed = CGSize(
                        width: panStart.width + value.translation.width,
                        height: panStart.height + value.translation.height
                    )
                    panOffset = clampedOffset(proposed, baseRect: baseRect, viewport: viewport, zoom: zoom)
                } else {
                    guard let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: imageRect) else { return }
                    traceContour.append(normalized)
                }
            }
            .onEnded { _ in
                if mode == .navigate {
                    panStart = panOffset
                } else {
                    if traceContour.count >= 10 {
                        workingContour = simplifyContourPoints(traceContour, targetCount: 32)
                    }
                    traceContour.removeAll()
                }
            }
    }

    private func magnifyGesture(baseRect: CGRect, viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(zoomStart * value, 1), 4)
                panOffset = clampedOffset(panOffset, baseRect: baseRect, viewport: viewport, zoom: zoom)
            }
            .onEnded { _ in
                zoomStart = zoom
            }
    }

    private func clampedOffset(_ proposed: CGSize, baseRect: CGRect, viewport: CGSize, zoom: CGFloat) -> CGSize {
        let scaledWidth = baseRect.width * zoom
        let scaledHeight = baseRect.height * zoom
        let maxX = max(20, (scaledWidth - viewport.width) / 2 + 20)
        let maxY = max(20, (scaledHeight - viewport.height) / 2 + 20)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func recenter(baseRect: CGRect, viewport: CGSize) {
        if let focusPoint {
            let focus = ImageSpaceTransform.viewPoint(from: focusPoint, imageRect: baseRect)
            let desired = CGSize(
                width: -(focus.x - baseRect.midX) * zoom,
                height: -(focus.y - baseRect.midY) * zoom
            )
            panOffset = clampedOffset(desired, baseRect: baseRect, viewport: viewport, zoom: zoom)
        } else {
            panOffset = .zero
        }
        panStart = panOffset
        zoomStart = zoom
    }

    private func initializeIfNeeded(baseRect: CGRect, viewport: CGSize) {
        guard !didInitialize else { return }
        didInitialize = true
        zoom = focusPoint == nil ? 1.6 : 2.3
        zoomStart = zoom
        recenter(baseRect: baseRect, viewport: viewport)
    }
}

private func simplifyContourPoints(_ points: [CGPoint], targetCount: Int) -> [CGPoint] {
    guard points.count > targetCount, targetCount > 2 else { return points }

    let closed = points + [points[0]]
    var lengths: [CGFloat] = [0]
    for index in 1..<closed.count {
        let dx = closed[index].x - closed[index - 1].x
        let dy = closed[index].y - closed[index - 1].y
        lengths.append(lengths[index - 1] + sqrt(dx * dx + dy * dy))
    }
    guard let totalLength = lengths.last, totalLength > 0 else { return points }

    var sampled: [CGPoint] = []
    for step in 0..<targetCount {
        let target = totalLength * CGFloat(step) / CGFloat(targetCount)
        guard let segmentIndex = lengths.firstIndex(where: { $0 >= target }), segmentIndex > 0 else {
            sampled.append(closed[min(step, closed.count - 1)])
            continue
        }

        let start = closed[segmentIndex - 1]
        let end = closed[segmentIndex]
        let segmentStart = lengths[segmentIndex - 1]
        let segmentLength = max(lengths[segmentIndex] - segmentStart, 0.0001)
        let t = (target - segmentStart) / segmentLength
        sampled.append(
            CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
        )
    }

    return sampled.isEmpty ? points : sampled
}

private struct ReviewSummaryGrid: View {
    let draft: EntryDraft

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DojoSpace.sm), GridItem(.flexible(), spacing: DojoSpace.sm)], spacing: DojoSpace.sm) {
            summaryCard(title: "Name", value: draft.name.isEmpty ? "Untitled" : draft.name)
            summaryCard(title: "Grade", value: draft.grade)
            summaryCard(title: "Route Color", value: draft.routeColor.title)
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

private struct ReviewMetadataSection: View {
    let draft: EntryDraft

    @ViewBuilder
    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                DojoSectionHeader(title: "Extra Details")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DojoSpace.sm),
                        GridItem(.flexible(), spacing: DojoSpace.sm)
                    ],
                    spacing: DojoSpace.sm
                ) {
                    if !draft.styleTags.isEmpty {
                        detailCard(title: "Style", value: tagsText(draft.styleTags.map(\.title)))
                    }
                    if !draft.holdTypeTags.isEmpty {
                        detailCard(title: "Hold Type", value: tagsText(draft.holdTypeTags.map(\.title)))
                    }
                    if !draft.techniqueTags.isEmpty {
                        detailCard(title: "Technique", value: tagsText(draft.techniqueTags.map(\.title)))
                    }
                    if !draft.gym.isEmpty {
                        detailCard(title: "Gym Override", value: draft.gym)
                    }
                    if !draft.notes.isEmpty {
                        detailCard(title: "Notes", value: draft.notes, lineLimit: nil)
                            .gridCellColumns(2)
                    }
                }
            }
        }
    }

    private var hasContent: Bool {
        !draft.styleTags.isEmpty ||
        !draft.holdTypeTags.isEmpty ||
        !draft.techniqueTags.isEmpty ||
        !draft.gym.isEmpty ||
        !draft.notes.isEmpty
    }

    private func tagsText(_ values: [String]) -> String {
        values.joined(separator: ", ")
    }

    private func detailCard(title: String, value: String, lineLimit: Int? = 3) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(value)
                .font(DojoType.body)
                .lineLimit(lineLimit)
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

private struct ExportedRouteFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct CropStepView: View {
    let image: UIImage
    @Binding var normalizedRect: CGRect
    let onCommit: () -> Void
    @State private var dragStartRect: CGRect = .zero
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
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DojoTheme.accentPrimary, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DojoTheme.accentPrimary.opacity(0.14))
                    )
                    .overlay {
                        CropGridOverlay()
                            .stroke(Color.white.opacity(0.42), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                            .padding(12)
                    }
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
                                onCommit()
                            }
                    )

                ForEach(CropHandle.allCases, id: \.self) { handle in
                    let point = handle.point(in: cropViewRect)
                    CropHandleView(handle: handle)
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
                                    onCommit()
                                }
                        )
                }

            }
            .contentShape(Rectangle())
        }
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
        case .top:
            next.origin.y = start.origin.y + dy
            next.size.height = start.size.height - dy
        case .topTrailing:
            next.origin.y = start.origin.y + dy
            next.size.width = start.size.width + dx
            next.size.height = start.size.height - dy
        case .trailing:
            next.size.width = start.size.width + dx
        case .bottomLeading:
            next.origin.x = start.origin.x + dx
            next.size.width = start.size.width - dx
            next.size.height = start.size.height + dy
        case .bottom:
            next.size.height = start.size.height + dy
        case .bottomTrailing:
            next.size.width = start.size.width + dx
            next.size.height = start.size.height + dy
        case .leading:
            next.origin.x = start.origin.x + dx
            next.size.width = start.size.width - dx
        }
        return next
    }
}

private enum CropHandle: CaseIterable {
    case topLeading
    case top
    case topTrailing
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
    case leading

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeading: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topTrailing: return CGPoint(x: rect.maxX, y: rect.minY)
        case .trailing: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeading: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomTrailing: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .leading: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

private struct CropHandleView: View {
    let handle: CropHandle

    var body: some View {
        Group {
            switch handle {
            case .top, .bottom:
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 28, height: 10)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(DojoTheme.accentPrimary, lineWidth: 2)
                    )
                    .padding(8)
            case .leading, .trailing:
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 10, height: 28)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(DojoTheme.accentPrimary, lineWidth: 2)
                    )
                    .padding(8)
            default:
                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(DojoTheme.accentPrimary, lineWidth: 2)
                    )
                    .padding(8)
            }
        }
    }
}

private struct CropGridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for step in 1...2 {
                let ratio = CGFloat(step) / 3
                let x = rect.minX + ratio * rect.width
                let y = rect.minY + ratio * rect.height
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
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
