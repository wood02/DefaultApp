import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreServices

// MARK: - Data Models

struct AppInfo: Identifiable, Hashable {
    let id: String // bundleId
    let name: String
    let bundleId: String
    let path: String
    let icon: NSImage
    let extensions: [String]
    let category: AppCategory
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
}

enum AppCategory: String, CaseIterable, Identifiable {
    case all = "全部应用"
    case code = "代码与开发"
    case markdown = "文本与写作"
    case office = "办公与文档"
    case browser = "网页浏览"
    case archive = "压缩与归档"
    case media = "影音多媒体"
    case utility = "数据库与工具"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .markdown: return "doc.text"
        case .office: return "folder.badge.gearshape"
        case .browser: return "globe"
        case .archive: return "archivebox"
        case .media: return "play.circle"
        case .utility: return "wrench.and.screwdriver"
        }
    }
}

struct ExtensionItem: Identifiable {
    let id: String // extension without dot
    let ext: String
    var uti: String
    var desc: String
    var currentHandlerBundleId: String?
    var currentHandlerName: String?
    var currentHandlerIcon: NSImage?
    var isDefaultByTargetApp: Bool = false
    var isSelected: Bool = false
    var isCommon: Bool = false
}

// Global list of prominent/common file extensions
let commonExtensionSet: Set<String> = [
    "py", "js", "ts", "jsx", "tsx", "html", "htm", "css", "scss", "json", "md", "markdown",
    "sh", "bash", "zsh", "c", "cpp", "h", "hpp", "java", "kt", "swift", "m",
    "go", "rs", "php", "rb", "sql", "xml", "yaml", "yml", "toml", "ini", "conf", "env",
    "txt", "pdf", "rtf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv",
    "zip", "tar", "gz", "7z", "rar", "dmg", "iso",
    "png", "jpg", "jpeg", "svg", "webp", "gif", "ico",
    "mp4", "mov", "mkv", "avi", "webm", "mp3", "wav", "flac", "m4a"
]

struct CandidateApp: Identifiable {
    var id: String { bundleId }
    let bundleId: String
    let name: String
    let icon: NSImage
    let path: String
    let isCurrentDefault: Bool
    
    var menuIcon: NSImage {
        let copy = icon.copy() as! NSImage
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }
}

// MARK: - Service Manager

final class LaunchServicesManager {
    static let shared = LaunchServicesManager()
    
    func getCurrentDefault(for ext: String) -> (bundleId: String, name: String, icon: NSImage)? {
        guard let ut = UTType(filenameExtension: ext) else { return nil }
        guard let handler = LSCopyDefaultRoleHandlerForContentType(ut.identifier as CFString, .all)?.takeRetainedValue() as String? else {
            return nil
        }
        let (name, icon) = getAppDetails(bundleId: handler)
        return (handler, name, icon)
    }
    
    func getAllCandidates(for ext: String) -> [CandidateApp] {
        guard let ut = UTType(filenameExtension: ext) else { return [] }
        guard let handlers = LSCopyAllRoleHandlersForContentType(ut.identifier as CFString, .all)?.takeRetainedValue() as? [String] else {
            return []
        }
        let currentDefault = LSCopyDefaultRoleHandlerForContentType(ut.identifier as CFString, .all)?.takeRetainedValue() as String?
        
        var results = [CandidateApp]()
        var seen = Set<String>()
        for bid in handlers {
            guard !seen.contains(bid) else { continue }
            seen.insert(bid)
            let (name, icon, path) = getAppFullDetails(bundleId: bid)
            results.append(CandidateApp(
                bundleId: bid,
                name: name,
                icon: icon,
                path: path,
                isCurrentDefault: (bid == currentDefault)
            ))
        }
        return results.sorted {
            if $0.isCurrentDefault != $1.isCurrentDefault {
                return $0.isCurrentDefault && !$1.isCurrentDefault
            }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
    
    func setDefault(ext: String, bundleId: String) -> Bool {
        guard let ut = UTType(filenameExtension: ext) else { return false }
        let status = LSSetDefaultRoleHandlerForContentType(ut.identifier as CFString, .all, bundleId as CFString)
        return status == noErr
    }
    
    func batchSetDefault(exts: [String], bundleId: String) -> (success: Int, failed: Int) {
        var s = 0
        var f = 0
        for ext in exts {
            if setDefault(ext: ext, bundleId: bundleId) {
                s += 1
            } else {
                f += 1
            }
        }
        return (s, f)
    }
    
    func getAppDetails(bundleId: String) -> (name: String, icon: NSImage) {
        let (name, icon, _) = getAppFullDetails(bundleId: bundleId)
        return (name, icon)
    }
    
    func getAppFullDetails(bundleId: String) -> (name: String, icon: NSImage, path: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return (name, icon, url.path)
        }
        if bundleId == "com.apple.archiveutility" {
            let path = "/System/Library/CoreServices/Applications/Archive Utility.app"
            let icon = NSWorkspace.shared.icon(forFile: path)
            return ("归档实用工具", icon, path)
        }
        if let appType = UTType("com.apple.application-bundle") {
            return (bundleId, NSWorkspace.shared.icon(for: appType), "")
        }
        return (bundleId, NSImage(size: NSSize(width: 32, height: 32)), "")
    }
}

// MARK: - App Scanner

final class AppScanner {
    static func scanAllApps() -> [AppInfo] {
        let searchPaths: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
        ]
        
