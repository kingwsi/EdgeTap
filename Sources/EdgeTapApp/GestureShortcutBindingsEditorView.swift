import AppKit
import Carbon.HIToolbox
import SwiftUI

// Native AppKit implementation for the segmented control for better stability

@MainActor
final class GestureShortcutBindingsEditorView: NSView {
        var onMappingChanged: ((GestureShortcutMapping) -> Void)?
    var onEdgeActionTypeChanged: ((String, EdgeActionType) -> Void)?
    var onSectionChanged: ((Int) -> Void)?
    private var edgeActionTypes: [String: EdgeActionType] = [:]
    private var edgePickers: [NSSegmentedControl: String] = [:]
    private var edgeRowsContainers: [String: NSView] = [:]
    private var edgeVolumeLabels: [String: NSView] = [:]

    private struct SectionDefinition {
        let title: String
        let subtitle: String
        let slots: [GestureShortcutSlot]
        var trackpadEdge: String? = nil
    }

    private static let sections: [SectionDefinition] = [
        SectionDefinition(
            title: Localization.get("SEGMENT_TOP"),
            subtitle: Localization.get("SUBTITLE_TOP"),
            slots: [.topEdgeSwipeLeft, .topEdgeSwipeRight], trackpadEdge: "top"
        ),
        SectionDefinition(
            title: Localization.get("SEGMENT_BOTTOM"),
            subtitle: Localization.get("SUBTITLE_BOTTOM"),
            slots: [.bottomEdgeSwipeLeft, .bottomEdgeSwipeRight], trackpadEdge: "bottom"
        ),
        SectionDefinition(
            title: Localization.get("SEGMENT_LEFT"),
            subtitle: Localization.get("SUBTITLE_LEFT"),
            slots: [.leftEdgeSwipeUp, .leftEdgeSwipeDown], trackpadEdge: "left"
        ),
        SectionDefinition(
            title: Localization.get("SEGMENT_RIGHT"),
            subtitle: Localization.get("SUBTITLE_RIGHT"),
            slots: [.rightEdgeSwipeUp, .rightEdgeSwipeDown], trackpadEdge: "right"
        ),
        SectionDefinition(
            title: Localization.get("SEGMENT_CORNERS"),
            subtitle: Localization.get("SUBTITLE_CORNERS"),
            slots: [.cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight]
        ),
    ]

    private let rootStackView = NSStackView()
    private var segmentedControl: NSSegmentedControl?
    private let cardView = NSView()
    private let pagesContainer = NSView()

