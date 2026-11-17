//
//  App.swift  —— 钢琴跟弹 · iOS 单文件版本
//  由 8 个源文件合并而成，供 GitHub Actions 云端编译使用。
//  用法：整个内容作为一个 App.swift 上传到仓库根目录即可。
//

// ============================================================
//  合并自 Sources/App.swift
// ============================================================

import SwiftUI

@main
struct PianoFollowApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}


// ============================================================
//  合并自 Sources/Models.swift
// ============================================================

import Foundation
import CoreGraphics

struct RawNote {
    var beat: Double
    var midis: [Int]
    var dur: Double
}

struct RawMeasure {
    var chord: String
    var rh: [RawNote]
    var lh: [RawNote]
}

enum PracticeMode: String, CaseIterable {
    case practice = "练习"
    case free = "自由"
}

enum CellState: String {
    case idle, hit, wrong, miss
}

struct Cell {
    var staff: String          // "rh" / "lh"
    var midis: [Int]
    var dur: Double
    var hitMidis: Set<Int> = []
    var state: CellState = .idle

    // 和弦要逐个音收齐才算完成
    var done: Bool { midis.allSatisfy { hitMidis.contains($0) } }
}

struct Group: Identifiable {
    var id: Int
    var measure: Int
    var beatIn: Double
    var cells: [Cell]
    var state: CellState = .idle
    var allDone: Bool { cells.allSatisfy { $0.done } }
    var midis: [Int] { cells.flatMap { $0.midis } }
}

// MARK: - 内置练习曲：12 小节，4/4，80 BPM
enum PieceData {
    static let builtin: [RawMeasure] = [
        RawMeasure(chord: "C",  rh: n([(0, [60]), (0.5, [64]), (1, [67]), (1.5, [72]), (2, [67]), (2.5, [64]), (3, [60]), (3.5, [64])]), lh: n([(0, [48]), (2, [55])])),
        RawMeasure(chord: "Am", rh: n([(0, [60]), (0.5, [64]), (1, [69]), (1.5, [72]), (2, [69]), (2.5, [64]), (3, [60]), (3.5, [64])]), lh: n([(0, [45]), (2, [52])])),
        RawMeasure(chord: "F",  rh: n([(0, [60]), (0.5, [65]), (1, [69]), (1.5, [72]), (2, [69]), (2.5, [65]), (3, [60]), (3.5, [65])]), lh: n([(0, [41]), (2, [48])])),
        RawMeasure(chord: "G",  rh: n([(0, [62]), (0.5, [67]), (1, [71]), (1.5, [74]), (2, [71]), (2.5, [67]), (3, [62]), (3.5, [67])]), lh: n([(0, [43]), (2, [50])])),
        RawMeasure(chord: "C",  rh: n([(0, [60, 64]), (1, [67, 72]), (2, [64, 67]), (3, [60, 64])]), lh: n([(0, [48]), (2, [55])])),
        RawMeasure(chord: "Am", rh: n([(0, [60, 64]), (1, [69, 72]), (2, [64, 69]), (3, [60, 64])]), lh: n([(0, [45]), (2, [52])])),
        RawMeasure(chord: "Dm", rh: n([(0, [62, 65]), (1, [69, 74]), (2, [65, 69]), (3, [62, 65])]), lh: n([(0, [50]), (2, [57])])),
        RawMeasure(chord: "G",  rh: n([(0, [62]), (1, [67]), (2, [71]), (3, [74])]), lh: n([(0, [43]), (2, [50])])),
        RawMeasure(chord: "C",  rh: n([(0, [60]), (0.5, [64]), (1, [67]), (1.5, [72]), (2, [67]), (2.5, [64]), (3, [60]), (3.5, [64])]), lh: n([(0, [48]), (2, [55])])),
        RawMeasure(chord: "Em", rh: n([(0, [64]), (0.5, [67]), (1, [71]), (1.5, [76]), (2, [71]), (2.5, [67]), (3, [64]), (3.5, [67])]), lh: n([(0, [52]), (2, [47])])),
        RawMeasure(chord: "F",  rh: n([(0, [60]), (0.5, [65]), (1, [69]), (1.5, [72]), (2, [69]), (2.5, [65]), (3, [60]), (3.5, [65])]), lh: n([(0, [41]), (2, [48])])),
        RawMeasure(chord: "C",  rh: n([(0, [60]), (0.5, [64]), (1, [67]), (1.5, [72]), (2, [64]), (2.5, [67]), (3, [60, 64, 67, 72])]), lh: n([(0, [48]), (2, [55])])),
    ]

    static func n(_ pairs: [(Double, [Int])]) -> [RawNote] {
        var list = pairs.map { RawNote(beat: $0.0, midis: $0.1, dur: 0) }
        list.sort { $0.beat < $1.beat }
        for i in 0..<list.count {
            if list[i].dur == 0 {
                let next: Double = (i + 1 < list.count) ? list[i + 1].beat : 4
                let d = (next - list[i].beat) * 2
                list[i].dur = max(0.5, (d.rounded()) / 2)
            }
        }
        return list
    }

    /// 把每个小节的右手、左手音符合并成“同一拍”的组
    static func buildGroups(_ measures: [RawMeasure]) -> [Group] {
        var out: [Group] = []
        for (mi, m) in measures.enumerated() {
            var beats: [Double: [Cell]] = [:]
            for note in m.rh {
                beats[note.beat, default: []].append(Cell(staff: "rh", midis: note.midis, dur: note.dur))
            }
            for note in m.lh {
                beats[note.beat, default: []].append(Cell(staff: "lh", midis: note.midis, dur: note.dur))
            }
            for beat in beats.keys.sorted() {
                out.append(Group(id: out.count, measure: mi, beatIn: beat, cells: beats[beat]!))
            }
        }
        return out
    }
}

// MARK: - 谱面几何：所有视图共用同一套坐标，保证音符、简谱、卷帘、光标严格同列
enum Geo {
    static let measureW: CGFloat = 300
    static let headerPad: CGFloat = 34      // 小节内左侧留白
    static let rightPad: CGFloat = 26
    static let lineGap: CGFloat = 12

    static let trebleTop: CGFloat = 70
    static let bassTop: CGFloat = 200
    static let staffH: CGFloat = 48         // 五线谱总高（4 个线距）
    static let canvasH: CGFloat = 320

    static func measureX(_ m: Int) -> CGFloat { CGFloat(m) * measureW }

    static func noteX(_ beat: Double, measure: Int) -> CGFloat {
        let usable = measureW - headerPad - rightPad
        return measureX(measure) + headerPad + CGFloat(beat) * (usable / 4)
    }

    static func x(of group: Group) -> CGFloat { noteX(group.beatIn, measure: group.measure) }

    static func totalWidth(_ measures: Int) -> CGFloat { CGFloat(measures) * measureW }

    /// MIDI → 自然音级序号（C 大调：C=0 D=1 E=2 F=3 G=4 A=5 B=6）
    static func dia(_ midi: Int) -> Int {
        let pc = ((midi % 12) + 12) % 12
        let letter = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6][pc]
        let octave = midi / 12 - 1
        return octave * 7 + letter
    }

    static func noteY(_ midi: Int, staff: String) -> CGFloat {
        let half = lineGap / 2
        if staff == "rh" {
            // 高音谱表底线为 E4（dia 30）
            return trebleTop + staffH - CGFloat(dia(midi) - 30) * half
        } else {
            // 低音谱表底线为 G2（dia 18）
            return bassTop + staffH - CGFloat(dia(midi) - 18) * half
        }
    }

    static func staffTop(_ staff: String) -> CGFloat { staff == "rh" ? trebleTop : bassTop }

    static func isFilled(_ dur: Double) -> Bool { dur < 2 }

    static func key(_ measure: Int, _ staff: String, _ beat: Double) -> String {
        "\(measure)-\(staff)-\(String(format: "%.1f", beat))"
    }
}

// MARK: - 评分体系：四档 + 三星 + 准确率
struct ScoreStats {
    var perfect = 0
    var early = 0
    var late = 0
    var error = 0
    var hit = 0
    var wrong = 0
    var miss = 0

    var judged: Int { perfect + early + late + error + miss }

    var accuracy: Double {
        guard judged > 0 else { return 0 }
        return (Double(perfect) + 0.6 * Double(early + late)) / Double(judged)
    }

    var accuracyText: String {
        judged == 0 ? "—" : "\(Int((accuracy * 100).rounded()))%"
    }

    var stars: Int {
        guard judged > 0 else { return 0 }
        if accuracy >= 0.85 { return 3 }
        if accuracy >= 0.65 { return 2 }
        return 1
    }

    mutating func clear() {
        self = ScoreStats()
    }
}

enum GradeKind {
    case perfect, early, late
}

// MARK: - 指法推断：右手从 1 指起、左手从 5 指起，跨八度进位 2，越界滚动换把
enum Fingering {
    static let gradeTolerance: Double = 0.09   // 评分容差（秒）
    static let beatSeconds: Double = 0.75      // 80 BPM

    static func map(for groups: [Group]) -> [String: Int] {
        var out: [String: Int] = [:]
        for staff in ["rh", "lh"] {
            var items: [(key: String, order: Double, midi: Int)] = []
            for g in groups {
                let absBeat = Double(g.measure * 4) + g.beatIn
                for c in g.cells where c.staff == staff {
                    let anchor = (staff == "rh") ? (c.midis.min() ?? 60) : (c.midis.max() ?? 48)
                    items.append((Geo.key(g.measure, staff, g.beatIn), absBeat, anchor))
                }
            }
            let sorted = items.sorted { $0.order < $1.order }
            var cur = (staff == "rh") ? 1 : 5
            for i in sorted.indices {
                if i > 0 {
                    let delta = sorted[i].midi - sorted[i - 1].midi
                    let dir = (staff == "rh") ? delta : -delta
                    if dir > 0 {
                        cur += (abs(delta) >= 12) ? 2 : 1
                    } else if dir < 0 {
                        cur -= 1
                    }
                    if cur > 5 { cur = 2 }
                    if cur < 1 { cur = 4 }
                }
                out[sorted[i].key] = cur
            }
        }
        return out
    }
}