        var apps = [AppInfo]()
        var seenBundleIds = Set<String>()
        
        for dir in searchPaths {
            let appItems = collectAppBundles(in: dir)
            for item in appItems {
                let plistURL = item.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let bundleId = plist["CFBundleIdentifier"] as? String,
                      !bundleId.isEmpty,
                      !seenBundleIds.contains(bundleId) else {
                    continue
                }
                
                var exts = extractSupportedExtensions(from: plist)
                
                if bundleId == "com.apple.archiveutility" && exts.isEmpty {
                    exts.formUnion(["zip", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "cpgz", "cpio"])
                }
                
                guard !exts.isEmpty else { continue }
                seenBundleIds.insert(bundleId)
                
                let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? item.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: item.path)
                let category = categorize(bundleId: bundleId, name: name, exts: exts)
                
                apps.append(AppInfo(
                    id: bundleId,
                    name: name,
                    bundleId: bundleId,
                    path: item.path,
                    icon: icon,
                    extensions: Array(exts).sorted(),
                    category: category
                ))
            }
        }
        
        return apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    /// 扫描指定目录及其下一层子目录（如 /Applications/Setapp、~/Applications/JetBrains Toolbox 等）中的 .app
    private static func collectAppBundles(in rootDir: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: rootDir,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        var results = [URL]()
        for item in items {
            if item.pathExtension.lowercased() == "app" {
                results.append(item)
                continue
            }
            // 如果是普通文件夹且不是 .app/.framework 等 Package，则向下扫描一层
            if let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
               values.isDirectory == true,
               values.isPackage != true,
               let subItems = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for subItem in subItems where subItem.pathExtension.lowercased() == "app" {
                    results.append(subItem)
                }
            }
        }
        return results
    }
    
    /// 从 Info.plist 中提取应用支持的文件扩展名（同时支持 CFBundleTypeExtensions 与 LSItemContentTypes / UTI 声明）
    private static func extractSupportedExtensions(from plist: [String: Any]) -> Set<String> {
        var exts = Set<String>()
        
        func insertValidExtension(_ raw: String) {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            if !clean.isEmpty && clean != "*" && clean.count <= 12 && !clean.contains("/") && !clean.contains(" ") {
                exts.insert(clean)
            }
        }
        
        // 1. 构建应用内自定义 UTI (UTExportedTypeDeclarations + UTImportedTypeDeclarations) 到扩展名的映射表
        var customUTIToExtensions = [String: [String]]()
        let declarationKeys = ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"]
        for key in declarationKeys {
            if let declarations = plist[key] as? [[String: Any]] {
                for decl in declarations {
                    guard let utiId = (decl["UTTypeIdentifier"] as? String)?.lowercased(),
                          let tagSpec = decl["UTTypeTagSpecification"] as? [String: Any] else {
                        continue
                    }
                    var declaredExts = [String]()
                    if let extArray = tagSpec["public.filename-extension"] as? [String] {
                        declaredExts.append(contentsOf: extArray)
                    } else if let extSingle = tagSpec["public.filename-extension"] as? String {
                        declaredExts.append(extSingle)
                    }
                    if !declaredExts.isEmpty {
                        customUTIToExtensions[utiId, default: []].append(contentsOf: declaredExts)
                    }
                }
            }
        }
        
        // 2. 解析 CFBundleDocumentTypes
        if let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] {
            for doc in docTypes {
                // 2a. 传统 CFBundleTypeExtensions
                if let extensions = doc["CFBundleTypeExtensions"] as? [String] {
                    for ext in extensions {
                        insertValidExtension(ext)
                    }
                }
                
                // 2b. 现代 LSItemContentTypes (UTI)
                if let contentTypes = doc["LSItemContentTypes"] as? [String] {
                    for utiStr in contentTypes {
                        let lowerUTI = utiStr.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard !lowerUTI.isEmpty else { continue }
                        
                        // 先查应用内自定义 UTI 映射
                        if let mapped = customUTIToExtensions[lowerUTI] {
                            for ext in mapped {
                                insertValidExtension(ext)
                            }
                        }
                        
                        // 再通过系统 UniformTypeIdentifiers 反解标准扩展名
                        if let utType = UTType(utiStr),
                           let utExts = utType.tags[.filenameExtension] {
                            for ext in utExts {
                                insertValidExtension(ext)
                            }
                        }
                    }
                }
            }
        }
        
        return exts
    }
    
    private static func categorize(bundleId: String, name: String, exts: Set<String>) -> AppCategory {
        let b = bundleId.lowercased()
        let n = name.lowercased()
        
        if b.contains("vscode") || b.contains("cursor") || b.contains("intellij") || b.contains("pycharm") || b.contains("xcode") || b.contains("gateway") || n.contains("code") {
            return .code
        }
        if b.contains("typora") || b.contains("obsidian") || b.contains("miaoyan") || b.contains("notegen") || (exts.contains("md") && exts.count < 10) {
            return .markdown
        }
        if b.contains("bandizip") || b.contains("archive") || b.contains("keka") || b.contains("unarchiver") || (exts.contains("7z") && exts.contains("rar")) {
            return .archive
        }
        if b.contains("wps") || b.contains("pdf") || b.contains("preview") || b.contains("xmind") || b.contains("drawio") || exts.contains("pdf") || exts.contains("docx") {
            return .office
        }
        if b.contains("chrome") || b.contains("edge") || b.contains("safari") || b.contains("firefox") || b.contains("browser") {
            return .browser
        }
        if b.contains("music") || b.contains("spotify") || b.contains("quicktime") || b.contains("iina") || b.contains("vlc") || exts.contains("mp3") || exts.contains("mp4") {
            return .media
        }
        return .utility
    }
}

