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
        let fm = FileManager.default
        
        for dir in searchPaths {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for item in items where item.pathExtension == "app" {
                let plistURL = item.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let bundleId = plist["CFBundleIdentifier"] as? String,
                      !bundleId.isEmpty,
                      !seenBundleIds.contains(bundleId) else {
                    continue
                }
                
                var exts = Set<String>()
                if let docTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] {
                    for doc in docTypes {
                        if let extensions = doc["CFBundleTypeExtensions"] as? [String] {
                            for ext in extensions {
                                let clean = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if !clean.isEmpty && clean != "*" && clean.count <= 12 {
                                    exts.insert(clean)
                                }
                            }
                        }
                    }
                }
                
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
        reloadExtensions()
    }
    
    func reloadExtensions() {
        guard let app = selectedApp else { return }
        currentAppExtensions = app.extensions.map { ext in
            let uti = UTType(filenameExtension: ext)?.identifier ?? "public.data"
            let desc = UTType(filenameExtension: ext)?.localizedDescription ?? "\(ext.uppercased()) 文件"
            let def = LaunchServicesManager.shared.getCurrentDefault(for: ext)
            let isCurrent = (def?.bundleId == app.bundleId)
            let isCommon = commonExtensionSet.contains(ext.lowercased())
            return ExtensionItem(
                id: ext,
                ext: ext,
                uti: uti,
                desc: desc,
                currentHandlerBundleId: def?.bundleId,
                currentHandlerName: def?.name,
                currentHandlerIcon: def?.icon,
                isDefaultByTargetApp: isCurrent,
                isSelected: isCurrent,
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
                self?.reloadExtensions()
            }
        }
    }
    
    func setSingleExtension(ext: String) {
        guard let app = selectedApp else { return }
        let ok = LaunchServicesManager.shared.setDefault(ext: ext, bundleId: app.bundleId)
        if ok {
            showToast("已请求将 .\(ext) 切换为 \(app.name)，请在系统弹窗中确认", success: true)
            reloadExtensions()
            schedulePeriodicRefresh()
        } else {
            showToast("设置 .\(ext) 失败，请检查权限", success: false)
        }
    }
    
    func applySelectedExtensions() {
        guard let app = selectedApp else { return }
        let selectedList = currentAppExtensions.filter { $0.isSelected }.map { $0.ext }
        guard !selectedList.isEmpty else {
            showToast("未勾选任何扩展名", success: false)
            return
        }
        let res = LaunchServicesManager.shared.batchSetDefault(exts: selectedList, bundleId: app.bundleId)
        showToast("已提交 \(res.success) 个格式切换请求，请在弹窗中确认", success: true)
        reloadExtensions()
        schedulePeriodicRefresh()
    }
    
    func applyAllExtensionsForApp() {
        guard let app = selectedApp else { return }
        // 对非浏览器类应用（如代码编辑器、解压工具等），过滤掉网页格式，防止 macOS 将默认网页浏览器劫持为该编辑器
        let targetExts: [String]
        if app.category != .browser {
            targetExts = app.extensions.filter { !Self.webExtensions.contains($0.lowercased()) }
        } else {
            targetExts = app.extensions
        }
        let res = LaunchServicesManager.shared.batchSetDefault(exts: targetExts, bundleId: app.bundleId)
        showToast("已提交全部 \(res.success) 个格式切换请求，请在弹窗中确认", success: true)
        reloadExtensions()
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
            showToast("已将 .\(clean) 默认打开程序变更为 \(candidate.name)", success: true)
            performExtensionLookup()
            if selectedApp?.bundleId == candidate.bundleId {
                reloadExtensions()
            }
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

// MARK: - Modern Design System Components

struct AppTheme {
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.25, green: 0.38, blue: 0.95), Color(red: 0.12, green: 0.58, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let emeraldGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.75, blue: 0.50), Color(red: 0.02, green: 0.65, blue: 0.40)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

// MARK: - Main Application Window

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Command Bar
            HStack(spacing: 16) {
                // Brand Title & Status
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default App")
                            .font(.system(size: 14, weight: .bold))
                        Text("macOS 文件关联架构管家")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Mode Switcher Segment
                HStack(spacing: 4) {
                    ForEach(AppViewModel.NavigationTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                vm.activeTab = tab
                            }
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: vm.activeTab == tab ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(
                                    vm.activeTab == tab ?
                                    Color.primary.opacity(0.12) : Color.clear
                                )
                                .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(9)
                
                Spacer()
                
                // Status / App Count
                Text("\(vm.apps.count) 款应用已就绪")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(alignment: .top) {
                if let toast = vm.toastText {
                    ToastBanner(text: toast, success: vm.isToastSuccess)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            Divider()
            
            // Core View Area
            if vm.activeTab == .byApp {
                AppManagementView(vm: vm)
            } else {
                ExtensionLookupView(vm: vm)
            }
        }
        .frame(minWidth: 920, minHeight: 640)
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
            defaultWidth: 280,
            minWidth: 250,
            maxWidth: 330
        )
    }
    
    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Category Carousel Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AppCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: vm.selectedCategory == cat ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                vm.selectedCategory == cat ?
                                Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04)
                            )
                            .foregroundColor(vm.selectedCategory == cat ? .accentColor : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("筛选应用名称或扩展名...", text: $vm.appSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !vm.appSearchText.isEmpty {
                    Button(action: { vm.appSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // App List
            ScrollView {
                LazyVStack(spacing: 3) {
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
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
    
    @ViewBuilder
    private var rightPanel: some View {
        if let app = vm.selectedApp {
            AppDetailInspector(app: app, vm: vm)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 38))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("从左侧选择一款应用，开始检视和配置其文件关联")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct AppCardRow: View {
    let app: AppInfo
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .lineLimit(1)
                
                Text(app.bundleId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Format count badge
            Text("\(app.extensions.count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .cornerRadius(6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - App Detail Inspector

struct AppDetailInspector: View {
    let app: AppInfo
    @ObservedObject var vm: AppViewModel
    @State private var showConfirmAllDialog: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // App Hero Showcase
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        
                        Text(app.category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)
                    }
                    
                    Text(app.bundleId)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Text("支持格式: \(app.extensions.count) 个")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("已默认生效: \(vm.activeExtensionsCount)/\(app.extensions.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Primary Action Cluster (恢复最初紧凑布局，与 Code 标题顶对齐)
                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: {
                        if vm.selectedExtensionsCount > 0 {
                            vm.applySelectedExtensions()
                        } else {
                            vm.showToast("请先在下方勾选需要绑定的格式", success: false)
                        }
                    }) {
                        HStack(spacing: 7) {
                            Text("保存勾选配置")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(vm.selectedExtensionsCount > 0 ? Color.primary : Color.secondary)
                            
                            // 右侧数量药丸
                            Text("\(vm.selectedExtensionsCount)")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(vm.selectedExtensionsCount > 0 ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                        .fill(vm.selectedExtensionsCount > 0 ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color.primary.opacity(vm.selectedExtensionsCount > 0 ? 0.16 : 0.08), lineWidth: 1.1)
                                )
                                .shadow(color: .black.opacity(vm.selectedExtensionsCount > 0 ? 0.05 : 0.0), radius: 2.5, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 次级辅助条
                    HStack(spacing: 10) {
                        Button("全选") { vm.toggleAllSelection(select: true) }
                            .font(.system(size: 11, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        
                        Button("取消全选") { vm.toggleAllSelection(select: false) }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        // 次级按钮：一键绑定所有格式
                        Button(action: { showConfirmAllDialog = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("一键绑定所有 (\(app.extensions.count))")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
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
                }
            }
            .padding(18)
            .background(
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            
            Divider()
            
            // Sub-Toolbar (Filter Pills + Search)
            HStack(spacing: 12) {
                // Filter pills
                HStack(spacing: 4) {
                    ForEach(AppViewModel.ExtensionFilterMode.allCases, id: \.self) { mode in
                        Button(action: { vm.extensionFilterMode = mode }) {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: vm.extensionFilterMode == mode ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(vm.extensionFilterMode == mode ? Color.primary.opacity(0.12) : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(7)
                
                Spacer()
                
                // Search field + Refresh Button
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    
                    // Compact Refresh Icon Button
                    Button(action: {
                        vm.reloadExtensions()
                        vm.showToast("已刷新格式默认状态", success: true)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("手动重新拉取系统最新默认状态")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            
            Divider()
            
            // Extensions Dynamic List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach($vm.currentAppExtensions) { $item in
                        if vm.extensionSearchText.isEmpty || item.ext.localizedCaseInsensitiveContains(vm.extensionSearchText) || item.desc.localizedCaseInsensitiveContains(vm.extensionSearchText) {
                            if vm.extensionFilterMode == .all ||
                               (vm.extensionFilterMode == .common && item.isCommon) ||
                               (vm.extensionFilterMode == .active && item.isDefaultByTargetApp) ||
                               (vm.extensionFilterMode == .inactive && !item.isDefaultByTargetApp) {
                                ExtensionRowItem(item: $item, onApplySingle: {
                                    vm.setSingleExtension(ext: item.ext)
                                })
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

struct ExtensionRowItem: View {
    @Binding var item: ExtensionItem
    let onApplySingle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
            
            // Monospace Extension Tag
            Text("." + item.ext)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 70, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(5)
            
            // Description
            VStack(alignment: .leading, spacing: 1) {
                Text(item.desc)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(item.uti)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 170, alignment: .leading)
            
            // Current System Default Status
            HStack(spacing: 6) {
                if let icon = item.currentHandlerIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("当前默认: \(item.currentHandlerName ?? "系统默认")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status or Set Button
            if item.isDefaultByTargetApp {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("当前生效")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
            } else {
                Button("设为默认") {
                    onApplySingle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.isDefaultByTargetApp ? Color.green.opacity(0.04) : Color.primary.opacity(0.02))
        )
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
            // Search & Quick Jump Panel
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("输入扩展名:")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 4) {
                        Text(".")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        TextField("例如 md, pdf, zip, py...", text: $vm.targetExtQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .onSubmit {
                                vm.performExtensionLookup()
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .frame(width: 220)
                    
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
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    vm.targetExtQuery.lowercased() == ext ?
                                    Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04)
                                )
                                .foregroundColor(vm.targetExtQuery.lowercased() == ext ? .accentColor : .primary)
                                .cornerRadius(6)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Format Overview Hero
            HStack(spacing: 16) {
                Text("." + vm.targetExtQuery.replacingOccurrences(of: ".", with: ""))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.primaryGradient.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前系统默认打开程序")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if let def = vm.targetExtCurrentDefault {
                        HStack(spacing: 8) {
                            Image(nsImage: def.icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
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
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            Divider()
            
            // Candidate Applications Grid/List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("本机已安装且支持此格式的候选应用 (\(vm.targetExtCandidates.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.targetExtCandidates) { candidate in
                            HStack(spacing: 12) {
                                Image(nsImage: candidate.icon)
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(candidate.name)
                                            .font(.system(size: 14, weight: .medium))
                                        if candidate.isCurrentDefault {
                                            Text("✓ 当前默认")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15))
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
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 8)
                                } else {
                                    Button("设为此应用打开") {
                                        vm.setCandidateAsDefault(candidate: candidate)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(candidate.isCurrentDefault ? Color.green.opacity(0.04) : Color.primary.opacity(0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(candidate.isCurrentDefault ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
            }
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
        }
    }
}
