import AppKit

@MainActor
final class SetupView: NSView {

    // MARK: - Mode

    enum Mode {
        case onboarding
        case display
    }

    var mode: Mode = .onboarding {
        didSet { applyMode() }
    }

    // MARK: - Callbacks

    var onPhotoSelected: ((String) -> Void)?
    var onStart: ((String) -> Void)?
    var onQuit: (() -> Void)?
    var onHistorySelected: ((String) -> Void)?
    var onModeChanged: ((Mode) -> Void)?

    /// Avatar path shown in `.display` mode.
    var displayAvatarPath: String?

    // MARK: - State

    private var processedPath: String?
    private var historyPopover: NSPopover?
    var historyEntries: [HistoryEntry] = []

    // MARK: - Title / Subtitle

    private let titleLabel: NSTextField = {
        let tf = NSTextField(labelWithString: Loc.createYourCompanion)
        tf.font = .systemFont(ofSize: 20, weight: .semibold)
        tf.textColor = .labelColor
        return tf
    }()

    private let subtitleLabel: NSTextField = {
        let tf = NSTextField(wrappingLabelWithString: Loc.setupSubtitle)
        tf.font = .systemFont(ofSize: 13, weight: .regular)
        tf.textColor = .secondaryLabelColor
        tf.maximumNumberOfLines = 2
        return tf
    }()

    // MARK: - Input Box

