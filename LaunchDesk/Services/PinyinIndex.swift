import Foundation

/// 中文拼音搜索索引
///
/// 实现思路：
/// 1. 用 CFStringTransform 把含中文的 App 名转成全拼（如 "微信" -> "wei xin"）
/// 2. 抽取首字母（"wx"）
/// 3. 命中规则：
///    - 英文子串匹配（最高优先级）
///    - 全拼无空格匹配（"weixin"）
///    - 首字母前缀匹配（"wx"）
struct PinyinIndex {
    /// 单条索引项
    struct Entry {
        let appID: String
        let name: String           // 原名（小写）
        let fullPinyin: String     // "wei xin"
        let fullPinyinNoSpace: String  // "weixin"
        let initials: String       // "wx"
    }

    private(set) var entries: [Entry] = []

    /// 重建索引
    mutating func rebuild(apps: [AppItem]) {
        entries = apps.map { app in
            let lowered = app.name.lowercased()
            let full = Self.toPinyin(app.name)
            let initials = Self.initials(of: app.name)
            return Entry(appID: app.id,
                         name: lowered,
                         fullPinyin: full,
                         fullPinyinNoSpace: full.replacingOccurrences(of: " ", with: ""),
                         initials: initials)
        }
    }

    /// 搜索
    func search(_ raw: String) -> [String] /* appIDs */ {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        // 给每个匹配项打分，按分数排序
        struct Hit { let appID: String; let score: Int; let name: String }
        var hits: [Hit] = []

        for e in entries {
            var best: Int? = nil

            // 名称完全匹配 -> 100
            if e.name == q { best = 100 }
            // 名称前缀 -> 80
            else if e.name.hasPrefix(q) { best = 80 }
            // 名称包含 -> 60
            else if e.name.contains(q) { best = 60 }
            // 首字母完全匹配 -> 70（"wx" -> 微信）
            else if !e.initials.isEmpty, e.initials == q { best = max(best ?? 0, 70) }
            // 首字母前缀 -> 55
            else if !e.initials.isEmpty, e.initials.hasPrefix(q) { best = max(best ?? 0, 55) }
            // 全拼前缀（无空格）-> 50
            else if !e.fullPinyinNoSpace.isEmpty, e.fullPinyinNoSpace.hasPrefix(q) { best = max(best ?? 0, 50) }
            // 全拼包含（无空格）-> 40
            else if !e.fullPinyinNoSpace.isEmpty, e.fullPinyinNoSpace.contains(q) { best = max(best ?? 0, 40) }
            // 全拼任一段前缀（"wei x" 命中 "微信"）-> 35
            else if e.fullPinyin.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { best = max(best ?? 0, 35) }

            if let s = best { hits.append(Hit(appID: e.appID, score: s, name: e.name)) }
        }

        hits.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        return hits.map(\.appID)
    }

    // MARK: - 拼音工具
    /// 转换为带空格全拼，例如 "微信PC版" -> "wei xin pc ban"
    static func toPinyin(_ s: String) -> String {
        let mu = NSMutableString(string: s) as CFMutableString
        // 中文 -> 拉丁拼音（带声调）
        CFStringTransform(mu, nil, kCFStringTransformToLatin, false)
        // 去掉声调音标
        CFStringTransform(mu, nil, kCFStringTransformStripCombiningMarks, false)
        let lower = (mu as String).lowercased()
        // 把多余空白合并成单空格
        let collapsed = lower
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    /// 抽取首字母 "微信PC版" -> "wxpcb"
    static func initials(of s: String) -> String {
        let p = toPinyin(s)
        let parts = p.split(separator: " ")
        return parts.compactMap { $0.first.map(String.init) }.joined()
    }
}