    private var rowViews: [GestureShortcutSlot: GestureShortcutBindingRowView] = [:]
    private var sectionPageViews: [Int: NSView] = [:]
    private var currentBindingsBySlot: [GestureShortcutSlot: GestureShortcutBinding] = [:]
    private var didBuildView = false
    private var selectedSectionIndex = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildViewIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        buildViewIfNeeded()
        return rootStackView.fittingSize
    }

        func apply(mappings: [GestureShortcutMapping], edgeActionTypes: [String: EdgeActionType]) {
        self.edgeActionTypes = edgeActionTypes
        buildViewIfNeeded()

        var bySlot: [GestureShortcutSlot: GestureShortcutBinding] = [:]
        for mapping in mappings {
            bySlot[mapping.slot] = mapping.binding
        }
        currentBindingsBySlot = bySlot

        for slot in GestureShortcutSlot.allCases {
            let mapping = GestureShortcutMapping(slot: slot, binding: bySlot[slot] ?? GestureShortcutBinding())
            rowViews[slot]?.configure(with: mapping)
        }

        for (edge, type) in edgeActionTypes {
            if let container = edgeRowsContainers[edge], let volumeLabel = edgeVolumeLabels[edge] {
                container.isHidden = (type == .continuousVolume)
                volumeLabel.isHidden = (type == .custom)
                
                if let picker = edgePickers.first(where: { $0.value == edge })?.key {
                    picker.selectedSegment = (type == .continuousVolume) ? 0 : 1
                }
            }
        }

        let oldIndex = selectedSectionIndex
        displaySection(at: selectedSectionIndex, from: oldIndex, animated: false)
    }

    @objc private func handleEdgeActionPicker(_ sender: NSSegmentedControl) {
        guard let edge = edgePickers[sender] else { return }
        let type: EdgeActionType = sender.selectedSegment == 0 ? .continuousVolume : .custom
        edgeActionTypes[edge] = type
        
        if let container = edgeRowsContainers[edge], let volumeLabel = edgeVolumeLabels[edge] {
            container.isHidden = (type == .continuousVolume)
            volumeLabel.isHidden = (type == .custom)
        }
        
        onEdgeActionTypeChanged?(edge, type)
    }

    // MARK: - Build

    private func buildViewIfNeeded() {
        guard !didBuildView else {
            return
        }

        didBuildView = true

        rootStackView.orientation = .vertical
        rootStackView.alignment = .leading
        rootStackView.distribution = .fill
        rootStackView.spacing = 10
        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStackView)

        NSLayoutConstraint.activate([
            rootStackView.topAnchor.constraint(equalTo: topAnchor),
            rootStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setupSegmentedControl()
        setupCard()
        showSection(at: 0)
    }

    private func setupSegmentedControl() {
        let labels = [
            Localization.get("SEGMENT_TOP"),
            Localization.get("SEGMENT_BOTTOM"),
            Localization.get("SEGMENT_LEFT"),
            Localization.get("SEGMENT_RIGHT"),
            Localization.get("SEGMENT_CORNERS")
        ]
        
        let segmentedControl = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: self, action: #selector(handleSegmentChange(_:)))
        segmentedControl.selectedSegment = selectedSectionIndex
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        self.segmentedControl = segmentedControl

        let segmentWrapper = NSView()
        segmentWrapper.translatesAutoresizingMaskIntoConstraints = false
        segmentWrapper.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: segmentWrapper.centerXAnchor),
            segmentedControl.topAnchor.constraint(equalTo: segmentWrapper.topAnchor, constant: 4),
            segmentedControl.bottomAnchor.constraint(equalTo: segmentWrapper.bottomAnchor, constant: -4),
        ])

        rootStackView.addArrangedSubview(segmentWrapper)
        NSLayoutConstraint.activate([
            segmentWrapper.widthAnchor.constraint(equalTo: rootStackView.widthAnchor)
        ])
    }

    @objc private func handleSegmentChange(_ sender: NSSegmentedControl) {
        let newIndex = sender.selectedSegment
        guard selectedSectionIndex != newIndex else { return }
        let oldIndex = selectedSectionIndex
        selectedSectionIndex = newIndex
        displaySection(at: newIndex, from: oldIndex, animated: true)
        onSectionChanged?(newIndex)
    }

    private func setupCard() {
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 10
        cardView.layer?.masksToBounds = true
        cardView.layer?.borderWidth = 0.5
        cardView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false

        pagesContainer.translatesAutoresizingMaskIntoConstraints = false
        pagesContainer.wantsLayer = true
        cardView.addSubview(pagesContainer)

        NSLayoutConstraint.activate([
            pagesContainer.topAnchor.constraint(equalTo: cardView.topAnchor),
            pagesContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            pagesContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            pagesContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
        ])

        rootStackView.addArrangedSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.widthAnchor.constraint(equalTo: rootStackView.widthAnchor)
        ])
        
        // Pre-build all pages and add them fully constrained
        for index in Self.sections.indices {
            let page = makeSectionPageView(for: Self.sections[index])
            page.translatesAutoresizingMaskIntoConstraints = false
            page.isHidden = true
            page.alphaValue = 0
            sectionPageViews[index] = page
            pagesContainer.addSubview(page)
            
            NSLayoutConstraint.activate([
                page.topAnchor.constraint(equalTo: pagesContainer.topAnchor),
                page.leadingAnchor.constraint(equalTo: pagesContainer.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: pagesContainer.trailingAnchor),
                // Allow the container to fit the tallest page smoothly
                page.bottomAnchor.constraint(lessThanOrEqualTo: pagesContainer.bottomAnchor)
            ])
            
            let bottomConstraint = page.bottomAnchor.constraint(equalTo: pagesContainer.bottomAnchor)
            bottomConstraint.priority = .defaultLow
            NSLayoutConstraint.activate([bottomConstraint])
        }
    }

    // MARK: - Section switching

    private func showSection(at index: Int) {
        guard Self.sections.indices.contains(index) else {
            return
        }

        let oldIndex = selectedSectionIndex
        selectedSectionIndex = index
        displaySection(at: index, from: oldIndex, animated: false)
    }

    private func displaySection(at index: Int, from oldIndex: Int? = nil, animated: Bool) {
        guard sectionPageViews[index] != nil else { return }

        if animated {
            let transition = CATransition()
            transition.type = .push
            
            if let oldIndex = oldIndex {
                transition.subtype = index > oldIndex ? .fromRight : .fromLeft
            } else {
                transition.subtype = .fromRight
            }
            
            transition.duration = 0.25
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            pagesContainer.layer?.add(transition, forKey: "tabSwitch")
        }
        
        for (i, page) in sectionPageViews {
            page.isHidden = (i != index)
            page.alphaValue = 1
        }
        
        if segmentedControl?.selectedSegment != index {
            segmentedControl?.selectedSegment = index
        }
    }
    
    private func makeSectionPageView(for section: SectionDefinition) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Section description row
        let descLabel = NSTextField(labelWithString: section.subtitle)
        descLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 0
        descLabel.lineBreakMode = .byWordWrapping

        let descRow = NSView()
        descRow.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descRow.addSubview(descLabel)

        NSLayoutConstraint.activate([
            descLabel.topAnchor.constraint(equalTo: descRow.topAnchor, constant: 10),
            descLabel.leadingAnchor.constraint(equalTo: descRow.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: descRow.trailingAnchor, constant: -16),
            descLabel.bottomAnchor.constraint(equalTo: descRow.bottomAnchor, constant: -10),
        ])
        stack.addArrangedSubview(descRow)
        NSLayoutConstraint.activate([
            descRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        let div1 = makeInsetDivider()
        stack.addArrangedSubview(div1)
        NSLayoutConstraint.activate([
            div1.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        if let edge = section.trackpadEdge {
            let picker = NSSegmentedControl(labels: [Localization.get("EDGE_ACTION_VOLUME"), Localization.get("EDGE_ACTION_CUSTOM")], trackingMode: .selectOne, target: self, action: #selector(handleEdgeActionPicker(_:)))
            picker.translatesAutoresizingMaskIntoConstraints = false
            edgePickers[picker] = edge
            
            let pickerContainer = NSView()
            pickerContainer.translatesAutoresizingMaskIntoConstraints = false
            pickerContainer.addSubview(picker)
            NSLayoutConstraint.activate([
                picker.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor, constant: 16),
                picker.topAnchor.constraint(equalTo: pickerContainer.topAnchor, constant: 10),
                picker.bottomAnchor.constraint(equalTo: pickerContainer.bottomAnchor, constant: -10),
            ])
            stack.addArrangedSubview(pickerContainer)
            NSLayoutConstraint.activate([
                pickerContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
            
            let div2 = makeInsetDivider()
            stack.addArrangedSubview(div2)
            NSLayoutConstraint.activate([div2.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        }

        let rowsContainer = NSView()
        rowsContainer.translatesAutoresizingMaskIntoConstraints = false
        if let edge = section.trackpadEdge { edgeRowsContainers[edge] = rowsContainer }
        
        let rowsStack = NSStackView()
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsContainer.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: rowsContainer.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: rowsContainer.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: rowsContainer.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: rowsContainer.bottomAnchor)
        ])
        
        stack.addArrangedSubview(rowsContainer)
        NSLayoutConstraint.activate([rowsContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)])

        for (i, slot) in section.slots.enumerated() {
            let rowView = GestureShortcutBindingRowView()
            rowView.translatesAutoresizingMaskIntoConstraints = false
            rowView.onMappingChanged = { [weak self] mapping in
                self?.currentBindingsBySlot[mapping.slot] = mapping.binding
                self?.onMappingChanged?(mapping)
            }
            rowView.configure(with: GestureShortcutMapping(slot: slot, binding: currentBindingsBySlot[slot] ?? GestureShortcutBinding()))
            rowViews[slot] = rowView
            rowsStack.addArrangedSubview(rowView)
            NSLayoutConstraint.activate([
                rowView.widthAnchor.constraint(equalTo: rowsStack.widthAnchor)
            ])

            if i < section.slots.count - 1 {
                let div = makeInsetDivider()
                rowsStack.addArrangedSubview(div)
                NSLayoutConstraint.activate([
                    div.widthAnchor.constraint(equalTo: rowsStack.widthAnchor)
                ])
            }
        }
        
        if let edge = section.trackpadEdge {
            let volumeLabel = NSTextField(labelWithString: Localization.get("EDGE_ACTION_VOLUME_DESC"))
            volumeLabel.font = .systemFont(ofSize: 13, weight: .regular)
            volumeLabel.textColor = .secondaryLabelColor
            volumeLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let labelContainer = NSView()
            labelContainer.translatesAutoresizingMaskIntoConstraints = false
            labelContainer.addSubview(volumeLabel)
            NSLayoutConstraint.activate([
                volumeLabel.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor, constant: 16),
                volumeLabel.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor, constant: -16),
                volumeLabel.topAnchor.constraint(equalTo: labelContainer.topAnchor, constant: 20),
                volumeLabel.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor, constant: -20),
            ])
            edgeVolumeLabels[edge] = labelContainer
            stack.addArrangedSubview(labelContainer)
            NSLayoutConstraint.activate([labelContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        }

        return stack
    }

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
}

// MARK: - Shortcut Recorder Field

@MainActor
final class ShortcutRecorderField: NSControl {
    var onShortcutRecorded: ((String) -> Void)?
    var shortcutValue: String = "" {
        didSet {
            updateAppearance()
        }
    }

    private let textLabel = NSTextField(labelWithString: "")

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            updateAppearance()
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        updateAppearance()
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        let filteredFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if event.keyCode == CGKeyCode(kVK_Delete) || event.keyCode == CGKeyCode(kVK_ForwardDelete) {
            // Delete key without modifiers clears the shortcut
            if filteredFlags.isEmpty {
                shortcutValue = ""
                onShortcutRecorded?("")
                return
            }
        }

        guard let capturedShortcut = ShortcutBinding.makeDisplayString(
            keyCode: event.keyCode,
            modifierFlags: filteredFlags
        ) else {
            NSSound.beep()
            return
        }

        shortcutValue = capturedShortcut
        onShortcutRecorded?(capturedShortcut)
        window?.makeFirstResponder(nil)
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5

        textLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        let isActive = window?.firstResponder === self
        let isEmpty = shortcutValue.isEmpty

        layer?.borderColor = (isActive ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(isActive ? 1.0 : 0.5).cgColor

        if isEmpty {
            textLabel.stringValue = isActive ? Localization.get("SHORTCUT_RECORDING") : Localization.get("SHORTCUT_CLICK_TO_RECORD")
            textLabel.textColor = .placeholderTextColor
        } else {
            textLabel.stringValue = shortcutValue
            textLabel.textColor = .labelColor
        }
    }
}

// MARK: - Binding Row View

@MainActor
final class GestureShortcutBindingRowView: NSView {
        var onMappingChanged: ((GestureShortcutMapping) -> Void)?
    var onEdgeActionTypeChanged: ((String, EdgeActionType) -> Void)?
    private var edgeActionTypes: [String: EdgeActionType] = [:]
    private var edgePickers: [NSSegmentedControl: String] = [:]
    private var edgeRowsContainers: [String: NSView] = [:]
    private var edgeVolumeLabels: [String: NSView] = [:]

    private let enableSwitch = NSSwitch()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let mediaActionButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let shortcutField = ShortcutRecorderField(frame: .zero)
    private let contentStackView = NSStackView()
    private var currentMapping = GestureShortcutMapping(slot: .topEdgeSwipeLeft)
    private var isUpdating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with mapping: GestureShortcutMapping) {
        isUpdating = true
        defer { isUpdating = false }

        currentMapping = mapping
        titleLabel.stringValue = mapping.slot.displayName
        enableSwitch.state = mapping.binding.enabled ? .on : .off
        mediaActionButton.selectItem(withTitle: mapping.binding.mediaAction.displayName)
        shortcutField.shortcutValue = mapping.binding.shortcut
        updateDerivedState()
    }

    private func setupView() {
        enableSwitch.target = self
        enableSwitch.action = #selector(toggleEnabled)
        enableSwitch.controlSize = .mini

        titleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail

        mediaActionButton.addItems(withTitles: MediaAction.allCases.map(\.displayName))
        mediaActionButton.target = self
        mediaActionButton.action = #selector(selectMediaAction)
        mediaActionButton.controlSize = .small
        mediaActionButton.setContentHuggingPriority(.required, for: .horizontal)
        mediaActionButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        shortcutField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        shortcutField.onShortcutRecorded = { [weak self] value in
            self?.commitShortcutValue(value)
        }

        let titleStack = NSStackView(views: [titleLabel, detailLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let trailingStack = NSStackView(views: [mediaActionButton, shortcutField])
        trailingStack.orientation = .horizontal
        trailingStack.alignment = .centerY
        trailingStack.spacing = 8

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        contentStackView.orientation = .horizontal
        contentStackView.alignment = .centerY
        contentStackView.distribution = .fill
        contentStackView.spacing = 10
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.addArrangedSubview(enableSwitch)
        contentStackView.addArrangedSubview(titleStack)
        contentStackView.addArrangedSubview(spacer)
        contentStackView.addArrangedSubview(trailingStack)

        addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            shortcutField.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            mediaActionButton.widthAnchor.constraint(equalToConstant: 120),
        ])
    }

    private func updateDerivedState() {
        let selectedAction = currentMapping.binding.mediaAction
        shortcutField.isEnabled = selectedAction == .none
        shortcutField.alphaValue = selectedAction == .none ? 1.0 : 0.46

        if currentMapping.binding.enabled {
            detailLabel.stringValue = selectedAction == .none ? Localization.get("DETAIL_KEYBOARD_SHORTCUT") : Localization.get("DETAIL_MEDIA_ACTION")
        } else {
            detailLabel.stringValue = Localization.get("DETAIL_DISABLED")
        }
    }

    @objc
    private func toggleEnabled() {
        guard !isUpdating else {
            return
        }

        currentMapping.binding.enabled = enableSwitch.state == .on
        updateDerivedState()
        onMappingChanged?(currentMapping)
    }

    @objc
    private func selectMediaAction() {
        guard !isUpdating else {
            return
        }

        let selectedAction = MediaAction.allCases[mediaActionButton.indexOfSelectedItem]
        currentMapping.binding.mediaAction = selectedAction
        updateDerivedState()
        onMappingChanged?(currentMapping)
    }

    private func commitShortcutValue(_ value: String) {
        guard !isUpdating else {
            return
        }

        currentMapping.binding.shortcut = value.trimmingCharacters(in: .whitespacesAndNewlines)
        updateDerivedState()
        onMappingChanged?(currentMapping)
    }
}