// MARK: - 键盘音域与黑白键
enum Keys {
    static func isBlack(_ midi: Int) -> Bool {
        let pc = ((midi % 12) + 12) % 12
        return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10
    }

    static func range(for groups: [Group]) -> (low: Int, high: Int) {
        var low = 127
        var high = 0
        for g in groups {
            for c in g.cells {
                for m in c.midis {
                    low = min(low, m)
                    high = max(high, m)
                }
            }
        }
        if high < low { return (36, 84) }
        var l = max(21, low - 6)
        var h = min(108, high + 6)
        while l % 12 != 0 && l > 21 { l -= 1 }
        while ((h + 1) % 12) != 0 && h < 108 { h += 1 }
        return (l, h)
    }
}

// MARK: - 和弦库
struct ChordItem: Identifiable {
    let id = UUID()
    var name: String
    var midis: [Int]
}

enum ChordLibrary {
    static let all: [ChordItem] = [
        ChordItem(name: "C", midis: [60, 64, 67]),
        ChordItem(name: "Am", midis: [57, 60, 64]),
        ChordItem(name: "F", midis: [53, 57, 60]),
        ChordItem(name: "G", midis: [55, 59, 62]),
        ChordItem(name: "Dm", midis: [50, 53, 57]),
        ChordItem(name: "Em", midis: [52, 55, 59]),
        ChordItem(name: "C7", midis: [60, 64, 67, 70]),
        ChordItem(name: "G7", midis: [55, 59, 62, 65]),
        ChordItem(name: "D", midis: [50, 54, 57]),
        ChordItem(name: "A", midis: [57, 61, 64]),
        ChordItem(name: "E", midis: [52, 56, 59]),
        ChordItem(name: "Bm", midis: [47, 50, 54]),
    ]
}


// ============================================================
//  合并自 Sources/AppModel.swift
// ============================================================

import Foundation
import SwiftUI
import Combine

final class AppModel: ObservableObject {
    // 曲谱
    @Published var measures: [RawMeasure] = PieceData.builtin
    @Published var groups: [Group] = PieceData.buildGroups(PieceData.builtin)
    @Published var pieceTitle: String = "练习曲 No.1 · C 大调双手交替 · 12 小节 · 80 BPM"
    @Published var mode: PracticeMode = .practice

    // 跟随位置与统计
    @Published var pos: Int = 0
    @Published var hit: Int = 0
    @Published var wrong: Int = 0
    @Published var miss: Int = 0
    @Published var cursorX: CGFloat = 0
    @Published var messages: [String] = ["— 就绪 等待演奏输入"]

    // 评分体系与辅助工具
    @Published var stats = ScoreStats()
    @Published var fingering: [String: Int] = [:]
    @Published var metroOn = false
    @Published var metroBpm: Double = 80
    @Published var metroBeat = 0
    @Published var rhythmText = "先开节拍器，再点我跟拍"
    @Published var wrongFlash: Int? = nil

    // 控制状态
    @Published var midiStatus: String = "未连接"
    @Published var soundOn: Bool = false
    @Published var running: Bool = false
    @Published var smooth: Bool = true

    let midi = MIDIInput()
    let tone = TonePlayer()

    private var demoTimer: Timer?
    private var demoTime: Double = 0