    private let photoContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 128).isActive = true
        v.heightAnchor.constraint(equalToConstant: 144).isActive = true
        return v
    }()

    private lazy var dropStack: NSStackView = {
        let img = NSImage(systemSymbolName: "photo.badge.plus",
                          accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 36, weight: .light))
        let icon = NSImageView(image: img!)
        icon.contentTintColor = .tertiaryLabelColor

        let label = NSTextField(labelWithString: Loc.choosePhoto)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center

        let hint = NSTextField(labelWithString: Loc.clickOrDragDrop)
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center

        let stack = NSStackView(views: [icon, label, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let originalImageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleAxesIndependently
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 20
        iv.layer?.masksToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    // MARK: - Flow Arrow

    private let flowArrow: NSImageView = {
        let img = NSImage(systemSymbolName: "arrow.down",
                          accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        let iv = NSImageView(image: img!)
        iv.contentTintColor = .tertiaryLabelColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Preview Box

    private let previewContainer: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 20
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 128).isActive = true
        v.heightAnchor.constraint(equalToConstant: 144).isActive = true
        return v
    }()

    private let previewPlaceholder: NSView = {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dashedCircle = NSView()
        dashedCircle.wantsLayer = true
        dashedCircle.layer?.cornerRadius = 40
        dashedCircle.layer?.borderWidth = 1.5
        dashedCircle.translatesAutoresizingMaskIntoConstraints = false
        dashedCircle.widthAnchor.constraint(equalToConstant: 80).isActive = true
        dashedCircle.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let label = NSTextField(labelWithString: "Preview")
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center

        let stack = NSStackView(views: [dashedCircle, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }()

    private let previewView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleAxesIndependently
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 40
        iv.layer?.masksToBounds = true
        iv.layer?.borderWidth = 2
        iv.layer?.borderColor = NSColor.white.cgColor
        iv.layer?.shadowColor = NSColor.black.withAlphaComponent(0.15).cgColor
        iv.layer?.shadowOffset = CGSize(width: 0, height: 2)
        iv.layer?.shadowRadius = 8
        iv.layer?.shadowOpacity = 1
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 80).isActive = true
        iv.isHidden = true
        return iv
    }()

    private let backButton: NSButton = {
        let img = NSImage(systemSymbolName: "arrow.uturn.backward",
                          accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        let btn = NSButton(image: img!, target: nil, action: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 13
        btn.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        btn.contentTintColor = .white
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 26).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 26).isActive = true
        btn.isHidden = true
        return btn
    }()

    private let spinner: NSProgressIndicator = {
        let sp = NSProgressIndicator()
        sp.style = .spinning
        sp.controlSize = .regular
        sp.translatesAutoresizingMaskIntoConstraints = false
        sp.isHidden = true
        return sp
    }()

    private let statusLabel: NSTextField = {
        let tf = NSTextField(labelWithString: Loc.processing)
        tf.font = .systemFont(ofSize: 12, weight: .regular)
        tf.textColor = .secondaryLabelColor
        tf.alignment = .center
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.isHidden = true
        return tf
    }()

    private var rootStack: NSStackView?

    // MARK: - Display mode (mini character preview)

    private let displayCharView = CharacterView()

    private lazy var displayContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true

        displayCharView.translatesAutoresizingMaskIntoConstraints = false
        displayCharView.widthAnchor.constraint(equalToConstant: 150).isActive = true
        displayCharView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let displayQuit = NSButton(title: Loc.quit, target: self, action: #selector(didTapQuit))
        displayQuit.bezelStyle = .inline
        displayQuit.isBordered = false
        displayQuit.font = .systemFont(ofSize: 12, weight: .regular)
        displayQuit.contentTintColor = .tertiaryLabelColor

        let topPad = NSView()
        topPad.translatesAutoresizingMaskIntoConstraints = false
        topPad.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let stack = NSStackView(views: [topPad, displayCharView, displayQuit])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])

        return v
    }()

    // MARK: - Messages Section

    private var messageFields: [NSTextField] = []
    private var messageCounters: [NSTextField] = []

    private static var cardBackgroundColor: NSColor {
        NSColor(name: "setupCardBg") { appearance in
            let isDark = appearance.name == .darkAqua || appearance.name == .vibrantDark
            return isDark
                ? NSColor(calibratedWhite: 0.17, alpha: 1.0)
                : NSColor(calibratedWhite: 0.96, alpha: 1.0)
        }
    }

    // MARK: - Buttons

    private let startButton: NSButton = {
        let btn = NSButton(title: Loc.letsGo, target: nil, action: nil)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 10
        btn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        btn.contentTintColor = .white
        btn.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.isEnabled = false
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 150).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return btn
    }()

    private let historyButton: NSButton = {
        let btn = NSButton(title: Loc.history, target: nil, action: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = .systemFont(ofSize: 12, weight: .regular)
        btn.contentTintColor = .controlAccentColor
        return btn
    }()

    private let quitButton: NSButton = {
        let btn = NSButton(title: Loc.quit, target: nil, action: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = .systemFont(ofSize: 12, weight: .regular)
        btn.contentTintColor = .tertiaryLabelColor
        return btn
    }()

    // MARK: - Build helpers

    private func buildMessageHintRow() -> NSView {
        let img = NSImage(systemSymbolName: "info.circle",
                          accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
        let iv = NSImageView(image: img!)
        iv.contentTintColor = .secondaryLabelColor
        iv.translatesAutoresizingMaskIntoConstraints = false

        let tf = NSTextField(labelWithString: Loc.messageHint)
        tf.font = .systemFont(ofSize: 11, weight: .regular)
        tf.textColor = .secondaryLabelColor

        let row = NSStackView(views: [iv, tf])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4
        return row
    }

    private func buildButtonRow() -> NSView {
        let row = NSStackView(views: [startButton, historyButton, quitButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func buildMessagesHeader() -> NSView {
        let label = NSTextField(labelWithString: Loc.customMessages)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = NSStackView(views: [label, sep])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func buildMessagesCardRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.distribution = .fillEqually
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        for i in 0..<MessageStore.maxMessages {
            let card = NSView()
            card.wantsLayer = true
            card.layer?.cornerRadius = 12
            card.layer?.backgroundColor = Self.cardBackgroundColor.cgColor
            card.translatesAutoresizingMaskIntoConstraints = false

            let textField = NSTextField()
            textField.placeholderString = Loc.messagePlaceholder(i)
            textField.font = .systemFont(ofSize: 13, weight: .regular)
            textField.textColor = .labelColor
            textField.isBordered = false
            textField.drawsBackground = false
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false

            let counter = NSTextField(labelWithString: Loc.messageLimit(0, MessageStore.maxLength))
            counter.font = .systemFont(ofSize: 11, weight: .regular)
            counter.textColor = .tertiaryLabelColor
            counter.alignment = .right
            counter.translatesAutoresizingMaskIntoConstraints = false

	            let clearBtn = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill",
	                                                       accessibilityDescription: nil)!
	                                   .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))!,
	                                 target: self,
	                                 action: #selector(didTapClearMessage(_:)))
	            clearBtn.bezelStyle = .inline
	            clearBtn.isBordered = false
	            clearBtn.contentTintColor = .tertiaryLabelColor
	            clearBtn.translatesAutoresizingMaskIntoConstraints = false
	            clearBtn.widthAnchor.constraint(equalToConstant: 16).isActive = true
	            clearBtn.heightAnchor.constraint(equalToConstant: 16).isActive = true
	            clearBtn.tag = i

	            let content = NSStackView(views: [textField, clearBtn, counter])
            content.orientation = .horizontal
            content.alignment = .centerY
            content.spacing = 8
            content.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
                content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
                content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
                content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            ])

            row.addArrangedSubview(card)
            messageFields.append(textField)
            messageCounters.append(counter)
        }

        return row
    }

    private func loadMessages() {
        let msgs = MessageStore.shared.messages
        for (i, field) in messageFields.enumerated() {
            if i < msgs.count, !msgs[i].isEmpty {
                field.stringValue = msgs[i]
                messageCounters[i].stringValue = Loc.messageLimit(msgs[i].count, MessageStore.maxLength)
            }
        }
    }

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        buildLayout()
        loadMessages()
        setupActions()
        registerDragAndDrop()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Dashed border

    override func layout() {
        super.layout()
        updateDashedBorders()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateDashedBorders()
    }

    private func updateDashedBorders() {
        let gray = NSColor.separatorColor.cgColor

        // Photo container dashed border
        if photoContainer.bounds.width > 0 {
            photoContainer.layer?.sublayers?.removeAll(where: { $0.name == "dashBorder" })
            let shape = CAShapeLayer()
            shape.name = "dashBorder"
            shape.path = NSBezierPath(roundedRect: photoContainer.bounds, xRadius: 20, yRadius: 20).cgPath
            shape.strokeColor = gray
            shape.fillColor = nil
            shape.lineWidth = 1.5
            shape.lineDashPattern = [6, 3]
            photoContainer.layer?.addSublayer(shape)
        }

        // Preview container dashed border
        if previewContainer.bounds.width > 0 {
            previewContainer.layer?.sublayers?.removeAll(where: { $0.name == "dashBorder" })
            let shape = CAShapeLayer()
            shape.name = "dashBorder"
            shape.path = NSBezierPath(roundedRect: previewContainer.bounds, xRadius: 20, yRadius: 20).cgPath
            shape.strokeColor = gray
            shape.fillColor = nil
            shape.lineWidth = 1.5
            shape.lineDashPattern = [6, 3]
            previewContainer.layer?.addSublayer(shape)
        }

        // Preview placeholder dashed circle
        if let dashedCircle = previewPlaceholder.subviews.first?.subviews.first as? NSView,
           dashedCircle.bounds.width > 0 {
            dashedCircle.layer?.sublayers?.removeAll(where: { $0.name == "dashCircle" })
            let circle = CAShapeLayer()
            circle.name = "dashCircle"
            circle.path = CGPath(ellipseIn: dashedCircle.bounds, transform: nil)
            circle.strokeColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
            circle.fillColor = nil
            circle.lineWidth = 1.5
            circle.lineDashPattern = [5, 3]
            dashedCircle.layer?.addSublayer(circle)
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        // —— Input box ——
        photoContainer.addSubview(dropStack)
        photoContainer.addSubview(originalImageView)

        NSLayoutConstraint.activate([
            dropStack.centerXAnchor.constraint(equalTo: photoContainer.centerXAnchor),
            dropStack.centerYAnchor.constraint(equalTo: photoContainer.centerYAnchor),
            originalImageView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            originalImageView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            originalImageView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            originalImageView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),
        ])

        // —— Preview box ——
        previewContainer.addSubview(previewPlaceholder)
        previewContainer.addSubview(previewView)
        previewContainer.addSubview(backButton)
        previewContainer.addSubview(spinner)
        previewContainer.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            previewPlaceholder.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewPlaceholder.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            previewView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            backButton.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            backButton.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -16),
            spinner.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
        ])

        // —— Left column ——
        let leftTopSpacer = NSView()
        leftTopSpacer.translatesAutoresizingMaskIntoConstraints = false
        leftTopSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let leftColumn = NSStackView(views: [leftTopSpacer, photoContainer, flowArrow, previewContainer])
        leftColumn.orientation = .vertical
        leftColumn.alignment = .centerX
        leftColumn.spacing = 8
        leftColumn.translatesAutoresizingMaskIntoConstraints = false

        // —— Right column ——
        let header = buildMessagesHeader()
        let cardRow = buildMessagesCardRow()
        cardRow.widthAnchor.constraint(equalToConstant: 256).isActive = true
        let hintRow = buildMessageHintRow()
        let buttonRow = buildButtonRow()

        let rightTopSpacer = NSView()
        rightTopSpacer.translatesAutoresizingMaskIntoConstraints = false
        rightTopSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let rightColumn = NSStackView(views: [
            rightTopSpacer,
            titleLabel,
            subtitleLabel,
            header,
            cardRow,
            hintRow,
            buttonRow,
        ])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .centerX
        rightColumn.spacing = 0
        rightColumn.setCustomSpacing(4, after: titleLabel)
        rightColumn.setCustomSpacing(20, after: subtitleLabel)
        rightColumn.setCustomSpacing(8, after: header)
        rightColumn.setCustomSpacing(6, after: cardRow)
        rightColumn.setCustomSpacing(22, after: hintRow)
        rightColumn.translatesAutoresizingMaskIntoConstraints = false

        // —— Root ——
        let root = NSStackView(views: [leftColumn, rightColumn])
        root.orientation = .horizontal
        root.alignment = .centerY
        root.spacing = 24
        root.translatesAutoresizingMaskIntoConstraints = false

        addSubview(root)
        self.rootStack = root

        // Display container (hidden until .display mode)
        addSubview(displayContainer)

        NSLayoutConstraint.activate([
            root.centerXAnchor.constraint(equalTo: centerXAnchor),
            root.centerYAnchor.constraint(equalTo: centerYAnchor),

            displayContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            displayContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            displayContainer.widthAnchor.constraint(equalToConstant: 280),
            displayContainer.heightAnchor.constraint(equalToConstant: 280),
        ])
    }

    // MARK: - Actions

    private func setupActions() {
        startButton.target = self
        startButton.action = #selector(didTapStart)
        quitButton.target = self
        quitButton.action = #selector(didTapQuit)
        historyButton.target = self
        historyButton.action = #selector(didTapHistory)
        backButton.target = self
        backButton.action = #selector(didTapBack)

        let click = NSClickGestureRecognizer(target: self, action: #selector(didTapPhotoArea))
        photoContainer.addGestureRecognizer(click)
    }

    @objc private func didTapPhotoArea() {
        guard mode == .onboarding else { return }
        openFilePicker()
    }

    @objc private func didTapStart() {
        guard let path = processedPath else { return }
        onStart?(path)
    }

    @objc private func didTapQuit() {
        onQuit?()
    }

    @objc private func didTapClearMessage(_ sender: NSButton) {
        let i = sender.tag
        guard i < messageFields.count else { return }
        messageFields[i].stringValue = ""
        messageCounters[i].stringValue = Loc.messageLimit(0, MessageStore.maxLength)
        saveMessages()
    }

    @objc private func didTapBack() {
        resetToInitialState()
    }

    @objc private func didTapHistory() {
        if let popover = historyPopover, popover.isShown {
            popover.close()
            return
        }
        showHistoryPopover()
    }

    // MARK: - History Popover

    private func showHistoryPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = {
            let vc = NSViewController()
            vc.view = buildHistoryContentView()
            return vc
        }()
        historyPopover = popover
        popover.show(relativeTo: historyButton.bounds, of: historyButton, preferredEdge: .maxY)
    }

    private func buildHistoryContentView() -> NSView {
        let entries = historyEntries
        let root = NSView(frame: .zero)

        if entries.isEmpty {
            let label = NSTextField(labelWithString: Loc.noHistory)
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = .tertiaryLabelColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: root.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            ])
            root.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
            return root
        }

        let title = NSTextField(labelWithString: Loc.history)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(title)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"

        for entry in entries {
            let cell = makeHistoryCell(entry: entry, dateFormatter: dateFormatter)
            row.addArrangedSubview(cell)
        }

        row.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.documentView = row

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scrollView.topAnchor),
            row.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            scrollView.heightAnchor.constraint(equalToConstant: 86),
        ])

        let w = CGFloat(entries.count) * 74 + 24
        root.frame = NSRect(x: 0, y: 0, width: max(320, min(w, 420)), height: 144)
        return root
    }

    private func makeHistoryCell(entry: HistoryEntry, dateFormatter: DateFormatter) -> NSView {
        let cell = NSView()
        cell.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 28
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 1.5
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 56).isActive = true
        if let img = NSImage(contentsOfFile: entry.processedPath) {
            imageView.image = img
        } else {
            imageView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor
        }

        let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: entry.timestamp))
        dateLabel.font = .systemFont(ofSize: 10, weight: .regular)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.alignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [imageView, dateLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.topAnchor),
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            cell.widthAnchor.constraint(equalToConstant: 66),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(didSelectHistoryEntry(_:)))
        cell.addGestureRecognizer(click)
        cell.identifier = NSUserInterfaceItemIdentifier(entry.id)

        return cell
    }

    @objc private func didSelectHistoryEntry(_ gesture: NSClickGestureRecognizer) {
        guard let cell = gesture.view,
              let id = cell.identifier?.rawValue,
              let entry = historyEntries.first(where: { $0.id == id }) else { return }

        historyPopover?.close()
        processedPath = entry.processedPath

        if let original = NSImage(contentsOfFile: entry.originalPath) {
            originalImageView.image = original
            originalImageView.alphaValue = 0
            originalImageView.isHidden = false
            dropStack.isHidden = true
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                originalImageView.animator().alphaValue = 1
            }
        }

        if let image = NSImage(contentsOfFile: entry.processedPath) {
            previewPlaceholder.isHidden = true
            previewView.image = image
            previewView.alphaValue = 0
            previewView.isHidden = false
            backButton.alphaValue = 0
            backButton.isHidden = false
            startButton.isEnabled = true

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                previewView.animator().alphaValue = 1
                backButton.animator().alphaValue = 1
            }
        }
    }

    private func resetToInitialState() {
        processedPath = nil
        startButton.isEnabled = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            originalImageView.animator().alphaValue = 0
            dropStack.animator().alphaValue = 1
            previewView.animator().alphaValue = 0
            backButton.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.originalImageView.isHidden = true
            self.originalImageView.image = nil
            self.previewView.isHidden = true
            self.previewView.image = nil
            self.backButton.isHidden = true
            self.dropStack.isHidden = false
            self.spinner.stopAnimation(nil)
            self.spinner.isHidden = true
            self.statusLabel.isHidden = true
            self.previewPlaceholder.isHidden = false
        }
    }

    // MARK: - File Picker

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Choose a character photo"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectPhoto(url.path)
    }

    // MARK: - Drag & Drop

    private func registerDragAndDrop() {
        photoContainer.registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard mode == .onboarding else { return [] }
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
            ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard mode == .onboarding,
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return false }
        selectPhoto(url.path)
        return true
    }

    // MARK: - Photo Selection

    private func selectPhoto(_ path: String) {
        processedPath = nil
        startButton.isEnabled = false

        if let originalImage = NSImage(contentsOfFile: path) {
            originalImageView.image = originalImage
            originalImageView.alphaValue = 0
            originalImageView.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                dropStack.animator().alphaValue = 0
                originalImageView.animator().alphaValue = 1
            } completionHandler: {
                self.dropStack.isHidden = true
            }
        }

        previewPlaceholder.isHidden = true
        previewView.isHidden = true
        backButton.isHidden = true
        spinner.isHidden = false
        spinner.startAnimation(nil)
        statusLabel.isHidden = false
        statusLabel.stringValue = Loc.processing
        statusLabel.textColor = .secondaryLabelColor

        onPhotoSelected?(path)
    }

    // MARK: - Public: Processed Preview

    func showProcessedPreview(_ outputPath: String) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        statusLabel.isHidden = true

        processedPath = outputPath

        guard let image = NSImage(contentsOfFile: outputPath) else {
            statusLabel.stringValue = Loc.failedToLoadPreview
            statusLabel.textColor = .systemRed
            statusLabel.isHidden = false
            return
        }

        previewView.image = image
        previewView.alphaValue = 0
        previewView.isHidden = false
        backButton.alphaValue = 0
        backButton.isHidden = false
        startButton.isEnabled = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            previewView.animator().alphaValue = 1
            backButton.animator().alphaValue = 1
        }
    }

    // MARK: - Mode

    private func applyMode() {
        switch mode {
        case .onboarding:
            rootStack?.isHidden = false
            displayContainer.isHidden = true
            startButton.alphaValue = 1
            startButton.isEnabled = processedPath != nil
            quitButton.alphaValue = 1
        case .display:
            rootStack?.isHidden = true
            displayContainer.isHidden = false
            displayCharView.avatarImagePath = displayAvatarPath
            onModeChanged?(.display)
        }
    }
}

// MARK: - NSTextFieldDelegate

extension SetupView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let index = messageFields.firstIndex(of: field) else { return }

        let text = field.stringValue
        if text.count > MessageStore.maxLength {
            field.stringValue = String(text.prefix(MessageStore.maxLength))
        }

        let count = field.stringValue.count
        messageCounters[index].stringValue = Loc.messageLimit(count, MessageStore.maxLength)
        messageCounters[index].textColor = count >= MessageStore.maxLength
            ? .systemRed : .tertiaryLabelColor

        if count >= MessageStore.maxLength {
            shakeView(messageCounters[index])
        }

        saveMessages()
    }

    private func shakeView(_ view: NSView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -3, 3, -3, 3, 0]
        animation.duration = 0.1
        view.layer?.add(animation, forKey: "shake")
    }

    private func saveMessages() {
        let msgs = messageFields.map { $0.stringValue }
        MessageStore.shared.messages = msgs
    }
}
