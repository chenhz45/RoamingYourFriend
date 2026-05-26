import Foundation

/// Localized strings — auto-switches between English and Chinese
/// based on the user's system language. Falls back to English for unsupported languages.
enum Loc {

    private static var isChinese: Bool {
        guard let code = Locale.current.language.languageCode?.identifier else { return false }
        return code.hasPrefix("zh")
    }

    // MARK: - Setup Window

    static var appTitle: String {
        isChinese ? "漫游你的朋友" : "RoamingYourFriend"
    }

    static var createYourCompanion: String {
        isChinese ? "选择恶搞的对象" : "Create Your Companion For A Prank"
    }

    static var setupSubtitle: String {
        isChinese
            ? "选择一张带人脸的照片\n让TA变成蟑螂侠"
            : "Select a photo with a human face, \nLet her/him become a Cockroach Man!"
    }

    static var choosePhoto: String {
        isChinese ? "选择照片" : "Choose Photo"
    }

    static var clickOrDragDrop: String {
        isChinese ? "点击或拖放" : "Click or drag & drop"
    }

    static var processing: String {
        isChinese ? "处理中..." : "Processing..."
    }

    static var ready: String {
        isChinese ? "就绪！" : "Ready!"
    }

    static var failedToLoadPreview: String {
        isChinese ? "预览加载失败" : "Failed to load preview"
    }

    static var letsGo: String {
        isChinese ? "出发！" : "Let's Go!"
    }

    static var quit: String {
        isChinese ? "退出" : "Quit"
    }

    static var photoDisabledWhileRoaming: String {
        isChinese
            ? "漫游时无法更换照片"
            : "Photo cannot be changed while roaming"
    }

    static var back: String {
        isChinese ? "← 撤回" : "← Back"
    }

    // MARK: - Messages

    static var customMessages: String {
        isChinese ? "自定义消息" : "Custom Messages"
    }

    static var messageHint: String {
        isChinese ? "自定义消息会在靠近鼠标时随机显示" : "Shown randomly when near the mouse"
    }

    static func messagePlaceholder(_ index: Int) -> String {
        isChinese ? "消息 \(index + 1)" : "Message \(index + 1)"
    }

    static func messageLimit(_ current: Int, _ max: Int) -> String {
        "\(current)/\(max)"
    }

    // MARK: - History

    static var history: String {
        isChinese ? "历史记录" : "History"
    }

    static var noHistory: String {
        isChinese ? "暂无历史记录" : "No history yet"
    }

    // MARK: - Menu Bar

    static var settings: String {
        isChinese ? "设置..." : "Settings..."
    }
}