    init() {
        fingering = Fingering.map(for: groups)
        midi.onNote = { [weak self] note in
            self?.feed(note)
        }
        midi.start()
        midiStatus = midi.status
        cursorX = currentCursorX()
        midi.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.midiStatus = self.midi.status
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    // MARK: - 光标

    func currentCursorX() -> CGFloat {
        guard !groups.isEmpty else { return 0 }
        if pos >= groups.count { return Geo.totalWidth(measures.count) - Geo.rightPad }
        return Geo.x(of: groups[pos])
    }

    private func syncCursor() {
        cursorX = currentCursorX()
    }

    // MARK: - 判音引擎

    func feed(_ note: Int) {
        guard !groups.isEmpty, pos < groups.count else { return }

        // 只有自由模式才做「和弦事件指纹」定位；练习模式严格跟随，不跳篇
        if mode == .free { trackEvent(note) }

        if match(at: pos, note: note) {
            afterHit()
            return
        }

        if mode == .practice {
            // 练习模式：原地等待，只记错，不前进也不回退
            wrong += 1
            stats.error += 1
            stats.wrong += 1
            wrongFlash = note
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                if self.wrongFlash == note { self.wrongFlash = nil }
            }
            log("错音 \(nameOf(note)) · 请弹 \(pendingHint())")
            return
        }

        // 自由模式：向前 1~3 拍找，中间这些拍判为漏音
        for step in 1...3 where pos + step < groups.count {
            if canMatch(at: pos + step, note: note) {
                for k in 0..<step { markMiss(pos + k) }
                _ = match(at: pos + step, note: note)
                pos = pos + step
                afterHit()
                log("跳到 \(label(pos))（跳过 \(step) 组）")
                return
            }
        }

        // 自由模式：向后 1~4 拍找，判为回退重练
        for step in 1...4 {
            let target = pos - step
            if target >= 0 && canMatch(at: target, note: note) {
                pos = target
                _ = match(at: pos, note: note)
                afterHit()
                log("回退重练 \(label(pos))")
                return
            }
        }

        wrong += 1
        stats.error += 1
        stats.wrong += 1
        wrongFlash = note
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            if self.wrongFlash == note { self.wrongFlash = nil }
        }
        log("错音 \(nameOf(note))")
    }

    /// 练习模式提示：当前这一组还差哪些音没弹
    func pendingHint() -> String {
        guard let g = groups[safe: pos] else { return "—" }
        var names: [String] = []
        for cell in g.cells where !cell.done {
            for m in cell.midis where !cell.hitMidis.contains(m) {
                names.append(nameOf(m))
            }
        }
        return names.isEmpty ? "—" : names.joined(separator: " ")
    }

    /// 底栏引擎状态：练习模式直接显示这一组还差哪些音
    var engineStatusText: String {
        if running { return "演示中" }
        if mode == .practice { return "练习 · 待弹 " + pendingHint() }
        return "自由 · 任意起弹"
    }

    /// 载入自定义曲谱（简谱导入用）
    func loadPiece(_ newMeasures: [RawMeasure], title: String) {
        guard !newMeasures.isEmpty else { return }
        stopDemo()
        measures = newMeasures
        groups = PieceData.buildGroups(newMeasures)
        pieceTitle = title.isEmpty
            ? "自定义曲目 · \(newMeasures.count) 小节 · 4/4"
            : title + " · \(newMeasures.count) 小节"
        pos = 0
        hit = 0
        wrong = 0
        miss = 0
        stats.clear()
        scoreAnchor = nil
        wrongFlash = nil
        eventList.removeAll()
        curChord = []
        fingering = Fingering.map(for: groups)
        syncCursor()
        log("已载入「\(pieceTitle)」· \(groups.count) 组")
    }

    private func afterHit() {
        guard pos < groups.count else { return }
        if groups[pos].allDone {
            for i in groups[pos].cells.indices { groups[pos].cells[i].state = .hit }
            groups[pos].state = .hit
            hit += 1
            stats.hit += 1
            gradeCurrentGroup()
            pos += 1
        }
        syncCursor()
    }

    private var scoreAnchor: Date?

    /// 时间档判定：以起手首音为 0 点、按 80 BPM 推算每组期望时刻
    private func gradeCurrentGroup() {
        guard pos < groups.count else { return }
        let g = groups[pos]
        let absBeat = Double(g.measure * 4) + g.beatIn
        let now = Date()
        guard let anchor = scoreAnchor else {
            scoreAnchor = now.addingTimeInterval(-absBeat * Fingering.beatSeconds)
            stats.perfect += 1
            return
        }
        let expect = anchor.addingTimeInterval(absBeat * Fingering.beatSeconds)
        let delta = expect.timeIntervalSince(now)      // 正数＝提前，负数＝滞后
        if delta > Fingering.gradeTolerance {
            stats.early += 1
        } else if delta < -Fingering.gradeTolerance {
            stats.late += 1
        } else {
            stats.perfect += 1
        }
    }

    private func canMatch(at index: Int, note: Int) -> Bool {
        guard let group = groups[safe: index] else { return false }
        return group.cells.contains { !$0.done && $0.midis.contains(note) }
    }

    private func match(at index: Int, note: Int) -> Bool {
        guard let group = groups[safe: index] else { return false }
        for i in 0..<group.cells.count where !group.cells[i].done && group.cells[i].midis.contains(note) {
            groups[index].cells[i].hitMidis.insert(note)
            return true
        }
        return false
    }

    private func markMiss(_ index: Int) {
        guard let group = groups[safe: index] else { return }
        if group.allDone { return }
        for i in groups[index].cells.indices where !groups[index].cells[i].done {
            groups[index].cells[i].hitMidis = Set(groups[index].cells[i].midis)
            groups[index].cells[i].state = .miss
        }
        groups[index].state = .miss
        miss += 1
        stats.miss += 1
    }

    // MARK: - 和弦事件定位：从中间起弹时自动跳到对应小节
    private var curChord: [Int] = []
    private var chordTime = Date.distantPast
    private var eventList: [[Int]] = []
    private var flushWork: DispatchWorkItem?

    private func trackEvent(_ note: Int) {
        let now = Date()
        if !curChord.isEmpty, now.timeIntervalSince(chordTime) < 0.08 {
            curChord.append(note)
        } else {
            flushEvents()
            curChord = [note]
        }
        chordTime = now
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushEvents() }
        flushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11, execute: work)
    }

    private func flushEvents() {
        guard !curChord.isEmpty else { return }
        eventList.append(curChord)
        curChord = []
        if eventList.count > 6 { eventList.removeFirst() }
        locateByEvents()
    }

    private func locateByEvents() {
        guard pos < groups.count else { return }
        let pair = Array(eventList.suffix(2))
        guard pair.count == 2 else { return }
        let first = pair[0]
        let second = pair[1]
        var best = -1
        var bestDistance = Int.max

        if !groups.isEmpty {
            for i in 0..<(groups.count - 1) {
                let one = groups[i].midis
                let two = groups[i + 1].midis
                guard first.allSatisfy({ one.contains($0) }),
                      second.allSatisfy({ two.contains($0) }) else { continue }
                let distance = abs(i - pos)
                if distance < bestDistance { bestDistance = distance; best = i }
            }
        }

        guard best >= 0, bestDistance > 2 else { return }

        for k in 0..<2 where best + k < groups.count {
            for ci in groups[best + k].cells.indices {
                groups[best + k].cells[ci].hitMidis = Set(groups[best + k].cells[ci].midis)
            }
            groups[best + k].state = .hit
        }
        pos = min(best + 2, groups.count)
        eventList.removeAll()
        syncCursor()
        log("定位 自动对齐到 \(label(best))")
    }

    // MARK: - 重置与注入

    func reset() {
        stopDemo()
        groups = PieceData.buildGroups(measures)
        pos = 0
        hit = 0
        wrong = 0
        miss = 0
        stats.clear()
        scoreAnchor = nil
        wrongFlash = nil
        fingering = Fingering.map(for: groups)
        syncCursor()
        log("重置到第 1 小节第 1 拍")
    }

    func jumpTo(_ measureIndex: Int) {
        guard let first = groups.firstIndex(where: { $0.measure == measureIndex }) else { return }
        pos = first
        scoreAnchor = nil
        syncCursor()
        log("跳到第 \(measureIndex + 1) 小节")
    }

    // MARK: - 键盘图取值

    var keyLow: Int { Keys.range(for: groups).low }
    var keyHigh: Int { Keys.range(for: groups).high }

    /// 当前这一组应该弹的音
    var expectedKeys: Set<Int> {
        guard pos < groups.count else { return [] }
        return Set(groups[pos].midis)
    }

    /// 当前组里已经按下的音
    var hitKeys: Set<Int> {
        guard pos < groups.count else { return [] }
        return Set(groups[pos].cells.filter { $0.done }.flatMap { $0.midis })
    }

    func previewKey(_ midi: Int) {
        tone.play(midi, duration: 0.7)
        log("键盘 \(nameOf(midi)) 试听 · 不推进判定")
    }

    // MARK: - 节拍器

    private var metroTimer: Timer?
    private var metroStart = Date()
    private var metroTicks = 0
    private var metroBeats: [Date] = []
    private var rhythmDevs: [Double] = []

    func toggleMetro() {
        metroOn.toggle()
        if metroOn {
            startMetro()
        } else {
            stopMetro()
        }
        log(metroOn ? "节拍器已启动 · \(Int(metroBpm)) BPM" : "节拍器已停止")
    }

    func cycleTempo() {
        let cycle: [Double] = [80, 100, 120, 60, 90]
        let idx = cycle.firstIndex(of: metroBpm) ?? 0
        metroBpm = cycle[(idx + 1) % cycle.count]
        if metroOn {
            startMetro()
        }
    }

    private func startMetro() {
        metroTimer?.invalidate()
        metroStart = Date()
        metroTicks = 0
        metroBeat = 0
        metroBeats = [metroStart]
        tone.click(strong: true)
        metroTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self, self.metroOn else { return }
            let step = 60.0 / self.metroBpm
            let elapsed = Date().timeIntervalSince(self.metroStart)
            let ticks = Int(floor(elapsed / step))
            if ticks > self.metroTicks {
                self.metroTicks = ticks
                let beat = ticks % 4
                self.metroBeat = beat
                self.tone.click(strong: beat == 0)
                self.metroBeats.append(Date())
                if self.metroBeats.count > 12 { self.metroBeats.removeFirst() }
            }
        }
    }

    private func stopMetro() {
        metroTimer?.invalidate()
        metroTimer = nil
    }

    // MARK: - 节奏练习

    func rhythmTap() {
        guard metroOn, let last = metroBeats.last else {
            rhythmText = "先开节拍器，再点我跟拍"
            return
        }
        let step = 60.0 / metroBpm
        var dev = Date().timeIntervalSince(last)
        if dev > step / 2 { dev -= step }
        rhythmDevs.append(dev)
        if rhythmDevs.count > 12 { rhythmDevs.removeFirst() }
        let avg = rhythmDevs.reduce(0, +) / Double(rhythmDevs.count)
        rhythmText = "最近 \(msText(dev))　平均 \(msText(avg))　共 \(rhythmDevs.count) 次"
    }

    private func msText(_ v: Double) -> String {
        let n = Int(abs(v * 1000).rounded())
        return (v >= 0 ? "+" : "−") + "\(n) ms"
    }

    // MARK: - 和弦试听

    func playChord(_ item: ChordItem) {
        for (i, m) in item.midis.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.024) { [weak self] in
                self?.tone.play(m, duration: 0.85)
            }
        }
        log("和弦 \(item.name) = \(item.midis.map { nameOf($0) }.joined(separator: " "))")
    }

    func playCurrent() {
        guard let group = groups[safe: pos] else { return }
        for note in group.midis {
            tone.play(note)
            feed(note)
        }
    }

    func wrongNote() {
        if soundOn { tone.play(61) }
        wrong += 1
        log("注入错音 C#4")
    }

    func skipOne() {
        markMiss(pos)
        pos = min(pos + 1, groups.count)
        syncCursor()
        log("漏掉一组")
    }

    func backOne() {
        pos = max(0, pos - 2)
        syncCursor()
        log("回退两组")
    }

    // MARK: - 演示

    func startDemo() {
        reset()
        running = true
        demoTime = 0
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.demoTick()
        }
        log("演示开始（80 BPM 完美演奏）")
    }

    func stopDemo() {
        demoTimer?.invalidate()
        demoTimer = nil
        running = false
    }

    private func demoTick() {
        guard running else { return }
        demoTime += 0.02
        guard pos < groups.count else {
            stopDemo()
            log("全曲完成 命中 \(hit) 组")
            return
        }
        let group = groups[pos]
        let beat = Double(group.measure * 4) + group.beatIn
        let due = beat * 0.75
        if demoTime >= due {
            if soundOn { group.midis.forEach { tone.play($0) } }
            group.midis.forEach { feed($0) }
        }
    }

    // MARK: - 文本

    func log(_ text: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        messages.insert("\(stamp) \(text)", at: 0)
        if messages.count > 8 { messages.removeLast() }
    }

    func label(_ index: Int) -> String {
        guard let group = groups[safe: index] else { return "—" }
        let beat = Int(group.beatIn) + 1
        return "第 \(group.measure + 1) 小节第 \(beat) 拍"
    }

    func nameOf(_ midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = midi / 12 - 1
        return names[((midi % 12) + 12) % 12] + "\(octave)"
    }

    func jpLabel(_ midis: [Int]) -> String {
        let deg = [0: "1", 2: "2", 4: "3", 5: "4", 7: "5", 9: "6", 11: "7"]
        let acc = [1: "#1", 3: "#2", 6: "#3", 8: "#5", 10: "#6"]
        return midis.prefix(4).map { midi -> String in
            let pc = ((midi % 12) + 12) % 12
            let base = deg[pc] ?? acc[pc] ?? "?"
            let octave = (midi - 60) / 12
            let mark = octave > 0 ? String(repeating: "'", count: octave) : String(repeating: ",", count: -octave)
            return base + mark
        }.joined(separator: "+")
    }

    var currentMeasure: Int {
        guard groups[safe: pos] != nil else { return max(0, measures.count - 1) }
        return groups[pos].measure
    }

    var currentBeatText: String {
        guard let group = groups[safe: pos] else { return "4/4" }
        let beat = group.beatIn
        let whole = Int(beat)
        let half = (beat - Double(whole)) > 0.2 ? " ½" : ""
        return "\(whole + 1)\(half)/4"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}


// ============================================================
//  合并自 Sources/MIDIInput.swift
// ============================================================

import Foundation
import CoreMIDI
import SwiftUI

/// 电钢 MIDI 输入：CoreMIDI 扫描所有输入源，收到 Note On 就回调
final class MIDIInput: ObservableObject {
    @Published var status: String = "未连接"
    @Published var connectedCount: Int = 0

    var onNote: ((Int) -> Void)?

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected: Set<MIDIEndpointRef> = []
    private var timer: Timer?

    func start() {
        guard client == 0 else { return }

        MIDIClientCreateWithBlock("PianoFollow" as CFString, &client) { [weak self] _ in
            self?.scanSources()
        }

        MIDIInputPortCreateWithBlock(client, "PianoFollow In" as CFString, &port) { [weak self] list, _ in
            self?.read(list)
        }

        scanSources()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanSources()
        }
    }

    private func displayName(of src: MIDIEndpointRef) -> String {
        var ref: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(src, kMIDIPropertyDisplayName, &ref) == noErr,
           let value = ref?.takeRetainedValue() {
            return value as String
        }
        return "MIDI 设备"
    }

    func rescan() {
        if client == 0 { start() } else { scanSources() }
    }

    private func scanSources() {
        let count = MIDIGetNumberOfSources()
        var names: [String] = []

        for i in 0..<count {
            let src = MIDIGetSource(i)
            if !connected.contains(src) {
                MIDIPortConnectSource(port, src, nil)
                connected.insert(src)
            }
            names.append(displayName(of: src))
        }

        DispatchQueue.main.async {
            self.connectedCount = count
            if count == 0 {
                self.status = "未检测到设备"
            } else {
                self.status = names.joined(separator: " · ")
            }
        }
    }

    private func read(_ list: UnsafePointer<MIDIPacketList>) {
        var packet = list.pointee.packet
        let packets = Int(list.pointee.numPackets)

        for _ in 0..<packets {
            let length = Int(packet.length)
            if length >= 3 {
                let status = packet.data.0
                let data1 = packet.data.1
                let data2 = packet.data.2
                let kind = status & 0xF0
                if (kind == 0x90 || kind == 0x80) && data2 > 0 {
                    let midi = Int(data1)
                    DispatchQueue.main.async { self.onNote?(midi) }
                }
            }
            packet = withUnsafePointer(to: &packet) { MIDIPacketNext($0).pointee }
        }
    }
}


// ============================================================
//  合并自 Sources/TonePlayer.swift
// ============================================================

import Foundation
import AVFoundation