// MARK: - View Model

@MainActor
final class AppViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var selectedCategory: AppCategory = .all
    @Published var selectedApp: AppInfo?
    @Published var appSearchText: String = ""
    @Published var extensionSearchText: String = ""
    @Published var extensionFilterMode: ExtensionFilterMode = .all
    
    // Extensions in currently selected app
    @Published var currentAppExtensions: [ExtensionItem] = []
    
    // Extension lookup mode
    @Published var activeTab: NavigationTab = .byApp
    @Published var targetExtQuery: String = "md"
    @Published var targetExtCandidates: [CandidateApp] = []
    @Published var targetExtCurrentDefault: (bundleId: String, name: String, icon: NSImage)?
    
    // Toast alert
    @Published var toastText: String?
    @Published var isToastSuccess: Bool = true
    
    enum NavigationTab: String, CaseIterable {
        case byApp = "应用中心"
        case byExtension = "格式直查"
    }
    
    enum ExtensionFilterMode: String, CaseIterable {
        case all = "全部"
        case common = "常用格式"
        case active = "已生效"
        case inactive = "未关联"
    }
    
    init() {
        loadData()
    }
    
    func loadData() {
        apps = AppScanner.scanAllApps()
        if let defaultPick = apps.first(where: { $0.bundleId.contains("VSCode") }) ?? apps.first {
            selectApp(defaultPick)
        }
        performExtensionLookup()
    }
    
    var filteredApps: [AppInfo] {
        apps.filter { app in
            let matchesCat = (selectedCategory == .all || app.category == selectedCategory)
            guard matchesCat else { return false }
            if appSearchText.isEmpty { return true }
            return app.name.localizedCaseInsensitiveContains(appSearchText) ||
                   app.bundleId.localizedCaseInsensitiveContains(appSearchText) ||
                   app.extensions.contains { $0.localizedCaseInsensitiveContains(appSearchText) }
        }
    }
    
    var activeExtensionsCount: Int {
        currentAppExtensions.filter { $0.isDefaultByTargetApp }.count
    }
    
    var selectedExtensionsCount: Int {
        currentAppExtensions.filter { $0.isSelected }.count
    }
    
    var filteredExtensions: [ExtensionItem] {
        currentAppExtensions.filter { item in
            let matchesSearch = extensionSearchText.isEmpty || item.ext.localizedCaseInsensitiveContains(extensionSearchText) || item.desc.localizedCaseInsensitiveContains(extensionSearchText)
            guard matchesSearch else { return false }
            switch extensionFilterMode {
            case .all: return true
            case .common: return item.isCommon
            case .active: return item.isDefaultByTargetApp
            case .inactive: return !item.isDefaultByTargetApp
            }
        }
    }
    
    func selectApp(_ app: AppInfo) {
        selectedApp = app
        reloadExtensions(preserveUserSelection: false)
    }
    
    func reloadExtensions(preserveUserSelection: Bool = false) {
        guard let app = selectedApp else { return }
        let previouslySelected = Set(currentAppExtensions.filter { $0.isSelected }.map { $0.ext })
        
        currentAppExtensions = app.extensions.map { ext in
            let uti = UTType(filenameExtension: ext)?.identifier ?? "public.data"
            let desc = UTType(filenameExtension: ext)?.localizedDescription ?? "\(ext.uppercased()) 文件"
            let def = LaunchServicesManager.shared.getCurrentDefault(for: ext)
            let isCurrent = (def?.bundleId == app.bundleId)
            let isCommon = commonExtensionSet.contains(ext.lowercased())
            let shouldSelect = preserveUserSelection ? (isCurrent || previouslySelected.contains(ext)) : isCurrent
            return ExtensionItem(
                id: ext,
                ext: ext,
                uti: uti,
                desc: desc,
                currentHandlerBundleId: def?.bundleId,
                currentHandlerName: def?.name,
                currentHandlerIcon: def?.icon,
                isDefaultByTargetApp: isCurrent,
                isSelected: shouldSelect,
                isCommon: isCommon
            )
        }
    }
    
    // 浏览器专有核心格式，防止对非浏览器应用批量操作时劫持系统默认网页浏览器
    static let webExtensions: Set<String> = ["html", "htm", "shtml", "xhtml"]
    
    func toggleAllSelection(select: Bool) {
        for i in currentAppExtensions.indices {
            let ext = currentAppExtensions[i].ext.lowercased()
            // 如果不是浏览器类应用，一键全选时默认不勾选网页核心格式（如需设置可单独手动勾选）
            if select && selectedApp?.category != .browser && Self.webExtensions.contains(ext) {
                currentAppExtensions[i].isSelected = false
            } else {
                currentAppExtensions[i].isSelected = select
            }
        }
    }
    
    func schedulePeriodicRefresh() {
        for delay in [0.8, 1.8, 3.2, 5.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.reloadExtensions(preserveUserSelection: true)
                self.performExtensionLookup()
            }
        }
    }
    
    func setSingleExtension(ext: String) {
        guard let app = selectedApp else { return }
        let ok = LaunchServicesManager.shared.setDefault(ext: ext, bundleId: app.bundleId)
        if ok {
            showToast("已请求将 .\(ext) 切换为 \(app.name)，请在系统弹窗中确认", success: true)
            reloadExtensions(preserveUserSelection: true)
            schedulePeriodicRefresh()
        } else {
            showToast("设置 .\(ext) 失败，请检查权限", success: false)
        }
    }
    
    func changeDefaultApp(for ext: String, to candidate: CandidateApp) {
        let cleanExt = ext.lowercased()
        let ok = LaunchServicesManager.shared.setDefault(ext: ext, bundleId: candidate.bundleId)
        if ok {
            showToast("已请求将 .\(ext) 默认打开程序变更为 \(candidate.name)，请在系统弹窗中确认", success: true)
            reloadExtensions(preserveUserSelection: true)
            schedulePeriodicRefresh()
        } else {
            if Self.webExtensions.contains(cleanExt) {
                showToast("变更失败：macOS 系统限制仅允许网页浏览器类应用接管 .\(ext) 格式", success: false)
            } else {
                showToast("变更 .\(ext) 打开程序失败，请检查权限", success: false)
            }
        }
    }
    
    func applySelectedExtensions() {
        guard let app = selectedApp else { return }
        let selectedItems = currentAppExtensions.filter { $0.isSelected }
        guard !selectedItems.isEmpty else {
            showToast("未勾选任何扩展名", success: false)
            return
        }
        // 仅对「已勾选但尚未生效」的增量格式发起请求，避免对已生效格式重复弹出系统确认框
        let pendingList = selectedItems.filter { !$0.isDefaultByTargetApp }.map { $0.ext }
        guard !pendingList.isEmpty else {
            showToast("所选格式均已默认生效，无需重复设置", success: true)
            return
        }
        let res = LaunchServicesManager.shared.batchSetDefault(exts: pendingList, bundleId: app.bundleId)
        showToast("已提交 \(res.success) 个新增格式切换请求，请在弹窗中确认", success: true)
        reloadExtensions(preserveUserSelection: true)
        schedulePeriodicRefresh()
    }
    
    func applyAllExtensionsForApp() {
        guard let app = selectedApp else { return }
        // 对非浏览器类应用（如代码编辑器、解压工具等），过滤掉网页格式，防止 macOS 将默认网页浏览器劫持为该编辑器
        let candidateExts: [String]
        if app.category != .browser {
            candidateExts = app.extensions.filter { !Self.webExtensions.contains($0.lowercased()) }
        } else {
            candidateExts = app.extensions
        }
        let alreadyActive = Set(currentAppExtensions.filter { $0.isDefaultByTargetApp }.map { $0.ext })
        let targetExts = candidateExts.filter { !alreadyActive.contains($0) }
        guard !targetExts.isEmpty else {
            showToast("所有目标格式均已默认生效，无需重复设置", success: true)
            return
        }
        let res = LaunchServicesManager.shared.batchSetDefault(exts: targetExts, bundleId: app.bundleId)
        showToast("已提交 \(res.success) 个格式切换请求，请在弹窗中确认", success: true)
        reloadExtensions(preserveUserSelection: true)
        schedulePeriodicRefresh()
    }
    
    // Extension search
    func performExtensionLookup() {
        let clean = targetExtQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: ".", with: "")
        guard !clean.isEmpty else { return }
        targetExtCurrentDefault = LaunchServicesManager.shared.getCurrentDefault(for: clean)
        targetExtCandidates = LaunchServicesManager.shared.getAllCandidates(for: clean)
    }
    
    func setCandidateAsDefault(candidate: CandidateApp) {
        let clean = targetExtQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: ".", with: "")
        let ok = LaunchServicesManager.shared.setDefault(ext: clean, bundleId: candidate.bundleId)
        if ok {
            showToast("已请求将 .\(clean) 默认打开程序变更为 \(candidate.name)，请在系统弹窗中确认", success: true)
            performExtensionLookup()
            if selectedApp?.bundleId == candidate.bundleId {
                reloadExtensions(preserveUserSelection: true)
            }
            schedulePeriodicRefresh()
        } else {
            showToast("变更失败", success: false)
        }
    }
    
    func showToast(_ text: String, success: Bool) {
        toastText = text
        isToastSuccess = success
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.toastText == text {
                self?.toastText = nil
            }
        }
    }
}

