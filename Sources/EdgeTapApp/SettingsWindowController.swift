import AppKit
import ApplicationServices
import EdgeTapCore

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSettingsChanged: ((AppSettings) -> Void)?

    private let settings: AppSettings

            private let monitoringEnabledSwitch = NSSwitch()
    private let languagePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let restartLabel = NSTextField(labelWithString: "")
    private let edgeThresholdSlider = NSSlider(value: 1.45, minValue: 1.20, maxValue: 1.80, target: nil, action: nil)
    private let triggerDeltaSlider = NSSlider(value: 0.12, minValue: 0.05, maxValue: 0.60, target: nil, action: nil)
    private let edgeThresholdValueLabel = NSTextField(labelWithString: "")
    private let triggerDeltaValueLabel = NSTextField(labelWithString: "")
    private let visualizerView = TouchVisualizerView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))
    private let liveTouchLabel = NSTextField(labelWithString: Localization.get("LIVE_TOUCH_WAITING"))
    private let shortcutMappingsEditorView = GestureShortcutBindingsEditorView(frame: NSRect(x: 0, y: 0, width: 380, height: 420))
    private let rootStack = NSStackView()
    
    private var permissionCheckTimer: Timer?
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let openAccessibilityButton = NSButton(title: "", target: nil, action: nil)
    private lazy var accessibilityStack: NSStackView = {
        let stack = NSStackView(views: [accessibilityStatusLabel, openAccessibilityButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        openAccessibilityButton.bezelStyle = .rounded
        openAccessibilityButton.controlSize = .small
        return stack
    }()

    init(settings: AppSettings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Localization.get("WINDOW_TITLE")
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.moveToActiveSpace]
        window.minSize = NSSize(width: 560, height: 520)
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        window.center()
        super.init(window: window)

        configureUI()
        wireShortcutMappingEditor()
        loadValuesFromSettings()
        
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccessibilityStatus()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func configureUI() {
        guard let window else {
            return
        }

        let materialView = NSVisualEffectView()
        materialView.material = .underPageBackground
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = materialView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.automaticallyAdjustsContentInsets = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        materialView.addSubview(scrollView)

        let documentView = FlippedContentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let contentColumn = NSView()
        contentColumn.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentColumn)

        contentColumn.addSubview(rootStack)

        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 24
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addSubview(rootStack)

        // ── Behavior section ──
        let behaviorSection = makeSection(
            header: Localization.get("SECTION_BEHAVIOR"),
            rows: [

                makeFormRow(
                    title: Localization.get("ROW_MONITORING"),
                    detail: Localization.get("DETAIL_MONITORING"),
                    trailing: monitoringEnabledSwitch
                ),
                makeFormRow(
                    title: Localization.get("ROW_LANGUAGE"),
                    detail: Localization.get("DETAIL_LANGUAGE"),
                    trailing: languagePopUp
                ),
            ]
        )
        let languageFooter = NSStackView(views: [restartLabel])
        languageFooter.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
        (behaviorSection as? NSStackView)?.addArrangedSubview(languageFooter)
        rootStack.addArrangedSubview(behaviorSection)

        // ── Permissions section ──
        let permissionsSection = makeSection(
            header: Localization.get("SECTION_PERMISSIONS"),
            rows: [
                makeFormRow(
                    title: Localization.get("ROW_ACCESSIBILITY"),
                    detail: Localization.get("DETAIL_ACCESSIBILITY"),
                    trailing: accessibilityStack
                )
            ]
        )
        rootStack.addArrangedSubview(permissionsSection)

        // ── Sensitivity section ──
        let sensitivitySection = makeSection(
            header: Localization.get("SECTION_SENSITIVITY"),
            rows: [
                makeSliderFormRow(
                    title: Localization.get("ROW_EDGE_THRESHOLD"),
                    detail: Localization.get("DETAIL_EDGE_THRESHOLD"),
                    slider: edgeThresholdSlider,
                    valueLabel: edgeThresholdValueLabel
                ),
                makeSliderFormRow(
                    title: Localization.get("ROW_TRIGGER_DELTA"),
                    detail: Localization.get("DETAIL_TRIGGER_DELTA"),
                    slider: triggerDeltaSlider,
                    valueLabel: triggerDeltaValueLabel
                ),
            ]
        )
        rootStack.addArrangedSubview(sensitivitySection)

        // ── Live Preview section (freeform — visualizer has its own background) ──
        let previewSection = makeFreeformSection(
            header: Localization.get("SECTION_LIVE_PREVIEW"),
            content: makeVisualizerContent()
        )
        rootStack.addArrangedSubview(previewSection)

        // ── Shortcut Mappings section (freeform — editor has its own card) ──
        let shortcutsSection = makeFreeformSection(
            header: Localization.get("SECTION_SHORTCUT_MAPPINGS"),
            content: makeShortcutMappingsContent()
        )
        rootStack.addArrangedSubview(shortcutsSection)
        
        NSLayoutConstraint.activate([
            behaviorSection.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            permissionsSection.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            sensitivitySection.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            previewSection.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            shortcutsSection.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
        ])

        // ── Wire actions ──
                                        monitoringEnabledSwitch.target = self
        monitoringEnabledSwitch.action = #selector(toggleMonitoringEnabled)
        edgeThresholdSlider.target = self
        edgeThresholdSlider.action = #selector(updateEdgeThreshold)
        triggerDeltaSlider.target = self
        triggerDeltaSlider.action = #selector(updateTriggerDelta)
        languagePopUp.target = self
        languagePopUp.action = #selector(changeLanguage)
        openAccessibilityButton.target = self
        openAccessibilityButton.action = #selector(openAccessibilitySettings)

        // ── Constraints ──
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: materialView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: materialView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: materialView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: materialView.bottomAnchor),

            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentColumn.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            contentColumn.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            contentColumn.widthAnchor.constraint(equalToConstant: 540),
            contentColumn.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -28),

            rootStack.topAnchor.constraint(equalTo: contentColumn.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentColumn.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentColumn.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentColumn.bottomAnchor),
        ])
    }

    // MARK: - Section builder

    /// Creates a full settings section: a small header label, then a grouped rounded-rect card
    /// containing the given rows separated by 1px dividers.
    private func makeSection(header: String, rows: [NSView]) -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 6

        // Header label (sits outside the card, like macOS System Settings)
        let headerLabel = NSTextField(labelWithString: header)
        headerLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headerLabel.textColor = .secondaryLabelColor
        wrapper.addArrangedSubview(headerLabel)

        // Grouped card
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.masksToBounds = true
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.alignment = .leading
        cardStack.spacing = 0
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        for (index, row) in rows.enumerated() {
            cardStack.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: cardStack.widthAnchor)
            ])
            if index < rows.count - 1 {
                let div = makeInsetDivider()
                cardStack.addArrangedSubview(div)
                NSLayoutConstraint.activate([
                    div.widthAnchor.constraint(equalTo: cardStack.widthAnchor)
                ])
            }
        }

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        wrapper.addArrangedSubview(card)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalTo: wrapper.widthAnchor)
        ])
        return wrapper
    }

    /// Creates a section with only a header label + raw content (no grouped card).
    /// Use for content that provides its own visual container.
    private func makeFreeformSection(header: String, content: NSView) -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 6

        let headerLabel = NSTextField(labelWithString: header)
        headerLabel.font = .systemFont(ofSize: 13, weight: .regular)
        headerLabel.textColor = .secondaryLabelColor
        wrapper.addArrangedSubview(headerLabel)
        
        wrapper.addArrangedSubview(content)
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: wrapper.widthAnchor)
        ])
        return wrapper
    }

    // MARK: - Row builders

    /// Standard form row: title + detail on the left, a trailing control on the right.
    private func makeFormRow(title: String, detail: String, trailing: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [textStack, spacer, trailing])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        return row
    }

    /// Slider row: title + value on the first line, detail on the second, slider on the third.
    private func makeSliderFormRow(
        title: String,
        detail: String,
        slider: NSSlider,
        valueLabel: NSTextField
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = .labelColor

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = NSStackView(views: [titleLabel, valueLabel])
        titleRow.orientation = .horizontal
        titleRow.distribution = .fill

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping

        slider.controlSize = .regular

        let stack = NSStackView(views: [titleRow, detailLabel, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        NSLayoutConstraint.activate([
            titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            slider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32)
        ])
        
        return stack
    }

    /// Touch visualizer + status label, displayed without a card wrapper.
    private func makeVisualizerContent() -> NSView {
        visualizerView.translatesAutoresizingMaskIntoConstraints = false
        visualizerView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        liveTouchLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        liveTouchLabel.textColor = .tertiaryLabelColor
        liveTouchLabel.maximumNumberOfLines = 0

        let stack = NSStackView(views: [visualizerView, liveTouchLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        
        NSLayoutConstraint.activate([
            visualizerView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            liveTouchLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        return stack
    }

    /// Shortcut mapping editor, displayed without a card wrapper.
    private func makeShortcutMappingsContent() -> NSView {
        shortcutMappingsEditorView.translatesAutoresizingMaskIntoConstraints = false
        return shortcutMappingsEditorView
    }

    // MARK: - Helpers

    private func makeInsetDivider() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    // MARK: - Data

    private func loadValuesFromSettings() {
                        monitoringEnabledSwitch.state = settings.monitoringEnabled ? .on : .off
        edgeThresholdSlider.doubleValue = settings.absoluteEdgeThresholdX
        triggerDeltaSlider.doubleValue = settings.triggerDeltaY
        refreshLabels()
        shortcutMappingsEditorView.apply(mappings: settings.gestureShortcutMappings, edgeActionTypes: settings.edgeActionTypes)
        setupLanguageMenu()
        refreshAccessibilityStatus()
    }
    
    private func setupLanguageMenu() {
        languagePopUp.removeAllItems()
        languagePopUp.addItems(withTitles: [
            Localization.get("LANG_EN"),
            Localization.get("LANG_ZH")
        ])
        
        if settings.language == "zh-hans" {
            languagePopUp.selectItem(at: 1)
        } else {
            languagePopUp.selectItem(at: 0)
        }
    }

    private func refreshLabels() {
        edgeThresholdValueLabel.stringValue = String(format: "%.2f", edgeThresholdSlider.doubleValue)
        triggerDeltaValueLabel.stringValue = String(format: "%.2f", triggerDeltaSlider.doubleValue)
    }

    private func refreshAllUI() {
        window?.title = Localization.get("WINDOW_TITLE")
        
        // Remove old sections and recreate them with new translations
        rootStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        configureUI()
        
        // Restore control values
        loadValuesFromSettings()
        
        // Update the footer text specifically
        restartLabel.stringValue = Localization.get("UI_RESTART_HINT")
        restartLabel.font = .systemFont(ofSize: 11, weight: .medium)
        restartLabel.textColor = .secondaryLabelColor
    }

    func updateTouches(_ touches: [TouchContact]) {
        visualizerView.touches = touches

        if touches.isEmpty {
            liveTouchLabel.stringValue = Localization.get("LIVE_TOUCH_NO_CONTACTS")
            return
        }

        let summary = touches.prefix(3).map { touch in
            "\(Localization.get("LIVE_TOUCH_ID")) \(touch.identifier)  x=\(String(format: "%.3f", touch.x))  y=\(String(format: "%.3f", touch.y))  s=\(touch.state)"
        }.joined(separator: "   |   ")
        liveTouchLabel.stringValue = "\(Localization.get("SECTION_LIVE_PREVIEW")): \(summary)"
    }

    // MARK: - Actions


    @objc
    private func toggleMonitoringEnabled() {
        if monitoringEnabledSwitch.state == .on {
            let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
            let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            if !isTrusted {
                let alert = NSAlert()
                alert.messageText = Localization.get("ACCESSIBILITY_REQUIRED_TITLE")
                alert.informativeText = Localization.get("ACCESSIBILITY_REQUIRED_MSG")
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                monitoringEnabledSwitch.state = .off
            }
        }
        settings.monitoringEnabled = monitoringEnabledSwitch.state == .on
        onSettingsChanged?(settings)
    }

    @objc
    private func updateEdgeThreshold() {
        settings.absoluteEdgeThresholdX = edgeThresholdSlider.doubleValue
        refreshLabels()
        onSettingsChanged?(settings)
    }

    @objc
    private func updateTriggerDelta() {
        settings.triggerDeltaY = triggerDeltaSlider.doubleValue
        refreshLabels()
        onSettingsChanged?(settings)
    }

    @objc
    private func changeLanguage() {
        let selectedIndex = languagePopUp.indexOfSelectedItem
        let code = selectedIndex == 1 ? "zh-hans" : "en"
        settings.language = code
        Localization.currentLanguage = code
        
        // Immediate UI refresh
        refreshAllUI()
        
        // Show a hint that some changes need restart
        restartLabel.stringValue = Localization.get("UI_RESTART_HINT")
        restartLabel.font = .systemFont(ofSize: 11, weight: .medium)
        restartLabel.textColor = .secondaryLabelColor
        
        onSettingsChanged?(settings)
    }

    private func wireShortcutMappingEditor() {
        shortcutMappingsEditorView.onMappingChanged = { [weak self] mapping in
            guard let self else {
                return
            }

            self.settings.updateGestureShortcutMapping(mapping)
            self.onSettingsChanged?(self.settings)
        }
        
        shortcutMappingsEditorView.onEdgeActionTypeChanged = { [weak self] edge, type in
            guard let self else { return }
            self.settings.edgeActionTypes[edge] = type
            self.onSettingsChanged?(self.settings)
        }
    }
    
    private func refreshAccessibilityStatus() {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            accessibilityStatusLabel.stringValue = Localization.get("STATUS_AUTHORIZED")
            accessibilityStatusLabel.textColor = .systemGreen
            openAccessibilityButton.isHidden = true
        } else {
            accessibilityStatusLabel.stringValue = Localization.get("STATUS_UNAUTHORIZED")
            accessibilityStatusLabel.textColor = .systemRed
            openAccessibilityButton.isHidden = false
            openAccessibilityButton.title = Localization.get("BTN_OPEN_SETTINGS")
        }
    }

    @objc
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