/// 参考音合成：正弦 + 快速起音、慢衰包络，多点轮流播放以便和弦同时响
final class TonePlayer {
    private var engine: AVAudioEngine?
    private var nodes: [AVAudioPlayerNode] = []
    private var index = 0
    private lazy var format: AVAudioFormat? = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    func prepare() {
        guard engine == nil else { return }
        let audioEngine = AVAudioEngine()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        guard let fmt = format else { return }

        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: fmt)
            nodes.append(node)
        }

        do {
            try audioEngine.start()
        } catch {
            return
        }
        nodes.forEach { $0.play() }
        engine = audioEngine
    }

    func play(_ midi: Int, duration: Double = 0.9) {
        prepare()
        guard engine != nil, let buffer = makeBuffer(midi: midi, duration: duration) else { return }
        let node = nodes[index]
        index = (index + 1) % nodes.count
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    /// 节拍器短音：强拍 1240Hz、弱拍 900Hz
    func click(strong: Bool) {
        prepare()
        guard engine != nil, let buffer = makeClickBuffer(strong: strong) else { return }
        let node = nodes[index]
        index = (index + 1) % nodes.count
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func makeClickBuffer(strong: Bool) -> AVAudioPCMBuffer? {
        guard let fmt = format else { return nil }
        let sampleRate = 44100.0
        let length = 0.085
        let frames = AVAudioFrameCount(sampleRate * length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        let frequency = strong ? 1240.0 : 900.0
        let total = Int(frames)
        for i in 0..<total {
            let t = Double(i) / sampleRate
            let env = exp(-t * 42.0) * min(1.0, t / 0.004)
            let sq: Double = sin(2.0 * .pi * frequency * t) >= 0 ? 1.0 : -1.0
            channel[i] = Float(sq * env * (strong ? 0.32 : 0.20))
        }
        return buffer
    }

    private func makeBuffer(midi: Int, duration: Double) -> AVAudioPCMBuffer? {
        guard let fmt = format else { return nil }
        let sampleRate = 44100.0
        let length = min(max(duration, 0.18), 2.2)
        let frames = AVAudioFrameCount(sampleRate * length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        // 标准音高：A4（MIDI 69）= 440 Hz（旧版误写 220，导致整体低一个八度）
        let f0 = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
        let total = Int(frames)
        // 谐波叠加：越高的泛音越弱，接近琴弦振动
        let amps: [Double] = [1.0, 0.60, 0.40, 0.26, 0.17, 0.11, 0.07, 0.05]
        let nyquistLimit = sampleRate * 0.45

        for i in 0..<total {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.008)
            let decay = exp(-t * (1.7 / length))
            var sum = 0.0
            for (h, a) in amps.enumerated() {
                let f = f0 * Double(h + 1)
                if f >= nyquistLimit { break }
                sum += sin(2.0 * .pi * f * t) * a
            }
            // 前 20ms 琴键锤击瞬态
            let hammer = exp(-t * 120.0) * sin(2.0 * .pi * f0 * 2.0 * t) * 0.30
            let mix = (sum / 2.3) + hammer
            channel[i] = Float(mix * attack * decay * 0.62)
        }
        return buffer
    }
}


// ============================================================
//  合并自 Sources/ContentView.swift
// ============================================================

import SwiftUI
import UniformTypeIdentifiers

enum AppColors {
    static let bg = Color(red: 0.055, green: 0.072, blue: 0.086)
    static let panel = Color(red: 0.078, green: 0.096, blue: 0.112)
    static let paper = Color(red: 0.963, green: 0.943, blue: 0.898)
    static let brass = Color(red: 0.878, green: 0.680, blue: 0.392)
    static let text = Color(red: 0.86, green: 0.85, blue: 0.82)
    static let dim = Color(red: 0.52, green: 0.55, blue: 0.57)
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    @State private var showScore = true
    @State private var showJianpu = true
    @State private var showRoll = true
    @State private var showKB = true
    @State private var showImport = false
    @State private var importText = JianpuParser.demo
    @State private var importErr = ""
    @State private var showImportFile = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if showScore { scoreArea }
                    if showJianpu { jianpuBar }
                    if showRoll { rollBar }
                    if showKB { keyboardBar }
                }
                sidePanel
            }
            statusBar
        }
        .background(AppColors.bg)
        .sheet(isPresented: $showImport) { importSheet }
        .fileImporter(isPresented: $showImportFile,
                      allowedContentTypes: scoreFileTypes,
                      allowsMultipleSelection: false) { result in
            handleFile(result)
        }
    }

    private var scoreFileTypes: [UTType] {
        var list: [UTType] = [.midi, .xml]
        if let m = UTType(filenameExtension: "musicxml") { list.append(m) }
        return list
    }

    // MARK: - 顶栏

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("钢琴跟弹 · 光标跟随")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Text(model.pieceTitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.dim)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                viewToggle("谱面", $showScore)
                viewToggle("简谱", $showJianpu)
                viewToggle("卷帘", $showRoll)
                viewToggle("键盘", $showKB)
            }
            HStack(spacing: 5) {
                modeToggle("练习", .practice)
                modeToggle("自由", .free)
            }
            Button {
                importErr = ""
                showImport = true
            } label: {
                Text("导入简谱")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.brass)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(AppColors.brass.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AppColors.brass.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                chip(model.midiStatus, on: model.midi.connectedCount > 0)
                chip(model.mode == .practice ? "练习" : "自由", on: true)
                chip(model.soundOn ? "声音开" : "声音关", on: model.soundOn)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(AppColors.panel)
    }

    private func modeToggle(_ title: String, _ m: PracticeMode) -> some View {
        let on = model.mode == m
        return Button {
            model.mode = m
            model.log(m == .practice
                ? "练习模式：弹对才前进，弹错原地等待，不会跳篇"
                : "自由模式：任意位置弹对即自动跳转")
        } label: {
            Text(title)
                .font(.system(size: 11, weight: on ? Font.Weight.medium : Font.Weight.regular))
                .foregroundColor(on ? AppColors.brass : AppColors.dim)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(on ? AppColors.brass.opacity(0.14) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(on ? AppColors.brass.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 导入简谱

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("导入简谱")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Button("载入示例") { importText = JianpuParser.demo }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.brass)
                Button("取消") { showImport = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.dim)
            }
            Text("第一行可写「标题: 曲名」。之后每行以「右手:」或「左手:」开头，用 | 分小节，每小节必须满 4 拍。数字 1–7 为音级（1=C），, 降八度，' 升八度，- 延一拍，/ 半拍，[1 3 5] 和弦，0 休止。")
                .font(.system(size: 11))
                .foregroundColor(AppColors.dim)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showImport = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showImportFile = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("从文件导入五线谱")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.brass)
                    Text("MIDI / MusicXML")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.dim)
                    Spacer()
                    Text("选择文件")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.dim)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 7).fill(AppColors.brass.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppColors.brass.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            TextEditor(text: $importText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AppColors.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 240)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            if !importErr.isEmpty {
                Text(importErr)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.78, green: 0.36, blue: 0.27))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button {
                    doImport()
                } label: {
                    Text("解析并载入")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 7).fill(AppColors.brass))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 420)
        .background(AppColors.bg)
    }

    private func doImport() {
        do {
            let r = try JianpuParser.parse(importText)
            model.loadPiece(r.measures, title: r.title)
            importErr = ""
            showImport = false
        } catch {
            importErr = error.localizedDescription
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            let msg = err.localizedDescription
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                importErr = msg
                showImport = true
            }
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let name = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension.lowercased()
                let parsed: (title: String, measures: [RawMeasure])
                if ext == "mid" || ext == "midi" {
                    parsed = try MidiParser.parse(data, title: name)
                } else {
                    guard let text = String(data: data, encoding: .utf8) else {
                        throw ScoreFileError.message("文件读不出文本，可能不是 UTF-8 的 MusicXML")
                    }
                    parsed = try MusicXmlParser.parse(text, fallbackTitle: name)
                }
                model.loadPiece(parsed.measures, title: parsed.title)
                importErr = ""
                showImport = false
            } catch {
                let msg = error.localizedDescription
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    importErr = msg
                    showImport = true
                }
            }
        }
    }

    private func chip(_ text: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(on ? AppColors.brass : AppColors.dim.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(on ? AppColors.text : AppColors.dim)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func viewToggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: binding.wrappedValue ? Font.Weight.medium : Font.Weight.regular))
                .foregroundColor(binding.wrappedValue ? AppColors.brass : AppColors.dim)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(binding.wrappedValue ? AppColors.brass.opacity(0.14) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(binding.wrappedValue ? AppColors.brass.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 谱面

    private var scoreArea: some View {
        GeometryReader { geo in
            let viewport = geo.size.width
            let total = Geo.totalWidth(model.measures.count)
            let maxScroll = max(0, total - viewport + 30)
            let target = min(max(0, model.cursorX - viewport * 0.42), maxScroll)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.paper)
                    .frame(width: viewport, height: geo.size.height)

                StaffCanvas(groups: model.groups,
                            measures: model.measures.count,
                            currentGroup: model.pos,
                            fingering: model.fingering)
                .offset(x: -target, y: 0)

                Rectangle()
                    .fill(AppColors.brass)
                    .frame(width: 1.6)
                    .frame(maxHeight: .infinity)
                    .offset(x: model.cursorX - target)
                    .opacity(0.9)

                TrianglePointer()
                    .fill(AppColors.brass)
                    .frame(width: 9, height: 6)
                    .offset(x: model.cursorX - target - 4.5, y: 1)

                LinearGradient(colors: [AppColors.bg.opacity(0.55), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 46)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)

                HStack {
                    Spacer()
                    LinearGradient(colors: [.clear, AppColors.bg.opacity(0.55)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 46)
                }
                .allowsHitTesting(false)
            }
            .clipped()
            .animation(.easeOut(duration: 0.22), value: target)
            .overlay(alignment: .bottomTrailing) {
                Text("点谱面试听 · 跟随由引擎判定，不是真实演奏时刻")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.dim.opacity(0.8))
                    .padding(.trailing, 12)
                    .padding(.bottom, 6)
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let globalX = value.location.x + target
                        guard let nearest = model.groups.min(by: {
                            abs(Geo.x(of: $0) - globalX) < abs(Geo.x(of: $1) - globalX)
                        }) else { return }
                        for note in nearest.midis { model.tone.play(note) }
                        model.log("试听 \(model.jpLabel(nearest.midis)) · 仅发声不推进")
                    }
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .frame(maxHeight: .infinity)
    }

    // MARK: - 简谱条

    private var jianpuBar: some View {
        GeometryReader { geo in
            let viewport = geo.size.width
            let total = Geo.totalWidth(model.measures.count)
            let maxScroll = max(0, total - viewport + 30)
            let target = min(max(0, model.cursorX - viewport * 0.42), maxScroll)

            ZStack(alignment: .topLeading) {
                JianpuCanvas(groups: model.groups,
                             measures: model.measures.count,
                             currentGroup: model.pos,
                             labels: { model.jpLabel($0) })
                    .offset(x: -target)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("简谱").font(.system(size: 10)).foregroundColor(AppColors.dim)
                        Text("右手").font(.system(size: 11)).foregroundColor(AppColors.dim).padding(.top, 16)
                        Text("左手").font(.system(size: 11)).foregroundColor(AppColors.dim).padding(.top, 18)
                        Spacer()
                    }
                    .frame(width: 52, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    LinearGradient(colors: [AppColors.panel, AppColors.panel.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 18)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 112)
            .clipped()
            .animation(.easeOut(duration: 0.22), value: target)
        }
        .frame(height: 112)
        .background(AppColors.panel)
        .padding(.top, 10)
    }

    // MARK: - 卷帘

    private var rollBar: some View {
        GeometryReader { geo in
            let viewport = geo.size.width
            let total = Geo.totalWidth(model.measures.count)
            let maxScroll = max(0, total - viewport + 30)
            let target = min(max(0, model.cursorX - viewport * 0.42), maxScroll)

            HStack(spacing: 0) {
                Text("卷帘")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.dim)
                    .frame(width: 46)

                ZStack(alignment: .topLeading) {
                    RollCanvas(groups: model.groups,
                               measures: model.measures.count,
                               currentGroup: model.pos)
                        .offset(x: -target)

                    Rectangle()
                        .fill(AppColors.brass.opacity(0.85))
                        .frame(width: 1.4)
                        .frame(maxHeight: .infinity)
                        .offset(x: model.cursorX - target)
                }
                .clipped()
                .animation(.easeOut(duration: 0.22), value: target)
            }
            .frame(height: 118)
            .background(AppColors.panel.opacity(0.6))
        }
        .frame(height: 118)
        .padding(.top, 8)
    }

    // MARK: - 键盘图

    private var keyboardBar: some View {
        HStack(spacing: 0) {
            Text("键盘")
                .font(.system(size: 10))
                .foregroundColor(AppColors.dim)
                .frame(width: 46)

            KeyboardView(low: model.keyLow,
                         high: model.keyHigh,
                         expected: model.expectedKeys,
                         hitKeys: model.hitKeys,
                         wrongKey: model.wrongFlash,
                         onTap: { model.previewKey($0) })
                .padding(.vertical, 7)
                .padding(.trailing, 14)
        }
        .frame(height: 92)
        .background(AppColors.panel)
        .padding(.top, 8)
    }

    // MARK: - 侧栏

    private var sidePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                card("输入源") {
                    Text(model.midiStatus)
                        .font(.system(size: 12))
                        .foregroundColor(model.midi.connectedCount > 0 ? AppColors.text : AppColors.dim)
                        .lineLimit(2)
                    actionButton("重新扫描 MIDI 设备") { model.midi.rescan() }
                    Text("iPad 用 USB-C 转接电钢，或系统级蓝牙 MIDI；原生走 CoreMIDI，不经网页 MIDI。")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                card("曲目 · 点小节直接跳") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(0..<model.measures.count, id: \.self) { index in
                            Button {
                                model.jumpTo(index)
                            } label: {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(model.currentMeasure == index ? AppColors.brass : AppColors.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(model.currentMeasure == index ? 0.10 : 0.04))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                card("评分 · 本次练习") {
                    HStack(spacing: 6) {
                        gradeCell("PERFECT", model.stats.perfect)
                        gradeCell("EARLY", model.stats.early)
                    }
                    HStack(spacing: 6) {
                        gradeCell("LATE", model.stats.late)
                        gradeCell("ERROR", model.stats.error)
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < model.stats.stars ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(i < model.stats.stars ? AppColors.brass : AppColors.dim.opacity(0.55))
                        }
                        Spacer()
                        Text("准确率 \(model.stats.accuracyText)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.dim)
                    }
                    Text("容差 ±\(Int(Fingering.gradeTolerance * 1000)) ms · 抢拍 Early / 拖拍 Late / 弹错 Error")
                        .font(.system(size: 9.5))
                        .foregroundColor(AppColors.dim.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                card("辅助工具") {
                    HStack(spacing: 8) {
                        actionButton(model.metroOn ? "节拍器 · 开" : "节拍器 · 关") { model.toggleMetro() }
                        actionButton("\(Int(model.metroBpm)) BPM") { model.cycleTempo() }
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill((model.metroOn && i == model.metroBeat) ? AppColors.brass : Color.white.opacity(0.10))
                                .frame(width: 7, height: 7)
                        }
                        Spacer()
                        Text("四拍 · 强拍更亮")
                            .font(.system(size: 9.5))
                            .foregroundColor(AppColors.dim.opacity(0.8))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 4), spacing: 5) {
                        ForEach(ChordLibrary.all) { item in
                            Button {
                                model.playChord(item)
                            } label: {
                                Text(item.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 24)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        model.rhythmTap()
                    } label: {
                        Text("节奏练习 · 点我跟拍")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.brass)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(AppColors.brass.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Text(model.rhythmText)
                        .font(.system(size: 9.5))
                        .foregroundColor(AppColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                card("演奏") {
                    HStack(spacing: 8) {
                        actionButton(model.running ? "停止演示" : "演示 · 完美演奏") {
                            if model.running { model.stopDemo() } else { model.startDemo() }
                        }
                    }
                    actionButton("重置到第 1 小节") { model.reset() }
                    Toggle(isOn: $model.soundOn) {
                        Text("参考音").font(.system(size: 12)).foregroundColor(AppColors.text)
                    }
                    .toggleStyle(.switch)
                    .tint(AppColors.brass)
                }

                card("手动注入") {
                    actionButton("弹当前一组") { model.playCurrent() }
                    actionButton("弹一个错音") { model.wrongNote() }
                    HStack(spacing: 8) {
                        actionButton("漏一组") { model.skipOne() }
                        actionButton("回退") { model.backOne() }
                    }
                }

                card("对齐事件") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(model.messages.prefix(5).enumerated()), id: \.offset) { item in
                            Text(item.element)
                                .font(.system(size: 10))
                                .foregroundColor(item.offset == 0 ? AppColors.text : AppColors.dim)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 246)
        .background(AppColors.panel)
    }

    private func card<T: View>(_ title: String, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundColor(AppColors.dim)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func gradeCell(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5))
                .tracking(0.8)
                .foregroundColor(AppColors.dim)
            Text("\(value)")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(value > 0 ? AppColors.text : AppColors.dim.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.055)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底栏

    private var statusBar: some View {
        HStack(spacing: 0) {
            stat("当前位置", "第 \(model.currentMeasure + 1) 小节")
            stat("拍位", model.currentBeatText)
            stat("命中", "\(model.hit)")
            stat("错音", "\(model.wrong)")
            stat("漏音", "\(model.miss)")
            stat("准确率", model.stats.accuracyText)
            stat("引擎状态", model.engineStatusText)
            Spacer()
            Text("共 \(model.groups.count) 组")
                .font(.system(size: 11))
                .foregroundColor(AppColors.dim)
                .padding(.trailing, 16)
        }
        .frame(height: 54)
        .background(AppColors.panel)
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundColor(AppColors.text)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(AppColors.dim)
        }
        .frame(minWidth: 96, alignment: .leading)
        .padding(.leading, 16)
    }
}

struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}


// ============================================================
//  合并自 Sources/StaffCanvas.swift
// ============================================================

import SwiftUI

// MARK: - 五线谱
struct StaffCanvas: View {
    var groups: [Group]
    var measures: Int
    var currentGroup: Int
    var fingering: [String: Int] = [:]

    private let ink = Color(red: 0.15, green: 0.12, blue: 0.09)
    private let brass = Color(red: 0.91, green: 0.76, blue: 0.54)

    var body: some View {
        Canvas { context, _ in
            self.draw(context: &context)
        }
        .frame(width: Geo.totalWidth(measures), height: Geo.canvasH)
    }

    private func draw(context: inout GraphicsContext) {
        // 五线 + 小节线 + 小节序号
        for m in 0..<measures {
            let x0 = Geo.measureX(m)
            for top in [Geo.trebleTop, Geo.bassTop] {
                for i in 0..<5 {
                    var p = Path()
                    let y = top + CGFloat(i) * Geo.lineGap
                    p.move(to: CGPoint(x: x0, y: y))
                    p.addLine(to: CGPoint(x: x0 + Geo.measureW, y: y))
                    context.stroke(p, with: .color(ink.opacity(0.30)), lineWidth: 0.9)
                }
            }
            var bar = Path()
            bar.move(to: CGPoint(x: x0, y: Geo.trebleTop - 2))
            bar.addLine(to: CGPoint(x: x0, y: Geo.bassTop + Geo.staffH + 2))
            context.stroke(bar, with: .color(ink.opacity(0.45)), lineWidth: m == 0 ? 1.6 : 1.1)

            context.draw(
                Text("\(m + 1)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ink.opacity(0.35)),
                at: CGPoint(x: x0 + 7, y: Geo.trebleTop - 14)
            )
        }

        // 谱号（仅第一小节）
        drawTrebleClef(&context, x: 14)
        drawBassClef(&context, x: 14)

        // 预先算出哪些音需要连梁：同小节、同谱表、拍位相差 0.5 且都是八分音符
        var durations: [String: Double] = [:]
        for group in groups {
            for cell in group.cells {
                durations[Geo.key(group.measure, cell.staff, group.beatIn)] = cell.dur
            }
        }
        var beamed: Set<String> = []
        for (key, dur) in durations where dur == 0.5 {
            let parts = key.split(separator: "-")
            guard parts.count == 3, let m = Int(parts[0]), let beat = Double(parts[2]) else { continue }
            let staff = String(parts[1])
            let next = Geo.key(m, staff, beat + 0.5)
            if durations[next] == 0.5 { beamed.insert(key) }
        }

        // 音符
        var stemEnds: [String: CGPoint] = [:]

        for group in groups {
            let gx = Geo.noteX(group.beatIn, measure: group.measure)
            let isCurrent = group.id == currentGroup

            for cell in group.cells {
                let color: Color
                switch cell.state {
                case .hit:   color = Color(red: 0.36, green: 0.55, blue: 0.42)
                case .miss:  color = ink.opacity(0.30)
                case .wrong: color = Color(red: 0.72, green: 0.30, blue: 0.22)
                case .idle:  color = ink
                }

                let ys = cell.midis.map { Geo.noteY($0, staff: cell.staff) }
                let key = Geo.key(group.measure, cell.staff, group.beatIn)
                let stemEnd = drawNote(&context, x: gx, ys: ys, staff: cell.staff,
                                       dur: cell.dur, color: color,
                                       beamed: beamed.contains(key), emphasis: isCurrent)
                stemEnds[key] = stemEnd

                // 指法数字：右手标在音符上方，左手标在下方
                if let finger = fingering[key] {
                    let fy: CGFloat = (cell.staff == "rh")
                        ? ((ys.min() ?? 0) - 12)
                        : ((ys.max() ?? 0) + 15)
                    context.draw(
                        Text("\(finger)")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(ink.opacity(0.52)),
                        at: CGPoint(x: gx, y: fy)
                    )
                }
            }
        }

        // 连梁
        for group in groups where group.beatIn == floor(group.beatIn) {
            for cell in group.cells where cell.dur == 0.5 {
                let a = Geo.key(group.measure, cell.staff, group.beatIn)
                let b = Geo.key(group.measure, cell.staff, group.beatIn + 0.5)
                guard beamed.contains(a), let p1 = stemEnds[a], let p2 = stemEnds[b] else { continue }
                var beam = Path()
                beam.move(to: p1)
                beam.addLine(to: p2)
                context.stroke(beam, with: .color(ink.opacity(0.80)), lineWidth: 2.2)
            }
        }
    }

    // 返回符干末端坐标，供连梁使用
    private func drawNote(_ context: inout GraphicsContext, x: CGFloat, ys: [CGFloat],
                          staff: String, dur: Double, color: Color,
                          beamed: Bool, emphasis: Bool) -> CGPoint {
        let filled = dur < 2

        for y in ys {
            var head = Path()
            head.addEllipse(in: CGRect(x: x - 5.4, y: y - 4.3, width: 10.8, height: 8.6))
            if filled {
                context.fill(head, with: .color(color))
            } else {
                context.stroke(head, with: .color(color), lineWidth: 1.5)
            }
            drawLedger(&context, x: x, y: y, staff: staff, color: color)
        }

        let top = ys.min() ?? 0
        let bottom = ys.max() ?? 0
        var stem = Path()
        var end: CGPoint

        if staff == "rh" {
            end = CGPoint(x: x + 5.2, y: (top - 25))
            stem.move(to: CGPoint(x: x + 5.2, y: bottom - 1))
            stem.addLine(to: end)
        } else {
            end = CGPoint(x: x - 5.2, y: (bottom + 25))
            stem.move(to: CGPoint(x: x - 5.2, y: top + 1))
            stem.addLine(to: end)
        }
        context.stroke(stem, with: .color(color), lineWidth: 1.3)

        if dur <= 0.5 && !beamed {
            var flag = Path()
            if staff == "rh" {
                flag.move(to: end)
                flag.addQuadCurve(to: CGPoint(x: end.x + 8, y: end.y + 11),
                                  control: CGPoint(x: end.x + 9, y: end.y + 2))
            } else {
                flag.move(to: end)
                flag.addQuadCurve(to: CGPoint(x: end.x - 8, y: end.y - 11),
                                  control: CGPoint(x: end.x - 9, y: end.y - 2))
            }
            context.stroke(flag, with: .color(color), lineWidth: 1.6)
        }

        if emphasis {
            var mark = Path()
            mark.addEllipse(in: CGRect(x: x - 9, y: (ys.first ?? 0) - 8, width: 18, height: 16))
            context.stroke(mark, with: .color(brass.opacity(0.55)), lineWidth: 1)
        }

        return end
    }

    private func drawLedger(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, staff: String, color: Color) {
        let top = Geo.staffTop(staff)
        let half = Geo.lineGap / 2
        guard y < top + Geo.staffH - 0.5 || y > top + Geo.staffH + 0.5 || y < top - 0.5 else { return }
        let steps = ((y - top) / half).rounded()
        guard Int(steps) % 2 == 0 else { return }
        let lineY = top + steps * half
        guard lineY <= top - 1 || lineY >= top + Geo.staffH + 1 else { return }
        var p = Path()
        p.move(to: CGPoint(x: x - 9, y: lineY))
        p.addLine(to: CGPoint(x: x + 9, y: lineY))
        context.stroke(p, with: .color(color.opacity(0.55)), lineWidth: 0.9)
    }

    private func drawTrebleClef(_ context: inout GraphicsContext, x: CGFloat) {
        let top = Geo.trebleTop
        var glyph = Path()
        glyph.move(to: CGPoint(x: x, y: top - 8))
        glyph.addQuadCurve(to: CGPoint(x: x, y: top + Geo.staffH + 10),
                           control: CGPoint(x: x + 22, y: top + 6))
        glyph.addEllipse(in: CGRect(x: x - 8, y: top + 10, width: 16, height: 16))
        context.stroke(glyph, with: .color(ink.opacity(0.85)), lineWidth: 2)
    }

    private func drawBassClef(_ context: inout GraphicsContext, x: CGFloat) {
        let top = Geo.bassTop
        var glyph = Path()
        glyph.addEllipse(in: CGRect(x: x - 9, y: top + 10, width: 13, height: 13))
        glyph.move(to: CGPoint(x: x + 4, y: top + 8))
        glyph.addQuadCurve(to: CGPoint(x: x + 10, y: top + 26),
                           control: CGPoint(x: x + 16, y: top + 16))
        context.stroke(glyph, with: .color(ink.opacity(0.85)), lineWidth: 2)

        var dots = Path()
        dots.addEllipse(in: CGRect(x: x + 6, y: top + 24, width: 4, height: 4))
        dots.addEllipse(in: CGRect(x: x + 6, y: top + 34, width: 4, height: 4))
        context.fill(dots, with: .color(ink.opacity(0.85)))
    }
}

// MARK: - 简谱条
struct JianpuCanvas: View {
    var groups: [Group]
    var measures: Int
    var currentGroup: Int
    var labels: ([Int]) -> String

    private let rhColor = Color(red: 0.86, green: 0.83, blue: 0.76)
    private let lhColor = Color(red: 0.71, green: 0.77, blue: 0.81)
    private let brass = Color(red: 0.91, green: 0.76, blue: 0.54)
    private let doneColor = Color(red: 0.45, green: 0.62, blue: 0.50)
    private let missColor = Color(red: 0.60, green: 0.53, blue: 0.40)

    var body: some View {
        Canvas { context, _ in
            self.draw(context: &context)
        }
        .frame(width: Geo.totalWidth(measures), height: 112)
    }

    private func draw(context: inout GraphicsContext) {
        for group in groups {
            let x = Geo.noteX(group.beatIn, measure: group.measure)
            for cell in group.cells {
                let text = labels(cell.midis)
                let color: Color
                switch cell.state {
                case .hit: color = doneColor
                case .miss: color = missColor
                case .wrong: color = Color(red: 0.78, green: 0.38, blue: 0.30)
                case .idle: color = cell.staff == "rh" ? rhColor : lhColor
                }
                let strong = group.id == currentGroup
                let y: CGFloat = cell.staff == "rh" ? 26 : 78
                context.draw(
                    Text(text)
                        .font(.system(size: strong ? 20 : 18, weight: strong ? .semibold : .regular, design: .serif))
                        .foregroundColor(color),
                    at: CGPoint(x: x, y: y)
                )
            }
        }
    }
}

// MARK: - 卷帘
struct RollCanvas: View {
    var groups: [Group]
    var measures: Int
    var currentGroup: Int

    var body: some View {
        Canvas { context, size in
            let low = 36
            let high = 80
            let rows = high - low + 1
            let rowH = (size.height - 16) / CGFloat(rows)

            for group in self.groups {
                let x = Geo.noteX(group.beatIn, measure: group.measure) - 4
                for cell in group.cells {
                    let color: Color
                    switch cell.state {
                    case .hit: color = Color(red: 0.36, green: 0.55, blue: 0.42).opacity(0.9)
                    case .miss: color = Color(red: 0.55, green: 0.47, blue: 0.35).opacity(0.8)
                    case .wrong: color = Color(red: 0.72, green: 0.30, blue: 0.22).opacity(0.9)
                    case .idle: color = Color(red: 0.45, green: 0.50, blue: 0.55).opacity(group.id == self.currentGroup ? 0.85 : 0.45)
                    }
                    for midi in cell.midis {
                        let row = CGFloat(high - midi)
                        let y = 8 + row * rowH
                        var bar = Path()
                        bar.addRoundedRect(in: CGRect(x: x, y: y, width: 8, height: max(2.5, rowH - 0.5)), cornerSize: CGSize(width: 1.5, height: 1.5))
                        context.fill(bar, with: .color(color))
                    }
                }
            }
        }
        .frame(width: Geo.totalWidth(measures), height: 120)
    }
}


// ============================================================
//  合并自 Sources/KeyboardView.swift
// ============================================================

import SwiftUI

/// 键盘图：按曲目音域自动取范围，白键均分、黑键骑缝，可点击试听
struct KeyboardView: View {
    var low: Int
    var high: Int
    var expected: Set<Int>
    var hitKeys: Set<Int>
    var wrongKey: Int? = nil
    var onTap: (Int) -> Void

    private let whiteFill = Color(red: 0.965, green: 0.937, blue: 0.878)
    private let blackFill = Color(red: 0.106, green: 0.141, blue: 0.165)
    private let brass = Color(red: 0.753, green: 0.561, blue: 0.306)
    private let doneFill = Color(red: 0.431, green: 0.604, blue: 0.471)
    private let wrongFill = Color(red: 0.753, green: 0.337, blue: 0.247)

    private var whites: [Int] {
        var list: [Int] = []
        var m = self.low
        while m <= self.high {
            if !Keys.isBlack(m) { list.append(m) }
            m += 1
        }
        return list
    }

    var body: some View {
        GeometryReader { geo in
            let sizeX = geo.size.width
            let sizeY = geo.size.height
            let ws = self.whites
            let count = max(1, ws.count)
            let ww = sizeX / CGFloat(count)
            let bw = ww * 0.62
            let bh = sizeY * 0.62

            Canvas { ctx, _ in
                for (i, midi) in ws.enumerated() {
                    let rect = CGRect(x: CGFloat(i) * ww + 0.7, y: 0,
                                      width: max(1.0, ww - 1.4), height: sizeY)
                    var p = Path()
                    p.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
                    ctx.fill(p, with: .color(self.colorFor(midi)))
                }

                var m = self.low
                while m <= self.high {
                    if Keys.isBlack(m) {
                        let cx = CGFloat(self.whiteCountBelow(m)) * ww
                        let rect = CGRect(x: cx - bw / 2, y: 0, width: bw, height: bh)
                        var p = Path()
                        p.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
                        ctx.fill(p, with: .color(self.colorFor(m)))
                    }
                    m += 1
                }

                for (i, midi) in ws.enumerated() where midi % 12 == 0 {
                    ctx.draw(
                        Text("C\(midi / 12 - 1)")
                            .font(.system(size: 7.5))
                            .foregroundColor(Color.black.opacity(0.34)),
                        at: CGPoint(x: CGFloat(i) * ww + ww / 2, y: sizeY - 7)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let midi = self.hitTest(value.location, ww: ww, bw: bw, bh: bh) {
                            self.onTap(midi)
                        }
                    }
            )
        }
    }

    private func whiteCountBelow(_ midi: Int) -> Int {
        var left = 0
        var k = self.low
        while k < midi {
            if !Keys.isBlack(k) { left += 1 }
            k += 1
        }
        return left
    }

    private func colorFor(_ midi: Int) -> Color {
        if let w = self.wrongKey, w == midi { return self.wrongFill }
        if self.hitKeys.contains(midi) { return self.doneFill }
        if self.expected.contains(midi) { return self.brass }
        return Keys.isBlack(midi) ? self.blackFill : self.whiteFill
    }

    private func hitTest(_ point: CGPoint, ww: CGFloat, bw: CGFloat, bh: CGFloat) -> Int? {
        if point.y <= bh {
            var m = self.low
            while m <= self.high {
                if Keys.isBlack(m) {
                    let cx = CGFloat(self.whiteCountBelow(m)) * ww
                    if abs(point.x - cx) <= bw / 2 { return m }
                }
                m += 1
            }
        }
        let idx = Int(floor(point.x / ww))
        let ws = self.whites
        guard idx >= 0 && idx < ws.count else { return nil }
        return ws[idx]
    }
}

// ============================================================
//  简谱文本解析：与网页版同一套格式
// ============================================================

enum JianpuParser {
    static let demo = """
    标题: 小星星（C 大调）
    右手: 1 1 5 5 | 6 6 5 - | 4 4 3 3 | 2 2 1 -
    右手: 5 5 4 4 | 3 3 2 - | 5 5 4 4 | 3 3 2 -
    左手: 1, - 5, - | 1, - 5, - | 4, - 1, - | 5, - 1, -
    左手: 1, - 5, - | 1, - 5, - | 4, - 1, - | 5, - 1, -
    """

    enum ParseError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self {
            case .message(let m): return m
            }
        }
    }

    private static let deg = [0, 0, 2, 4, 5, 7, 9, 11]

    static func parse(_ text: String) throws -> (title: String, measures: [RawMeasure]) {
        var rhBars: [[RawNote]] = []
        var lhBars: [[RawNote]] = []
        var cur = "rh"
        var title = ""

        let rows = text.components(separatedBy: CharacterSet.newlines)
        for row in rows {
            let line = row.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if let m = firstMatch(line, "^(标题|title)\\s*[:：]\\s*(.+)$", [.caseInsensitive]) {
                title = m[2].trimmingCharacters(in: .whitespaces)
                continue
            }

            var body = line
            if let m = firstMatch(line, "^(右手|左手|RH|LH|R|L)\\s*[:：]?\\s*(.*)$", [.caseInsensitive]) {
                let head = m[1]
                cur = (head.hasPrefix("左") || head.uppercased().hasPrefix("L")) ? "lh" : "rh"
                body = m[2]
            }

            let sections = body.components(separatedBy: CharacterSet(charactersIn: "|｜"))
            for sec in sections {
                let seg = sec.trimmingCharacters(in: .whitespaces)
                if seg.isEmpty { continue }
                let barNo = (cur == "rh" ? rhBars.count : lhBars.count) + 1
                let toks = findAll(seg, "[#b]?[0-7][',]*/?|-|\\[[^\\]]*\\]")
                if toks.isEmpty { continue }

                var notes: [RawNote] = []
                var beat = 0.0
                for tk in toks {
                    if tk == "-" {
                        if notes.isEmpty {
                            throw ParseError.message("第 \(barNo) 小节开头就是延音线「-」")
                        }
                        notes[notes.count - 1].dur += 1
                        beat += 1
                        continue
                    }
                    let half = tk.hasSuffix("/")
                    let core = half ? String(tk.dropLast()) : tk
                    var midis: [Int] = []
                    if core.hasPrefix("[") {
                        let inner = core
                            .replacingOccurrences(of: "[", with: "")
                            .replacingOccurrences(of: "]", with: "")
                        let parts = inner.components(separatedBy: CharacterSet(charactersIn: ",， "))
                        for part in parts where !part.isEmpty {
                            if let v = try midiOf(part) { midis.append(v) }
                        }
                        if midis.isEmpty {
                            throw ParseError.message("第 \(barNo) 小节的和弦是空的")
                        }
                    } else {
                        if let v = try midiOf(core) { midis = [v] }
                    }
                    if beat > 4.0001 {
                        throw ParseError.message("第 \(barNo) 小节超过 4 拍")
                    }
                    let len: Double = half ? 0.5 : 1
                    if !midis.isEmpty {
                        notes.append(RawNote(beat: beat, midis: midis, dur: len))
                    }
                    beat += len
                }
                if abs(beat - 4) > 0.0001 {
                    throw ParseError.message("第 \(barNo) 小节只写了 \(beat) 拍，必须满 4 拍")
                }
                if cur == "rh" { rhBars.append(notes) } else { lhBars.append(notes) }
            }
        }

        if rhBars.isEmpty {
            throw ParseError.message("没找到音符，请确认写了「右手:」并填入数字")
        }
        if !lhBars.isEmpty && lhBars.count != rhBars.count {
            throw ParseError.message("左手 \(lhBars.count) 小节、右手 \(rhBars.count) 小节，数量必须一致")
        }
        if rhBars.count > 64 {
            throw ParseError.message("小节太多（\(rhBars.count) 个），请分批导入")
        }

        var out: [RawMeasure] = []
        for i in 0..<rhBars.count {
            let lh: [RawNote] = i < lhBars.count ? lhBars[i] : []
            out.append(RawMeasure(chord: "", rh: rhBars[i], lh: lh))
        }
        return (title, out)
    }

    private static func midiOf(_ token: String) throws -> Int? {
        var acc = 0
        var i = token.startIndex
        if token.hasPrefix("#") { acc = 1; i = token.index(after: i) }
        else if token.hasPrefix("b") { acc = -1; i = token.index(after: i) }
        guard i < token.endIndex, let d = Int(String(token[i])) else {
            throw ParseError.message("看不懂的音符「\(token)」")
        }
        if d == 0 { return nil }
        var midi = 60 + deg[d] + acc
        var j = token.index(after: i)
        while j < token.endIndex {
            let ch = token[j]
            if ch == "'" { midi += 12 }
            else if ch == "," { midi -= 12 }
            else if ch == "/" { }
            else { throw ParseError.message("看不懂的音符「\(token)」") }
            j = token.index(after: j)
        }
        guard midi >= 21 && midi <= 108 else {
            throw ParseError.message("音高超出范围：「\(token)」")
        }
        return midi
    }

    private static func firstMatch(_ source: String,
                                  _ pattern: String,
                                  _ options: NSRegularExpression.Options = []) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = source as NSString
        guard let m = re.firstMatch(in: source, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        var out: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            out.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        return out
    }

    private static func findAll(_ source: String, _ pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = source as NSString
        return re.matches(in: source, options: [], range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }
}

// ============================================================
//  五线谱文件导入：MIDI（.mid/.midi）与 MusicXML（.musicxml/.xml）
// ============================================================

enum ScoreFileError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let m): return m
        }
    }
}

enum MidiParser {
    struct Ev {
        let tick: Int
        let midi: Int
        let len: Int
    }

    static func parse(_ data: Data, title: String) throws -> (title: String, measures: [RawMeasure]) {
        let bytes = [UInt8](data)
        guard bytes.count >= 14 else { throw ScoreFileError.message("文件太小，不像是 MIDI") }
        guard bytes[0] == 0x4D, bytes[1] == 0x54, bytes[2] == 0x68, bytes[3] == 0x64 else {
            throw ScoreFileError.message("不是 MIDI 文件（没有 MThd 文件头）")
        }
        let division = (Int(bytes[12]) << 8) | Int(bytes[13])
        guard division > 0 else { throw ScoreFileError.message("MIDI 时间基准无效") }
        let ppq = Double(division)
        let barLength = 4.0

        var pos = 14
        var tracks: [[Ev]] = []
        var metaTitle = ""

        while pos + 8 <= bytes.count {
            let isTrack = bytes[pos] == 0x4D && bytes[pos + 1] == 0x54 && bytes[pos + 2] == 0x72 && bytes[pos + 3] == 0x6B
            if !isTrack { break }
            let len = (Int(bytes[pos + 4]) << 24) | (Int(bytes[pos + 5]) << 16) | (Int(bytes[pos + 6]) << 8) | Int(bytes[pos + 7])
            let end = min(pos + 8 + max(0, len), bytes.count)
            var q = pos + 8
            var tick = 0
            var running: UInt8 = 0
            var notes: [Ev] = []
            var open: [Int: Int] = [:]

            while q < end {
                var delta = 0
                var more = true
                while more && q < end {
                    let b = bytes[q]
                    q += 1
                    delta = (delta << 7) | Int(b & 0x7F)
                    more = (b & 0x80) != 0
                }
                tick += delta
                if q >= end { break }

                var status = bytes[q]
                if (status & 0x80) != 0 {
                    q += 1
                    if status < 0xF0 { running = status }
                } else {
                    status = running
                }
                if status == 0 { break }

                let hi = status & 0xF0
                if hi == 0x90 || hi == 0x80 {
                    if q + 1 >= end { break }
                    let note = Int(bytes[q] & 0x7F)
                    let vel = Int(bytes[q + 1] & 0x7F)
                    q += 2
                    if hi == 0x90 && vel > 0 {
                        if open[note] == nil { open[note] = tick }
                    } else if let start = open.removeValue(forKey: note) {
                        notes.append(Ev(tick: start, midi: note, len: max(1, tick - start)))
                    }
                } else if hi == 0xC0 || hi == 0xD0 {
                    q += 1
                } else if hi == 0xA0 || hi == 0xB0 || hi == 0xE0 {
                    q += 2
                } else if status == 0xFF {
                    if q >= end { break }
                    let type = bytes[q]
                    q += 1
                    var metaLen = 0
                    var moreMeta = true
                    while moreMeta && q < end {
                        let b = bytes[q]
                        q += 1
                        metaLen = (metaLen << 7) | Int(b & 0x7F)
                        moreMeta = (b & 0x80) != 0
                    }
                    let stop = min(q + metaLen, end)
                    if type == 0x03 && q < stop {
                        let raw = Array(bytes[q..<stop])
                        if let t = String(bytes: raw, encoding: .utf8) { metaTitle = t }
                    }
                    q = stop
                } else if status == 0xF0 || status == 0xF7 {
                    var sysLen = 0
                    var moreSys = true
                    while moreSys && q < end {
                        let b = bytes[q]
                        q += 1
                        sysLen = (sysLen << 7) | Int(b & 0x7F)
                        moreSys = (b & 0x80) != 0
                    }
                    q = min(q + sysLen, end)
                } else {
                    break
                }
            }

            for (note, start) in open {
                notes.append(Ev(tick: start, midi: note, len: 1))
            }
            if !notes.isEmpty { tracks.append(notes) }
            pos = end
        }

        guard !tracks.isEmpty else { throw ScoreFileError.message("MIDI 里没有找到音符") }

        var rhList: [Ev] = []
        var lhList: [Ev] = []
        if tracks.count >= 2 {
            let sumA = tracks[0].reduce(0) { $0 + $1.midi }
            let sumB = tracks[1].reduce(0) { $0 + $1.midi }
            if sumA >= sumB {
                rhList = tracks[0]
                lhList = tracks[1]
            } else {
                rhList = tracks[1]
                lhList = tracks[0]
            }
        } else {
            for e in tracks[0] {
                if e.midi >= 60 { rhList.append(e) } else { lhList.append(e) }
            }
        }

        func buildBars(_ list: [Ev], limit: Int) -> [[RawNote]] {
            var map: [Int: [RawNote]] = [:]
            for e in list {
                let beat = Double(e.tick) / ppq
                let bar = Int(floor(beat / barLength))
                if bar < 0 || bar >= limit { continue }
                let inBar = beat - Double(bar) * barLength
                let dur = min(barLength, max(0.25, Double(e.len) / ppq))
                map[bar, default: []].append(RawNote(beat: inBar, midis: [e.midi], dur: dur))
            }
            if map.isEmpty { return [] }
            let top = map.keys.max() ?? 0
            var out: [[RawNote]] = []
            for i in 0...top {
                out.append((map[i] ?? []).sorted { $0.beat < $1.beat })
            }
            return out
        }

        let rhBars = buildBars(rhList, limit: 64)
        let lhBars = buildBars(lhList, limit: 64)
        let count = max(rhBars.count, lhBars.count)
        guard count > 0 else { throw ScoreFileError.message("按 4/4 切分后没有任何小节") }

        var out: [RawMeasure] = []
        for i in 0..<count {
            let rh: [RawNote] = i < rhBars.count ? rhBars[i] : []
            let lh: [RawNote] = i < lhBars.count ? lhBars[i] : []
            out.append(RawMeasure(chord: "", rh: rh, lh: lh))
        }

        var finalTitle = metaTitle.isEmpty ? title : metaTitle
        if count >= 64 { finalTitle += "（只取前 64 小节）" }
        return (finalTitle, out)
    }
}

enum MusicXmlParser {
    private static let stepValue: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    static func parse(_ text: String, fallbackTitle: String) throws -> (title: String, measures: [RawMeasure]) {
        guard text.contains("<score-partwise") || text.contains("<score-timewise") else {
            throw ScoreFileError.message("不是 MusicXML（缺少 score-partwise 根节点）")
        }
        let title = innerText(text, "work-title") ?? innerText(text, "movement-title") ?? fallbackTitle

        var parts: [String] = []
        var cursor = text.startIndex
        while let a = text.range(of: "<part ", range: cursor..<text.endIndex),
              let b = text.range(of: "</part>", range: a.upperBound..<text.endIndex) {
            parts.append(String(text[a.lowerBound..<b.upperBound]))
            cursor = b.upperBound
        }
        if parts.isEmpty,
           let a = text.range(of: "<part>"),
           let b = text.range(of: "</part>", range: a.upperBound..<text.endIndex) {
            parts.append(String(text[a.lowerBound..<b.upperBound]))
        }
        guard !parts.isEmpty else { throw ScoreFileError.message("没有找到 <part> 乐谱内容") }

        var rhBars: [[RawNote]] = []
        var lhBars: [[RawNote]] = []
        let splitByStaff = parts.count == 1

        for (pi, part) in parts.enumerated() {
            if !splitByStaff && pi > 1 { break }
            var divisions = 1.0
            var cur = part.startIndex
            while let a = part.range(of: "<measure", range: cur..<part.endIndex),
                  let b = part.range(of: "</measure>", range: a.upperBound..<part.endIndex) {
                let body = String(part[a.upperBound..<b.lowerBound])
                if let d = Double(innerText(body, "divisions") ?? ""), d > 0 { divisions = d }

                var staffTime: [Int: Double] = [1: 0.0, 2: 0.0]
                var lastPos: [Int: Double] = [:]
                var notesHere: [Int: [RawNote]] = [1: [], 2: []]

                var nc = body.startIndex
                while let na = body.range(of: "<note", range: nc..<body.endIndex),
                      let nb = body.range(of: "</note>", range: na.upperBound..<body.endIndex) {
                    let nbBody = String(body[na.upperBound..<nb.lowerBound])
                    nc = nb.upperBound

                    let staff = Int(innerText(nbBody, "staff") ?? "1") ?? 1
                    let isChord = nbBody.contains("<chord/>") || nbBody.contains("<chord />")
                    let isRest = nbBody.contains("<rest")
                    let rawDur = Double(innerText(nbBody, "duration") ?? "") ?? divisions
                    var beats = rawDur / divisions
                    if beats <= 0 { beats = 1.0 }

                    var pos = staffTime[staff] ?? 0.0
                    if isChord, let last = lastPos[staff] { pos = last }
                    staffTime[staff] = pos + beats

                    if !isRest,
                       let step = innerText(nbBody, "step"),
                       let octave = Int(innerText(nbBody, "octave") ?? "") {
                        let alter = Int(innerText(nbBody, "alter") ?? "0") ?? 0
                        if let firstChar = step.first, let base = stepValue[firstChar] {
                            let midi = 12 * (octave + 1) + base + alter
                            if midi >= 21 && midi <= 108 {
                                let note = RawNote(beat: min(3.75, pos),
                                                   midis: [midi],
                                                   dur: min(4.0, max(0.25, beats)))
                                notesHere[staff, default: []].append(note)
                                if !isChord { lastPos[staff] = pos }
                            }
                        }
                    }
                }

                if splitByStaff {
                    rhBars.append((notesHere[1] ?? []).sorted { $0.beat < $1.beat })
                    lhBars.append((notesHere[2] ?? []).sorted { $0.beat < $1.beat })
                } else if pi == 0 {
                    let merged = (notesHere[1] ?? []) + (notesHere[2] ?? [])
                    rhBars.append(merged.sorted { $0.beat < $1.beat })
                } else {
                    let merged = (notesHere[1] ?? []) + (notesHere[2] ?? [])
                    lhBars.append(merged.sorted { $0.beat < $1.beat })
                }
                cur = b.upperBound
            }
        }

        let count = min(64, max(rhBars.count, lhBars.count))
        guard count > 0 else { throw ScoreFileError.message("没有解析到音符，请确认导出的是含 <note> 的 MusicXML") }

        var out: [RawMeasure] = []
        for i in 0..<count {
            let rh: [RawNote] = i < rhBars.count ? rhBars[i] : []
            let lh: [RawNote] = i < lhBars.count ? lhBars[i] : []
            out.append(RawMeasure(chord: "", rh: rh, lh: lh))
        }
        var finalTitle = title
        if max(rhBars.count, lhBars.count) > 64 { finalTitle += "（只取前 64 小节）" }
        return (finalTitle, out)
    }

    private static func innerText(_ source: String, _ tag: String) -> String? {
        guard let a = source.range(of: "<" + tag),
              let b = source.range(of: "</" + tag + ">", range: a.upperBound..<source.endIndex) else { return nil }
        var inner = String(source[a.upperBound..<b.lowerBound])
        if let gt = inner.firstIndex(of: ">") {
            inner = String(inner[inner.index(after: gt)...])
        }
        let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