// MARK: - Native Design System & Visual Materials

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .followsWindowActiveState

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct ToastBanner: View {
    let text: String
    let success: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(success ? .green : .orange)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        )
    }
}

// MARK: - Auto Update Sheet View

struct UpdateSheetView: View {
    @ObservedObject var updater = UpdateManager.shared
    let release: ReleaseInfo
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("发现新版本")
                            .font(.system(size: 16, weight: .bold))
                        Text(release.tagName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                    Text("当前安装版本: v\(updater.currentVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Release Notes Box
            VStack(alignment: .leading, spacing: 6) {
                Text("更新日志")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(release.body.isEmpty ? "包含性能提升与常规问题修复。" : release.body)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 140)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            
            // Download Progress / Status
            if updater.isDownloading {
                VStack(spacing: 6) {
                    ProgressView(value: updater.downloadProgress)
                        .progressViewStyle(.linear)
                    Text(updater.statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else if !updater.statusMessage.isEmpty {
                Text(updater.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("稍后提醒") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("在浏览器中打开") {
                    if let url = URL(string: release.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                if release.downloadUrl != nil {
                    Button(action: {
                        updater.startAutoUpdate(release: release)
                    }) {
                        HStack(spacing: 5) {
                            if updater.isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(updater.isDownloading ? "正在更新..." : "一键更新并重启")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updater.isDownloading)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

// MARK: - Main Application Window

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @ObservedObject private var updater = UpdateManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern macOS Unified Navigation & Header Bar
            HStack(spacing: 16) {
                // Brand Title & Status Indicator
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("Default App")
                                .font(.system(size: 13, weight: .bold))
                            Text("v\(updater.currentVersion)")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(3.5)
                        }
                        Text("macOS 文件关联架构管家")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Centered Segmented Navigation Tab
                Picker("", selection: $vm.activeTab) {
                    ForEach(AppViewModel.NavigationTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                
                Spacer()
                
                // Status Counter & Dynamic Update Pill
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(vm.apps.count) 款应用就绪")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    
                    // Dynamic Update Capsule (appears only when update is available)
                    if let release = updater.availableRelease {
                        Button(action: {
                            updater.showUpdateSheet = true
                        }) {
                            HStack(spacing: 5) {
                                if updater.isDownloading {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                Text(updater.isDownloading ? "更新中..." : "新版本 \(release.tagName)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .help("检测到新版本 \(release.tagName)，点击查看更新日志并一键更新")
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(nsColor: .separatorColor).opacity(0.5)),
                alignment: .bottom
            )
            .overlay(alignment: .top) {
                if let toast = vm.toastText {
                    ToastBanner(text: toast, success: vm.isToastSuccess)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            // Core View Area
            if vm.activeTab == .byApp {
                AppManagementView(vm: vm)
            } else {
                ExtensionLookupView(vm: vm)
            }
        }
        .frame(minWidth: 920, minHeight: 640)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                updater.checkForUpdates(isUserInitiated: false)
            }
        }
        .sheet(isPresented: $updater.showUpdateSheet) {
            if let rel = updater.availableRelease {
                UpdateSheetView(release: rel) {
                    updater.showUpdateSheet = false
                }
            }
        }
    }
}

// MARK: - App Management Master-Detail View

struct PreciseSplitView<Left: View, Right: View>: NSViewRepresentable {
    let left: Left
    let right: Right
    let defaultWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let leftHost = NSHostingView(rootView: left)
        let rightHost = NSHostingView(rootView: right)

        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)
        splitView.delegate = context.coordinator

        DispatchQueue.main.async {
            splitView.setPosition(defaultWidth, ofDividerAt: 0)
        }
        return splitView
    }

    func updateNSView(_ nsView: NSSplitView, context: Context) {
        if let leftHost = nsView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = left
        }
        if nsView.arrangedSubviews.count > 1,
           let rightHost = nsView.arrangedSubviews[1] as? NSHostingView<Right> {
            rightHost.rootView = right
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(minWidth: minWidth, maxWidth: maxWidth)
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        let minWidth: CGFloat
        let maxWidth: CGFloat
        init(minWidth: CGFloat, maxWidth: CGFloat) {
            self.minWidth = minWidth
            self.maxWidth = maxWidth
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            return minWidth
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            return maxWidth
        }

        func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview subview: NSView) -> Bool {
            return subview != splitView.arrangedSubviews.first
        }
    }
}

struct AppManagementView: View {
    @ObservedObject var vm: AppViewModel
    
    var body: some View {
        PreciseSplitView(
            left: leftPanel,
            right: rightPanel,
            defaultWidth: 285,
            minWidth: 250,
            maxWidth: 350
        )
    }
    
    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Sidebar Controls: Category Pop-up & Compact Search
            VStack(spacing: 8) {
                // Category Filter Menu
                Menu {
                    ForEach(AppCategory.allCases) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.selectedCategory = cat
                            }
                        } label: {
                            HStack {
                                Label(cat.rawValue, systemImage: cat.iconName)
                                if vm.selectedCategory == cat {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.selectedCategory.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(vm.selectedCategory.rawValue)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .menuStyle(.borderlessButton)
                
                // Native-styled Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("筛选应用名称或扩展名...", text: $vm.appSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                    if !vm.appSearchText.isEmpty {
                        Button(action: { vm.appSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            // List Header Summary
            HStack {
                Text("\(vm.filteredApps.count) 款应用")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            
            Divider()
                .opacity(0.6)
            
            // App List with Native Vibrancy
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.filteredApps) { app in
                        AppCardRow(
                            app: app,
                            isSelected: vm.selectedApp?.id == app.id
                        )
                        .onTapGesture {
                            vm.selectApp(app)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
    
    @ViewBuilder
    private var rightPanel: some View {
        if let app = vm.selectedApp {
            AppDetailInspector(app: app, vm: vm)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.system(size: 38))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("从左侧选择一款应用，开始检视和配置其文件关联")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct AppCardRow: View {
    let app: AppInfo
    let isSelected: Bool
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text(app.bundleId)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // Format count tag
            Text("\(app.extensions.count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isSelected
                        ? Color.white.opacity(0.25)
                        : Color.primary.opacity(0.06)
                )
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(4.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor
                        : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - App Detail Inspector

struct AppDetailInspector: View {
    let app: AppInfo
    @ObservedObject var vm: AppViewModel
    @State private var showConfirmAllDialog: Bool = false
    
    var completionRatio: Double {
        guard !app.extensions.isEmpty else { return 0 }
        return Double(vm.activeExtensionsCount) / Double(app.extensions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // App Hero Dashboard Card
            HStack(alignment: .top, spacing: 14) {
                // Large App Icon
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                
                // App Information & Metric Pills
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        
                        Text(app.category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06))
                            .foregroundColor(.secondary)
                            .cornerRadius(4.5)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 6) {
                        Text(app.bundleId)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(app.bundleId, forType: .string)
                            vm.showToast("已复制 Bundle ID", success: true)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("点击复制 Bundle ID")
                    }
                    
                    // Status Strip (Strictly 1 line, never wrapped)
                    HStack(spacing: 8) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                            Text("支持 \(app.extensions.count) 格式")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(completionRatio >= 1.0 ? Color.green : (completionRatio > 0 ? Color.orange : Color.secondary))
                                .frame(width: 6, height: 6)
                            Text("默认生效: \(vm.activeExtensionsCount)/\(app.extensions.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(completionRatio >= 1.0 ? .green : .primary)
                            Text("(\(Int(completionRatio * 100))%)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer(minLength: 12)
                
                // Action Cluster (Restored Clean 2-Tier: Primary on top, helpers on bottom)
                VStack(alignment: .trailing, spacing: 7) {
                    // Primary Action: Save Checked Associations
                    Button(action: {
                        if vm.selectedExtensionsCount > 0 {
                            vm.applySelectedExtensions()
                        } else {
                            vm.showToast("请先在下方勾选需要绑定的格式", success: false)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11.5))
                            Text("保存勾选配置")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            
                            // Badge with count
                            Text("\(vm.selectedExtensionsCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5.5)
                                .padding(.vertical, 1.5)
                                .background(
                                    vm.selectedExtensionsCount > 0
                                        ? Color.white.opacity(0.25)
                                        : Color.primary.opacity(0.06)
                                )
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                .fill(vm.selectedExtensionsCount > 0 ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                        .foregroundColor(vm.selectedExtensionsCount > 0 ? .white : .secondary)
                        .shadow(color: vm.selectedExtensionsCount > 0 ? Color.accentColor.opacity(0.25) : .clear, radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    
                    // Secondary Actions Row
                    HStack(spacing: 7) {
                        Button("全选") { vm.toggleAllSelection(select: true) }
                            .font(.system(size: 11, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                        
                        Button("取消全选") { vm.toggleAllSelection(select: false) }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        // One-Click Bind All Button
                        Button(action: { showConfirmAllDialog = true }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("一键绑定所有 (\(app.extensions.count))")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .alert(isPresented: $showConfirmAllDialog) {
                            Alert(
                                title: Text("确认一键绑定？"),
                                message: Text("是否将 \(app.name) 支持的全部 \(app.extensions.count) 个文件格式全部设置为默认用它打开？"),
                                primaryButton: .default(Text("确认绑定")) {
                                    vm.applyAllExtensionsForApp()
                                },
                                secondaryButton: .cancel(Text("取消"))
                            )
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
                .opacity(0.6)
            
            // Sub-Toolbar: Segmented Filter & Live Search
            HStack(spacing: 12) {
                // Filter Segmented Controls
                HStack(spacing: 2) {
                    ForEach(AppViewModel.ExtensionFilterMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.extensionFilterMode = mode
                            }
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: vm.extensionFilterMode == mode ? .semibold : .regular))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3.5)
                                .background(
                                    vm.extensionFilterMode == mode
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear
                                )
                                .foregroundColor(vm.extensionFilterMode == mode ? .accentColor : .primary)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                Spacer()
                
                // Search field & Refresh Action
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10.5))
                        TextField("快速过滤格式...", text: $vm.extensionSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 130)
                        if !vm.extensionSearchText.isEmpty {
                            Button(action: { vm.extensionSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(5.5)
                    
                    // Refresh Button
                    Button(action: {
                        vm.reloadExtensions()
                        vm.showToast("已刷新格式默认状态", success: true)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(5.5)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(5.5)
                    }
                    .buttonStyle(.plain)
                    .help("重新拉取系统最新默认状态")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
                .opacity(0.6)
            
            // Extensions Dynamic List
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach($vm.currentAppExtensions) { $item in
                        if vm.extensionSearchText.isEmpty || item.ext.localizedCaseInsensitiveContains(vm.extensionSearchText) || item.desc.localizedCaseInsensitiveContains(vm.extensionSearchText) {
                            if vm.extensionFilterMode == .all ||
                               (vm.extensionFilterMode == .common && item.isCommon) ||
                               (vm.extensionFilterMode == .active && item.isDefaultByTargetApp) ||
                               (vm.extensionFilterMode == .inactive && !item.isDefaultByTargetApp) {
                                ExtensionRowItem(
                                    item: $item,
                                    onSelectCandidate: { candidate in
                                        vm.changeDefaultApp(for: item.ext, to: candidate)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - Native Auto Updater (GitHub Releases)

struct ReleaseInfo: Decodable {
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let htmlUrl: String
    let downloadUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
        case assets
    }
    
    struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: String
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = (try? container.decode(String.self, forKey: .name)) ?? tagName
        body = (try? container.decode(String.self, forKey: .body)) ?? ""
        publishedAt = (try? container.decode(String.self, forKey: .publishedAt)) ?? ""
        htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        
        let assets = (try? container.decode([Asset].self, forKey: .assets)) ?? []
        let matched = assets.first { $0.name.lowercased().hasSuffix(".dmg") } ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }
        downloadUrl = matched?.browserDownloadUrl
    }
}

@MainActor
final class UpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = UpdateManager()
    
    @Published var isChecking: Bool = false
    @Published var availableRelease: ReleaseInfo?
    @Published var showUpdateSheet: Bool = false
    
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""
    
    private let repoOwner = "wood02"
    private let repoName = "DefaultApp"
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
    }
    
    func checkForUpdates(isUserInitiated: Bool, onToast: ((String, Bool) -> Void)? = nil) {
        guard !isChecking, !isDownloading else { return }
        isChecking = true
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("DefaultApp-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                
                guard let data = data, error == nil,
                      let release = try? JSONDecoder().decode(ReleaseInfo.self, from: data) else {
                    if isUserInitiated {
                        onToast?("检查更新失败，请检查网络连接", false)
                    }
                    return
                }
                
                if self.isVersion(release.tagName, greaterThan: self.currentVersion) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        self.availableRelease = release
                    }
                    if isUserInitiated {
                        self.showUpdateSheet = true
                    }
                } else {
                    withAnimation {
                        self.availableRelease = nil
                    }
                    if isUserInitiated {
                        onToast?("当前已是最新版本 (v\(self.currentVersion))", true)
                    }
                }
            }
        }.resume()
    }
    
    func startAutoUpdate(release: ReleaseInfo) {
        guard let downloadUrlString = release.downloadUrl, let url = URL(string: downloadUrlString) else {
            if let webUrl = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(webUrl)
            }
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = "正在下载更新包..."
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    // URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        Task { @MainActor in
            self.downloadProgress = progress
            self.statusMessage = String(format: "正在下载新版本... %.0f%%", progress * 100)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDmgPath = "/tmp/DefaultApp_update.dmg"
        try? FileManager.default.removeItem(atPath: tempDmgPath)
        try? FileManager.default.copyItem(at: location, to: URL(fileURLWithPath: tempDmgPath))
        
        Task { @MainActor in
            self.statusMessage = "下载完成，正在自动安装并准备重启..."
            self.installAndRelaunch(dmgPath: tempDmgPath)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isDownloading = false
                self.statusMessage = "下载失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func installAndRelaunch(dmgPath: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            set -e
            MOUNT_DIR="/tmp/DefaultApp_mount"
            rm -rf "$MOUNT_DIR"
            mkdir -p "$MOUNT_DIR"
            hdiutil attach "\(dmgPath)" -nobrowse -mountpoint "$MOUNT_DIR" -quiet
            
            TARGET_APP="/Applications/Default App.app"
            if [ -d "$MOUNT_DIR/Default App.app" ]; then
                killall -9 DefaultApp 2>/dev/null || true
                rm -rf "$TARGET_APP"
                cp -R "$MOUNT_DIR/Default App.app" "$TARGET_APP"
                codesign -fs - --deep "$TARGET_APP" 2>/dev/null || true
                hdiutil detach "$MOUNT_DIR" -force -quiet || true
                rm -rf "\(dmgPath)" "$MOUNT_DIR"
                open "$TARGET_APP"
                exit 0
            else
                hdiutil detach "$MOUNT_DIR" -force -quiet || true
                exit 1
            fi
            """
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", script]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.statusMessage = "自动安装失败，建议前往浏览器下载"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.statusMessage = "安装失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func isVersion(_ newVer: String, greaterThan currentVer: String) -> Bool {
        func parse(_ str: String) -> [Int] {
            let clean = str.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
            return clean.split(separator: ".").compactMap { Int($0) }
        }
        let v1 = parse(newVer)
        let v2 = parse(currentVer)
        let count = max(v1.count, v2.count)
        for i in 0..<count {
            let p1 = i < v1.count ? v1[i] : 0
            let p2 = i < v2.count ? v2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}

// MARK: - Native Menu Helper for Candidate Apps

final class MenuActionTarget: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    @objc func trigger() {
        action()
    }
}

final class NativeAppMenuPresenter {
    static func popUpAppMenu(
        for ext: String,
        onSelectCandidate: @escaping (CandidateApp) -> Void
    ) {
        let menu = NSMenu(title: "Choose App")
        
        let headerItem = NSMenuItem(title: "将 .\(ext) 默认打开程序切换为：", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        let candidates = LaunchServicesManager.shared.getAllCandidates(for: ext)
        if candidates.isEmpty {
            let emptyItem = NSMenuItem(title: "未找到支持此格式的其它候选应用", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for candidate in candidates {
                let item = NSMenuItem(
                    title: candidate.name,
                    action: #selector(MenuActionTarget.trigger),
                    keyEquivalent: ""
                )
                
                // 规范设置 16x16 菜单图标
                let iconCopy = candidate.icon.copy() as! NSImage
                iconCopy.size = NSSize(width: 16, height: 16)
                item.image = iconCopy
                
                if candidate.isCurrentDefault {
                    item.state = .on
                }
                
                let target = MenuActionTarget {
                    onSelectCandidate(candidate)
                }
                item.target = target
                item.representedObject = target
                menu.addItem(item)
            }
        }
        
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            menu.popUp(positioning: nil, at: mouseLocation, in: contentView)
        }
    }
}

struct ExtensionRowItem: View {
    @Binding var item: ExtensionItem
    let onSelectCandidate: (CandidateApp) -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Selection Checkbox
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
            
            // 2. Monospace Extension Badge
            Text("." + item.ext)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 82, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(item.isDefaultByTargetApp ? Color.green.opacity(0.12) : Color.accentColor.opacity(0.10))
                )
            
            // 3. Format Description & UTI Hierarchy (Adaptive width, perfectly aligned)
            VStack(alignment: .leading, spacing: 1.5) {
                Text(item.desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(item.uti)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 12)
            
            // 4. Interactive App Selector Pill (Single source of truth)
            Button(action: {
                NativeAppMenuPresenter.popUpAppMenu(for: item.ext, onSelectCandidate: onSelectCandidate)
            }) {
                HStack(spacing: 6) {
                    if let icon = item.currentHandlerIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    
                    Text(item.currentHandlerName ?? "系统默认")
                        .font(.system(size: 11.5, weight: item.isDefaultByTargetApp ? .semibold : .medium))
                        .foregroundColor(item.isDefaultByTargetApp ? .green : .primary)
                        .lineLimit(1)
                    
                    if item.isDefaultByTargetApp {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(item.isDefaultByTargetApp ? .green.opacity(0.8) : .secondary.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    item.isDefaultByTargetApp
                        ? Color.green.opacity(0.08)
                        : Color.primary.opacity(0.04)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(item.isDefaultByTargetApp ? Color.green.opacity(0.28) : Color.primary.opacity(0.08), lineWidth: 0.8)
                )
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("点击快速选择本机其它支持该格式的应用接管")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    item.isSelected
                        ? Color.accentColor.opacity(0.05)
                        : (isHovered ? Color.primary.opacity(0.025) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Extension Reverse Lookup View

struct ExtensionLookupView: View {
    @ObservedObject var vm: AppViewModel
    
    let quickPills = [
        "md", "py", "json", "js", "ts", "html", "pdf", "docx", "xlsx",
        "zip", "7z", "rar", "tar", "iso", "png", "jpg", "mp4", "mp3", "db"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Spotlight-Style Search & Quick Jump Panel
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("查询扩展名:")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 4) {
                        Text(".")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        TextField("例如 md, pdf, zip, py...", text: $vm.targetExtQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13.5, design: .monospaced))
                            .onSubmit {
                                vm.performExtensionLookup()
                            }
                        if !vm.targetExtQuery.isEmpty {
                            Button(action: { vm.targetExtQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                    )
                    .frame(width: 240)
                    
                    Button("立即反查") {
                        vm.performExtensionLookup()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    
                    Spacer()
                }
                
                // Quick Jump presets
                HStack(spacing: 6) {
                    Text("常见格式:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quickPills, id: \.self) { ext in
                                Button("." + ext) {
                                    vm.targetExtQuery = ext
                                    vm.performExtensionLookup()
                                }
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    vm.targetExtQuery.lowercased() == ext ?
                                    Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04)
                                )
                                .foregroundColor(vm.targetExtQuery.lowercased() == ext ? .accentColor : .primary)
                                .cornerRadius(5)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            
            Divider()
                .opacity(0.6)
            
            // Format Overview Hero
            HStack(spacing: 16) {
                Text("." + vm.targetExtQuery.replacingOccurrences(of: ".", with: ""))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前系统默认打开程序")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if let def = vm.targetExtCurrentDefault {
                        HStack(spacing: 8) {
                            Image(nsImage: def.icon)
                                .resizable()
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                            Text(def.name)
                                .font(.system(size: 15, weight: .bold))
                            Text("(\(def.bundleId))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未找到注册的默认应用")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
                .opacity(0.6)
            
            // Candidate Applications Grid/List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("本机已安装且支持此格式的候选应用 (\(vm.targetExtCandidates.count))")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.targetExtCandidates) { candidate in
                            HStack(spacing: 12) {
                                Image(nsImage: candidate.icon)
                                    .resizable()
                                    .frame(width: 34, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 7.5, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(candidate.name)
                                            .font(.system(size: 13.5, weight: .medium))
                                        if candidate.isCurrentDefault {
                                            Text("✓ 当前默认")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.12))
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(candidate.bundleId)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if candidate.isCurrentDefault {
                                    Text("正在作为默认")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 8)
                                } else {
                                    Button("设为默认打开应用") {
                                        vm.setCandidateAsDefault(candidate: candidate)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(candidate.isCurrentDefault ? Color.green.opacity(0.04) : Color.primary.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(candidate.isCurrentDefault ? Color.green.opacity(0.2) : Color.primary.opacity(0.05), lineWidth: 0.8)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - App Main

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct DefaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                }
                .keyboardShortcut("U", modifiers: [.command])
            }
        }
    }
}
