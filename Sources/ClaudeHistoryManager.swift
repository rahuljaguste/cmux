import AppKit
import SwiftUI

struct ClaudeHistorySession: Identifiable {
    let id: String // sessionId
    let sessionId: String
    let project: String
    let firstMessage: String
    let lastTimestamp: Date
    let messageCount: Int

    var projectName: String {
        (project as NSString).lastPathComponent
    }
}

final class ClaudeHistoryManager {
    static let shared = ClaudeHistoryManager()

    private let historyPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/history.jsonl"
    }()

    func loadSessions() -> [ClaudeHistorySession] {
        guard let data = FileManager.default.contents(atPath: historyPath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        struct RawEntry {
            let display: String
            let timestamp: Date
            let project: String
            let sessionId: String
        }

        var entriesBySession: [String: [RawEntry]] = [:]

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let display = json["display"] as? String,
                  let timestampMs = json["timestamp"] as? Double,
                  let project = json["project"] as? String,
                  let sessionId = json["sessionId"] as? String else {
                continue
            }

            let entry = RawEntry(
                display: display,
                timestamp: Date(timeIntervalSince1970: timestampMs / 1000.0),
                project: project,
                sessionId: sessionId
            )
            entriesBySession[sessionId, default: []].append(entry)
        }

        var sessions: [ClaudeHistorySession] = []
        for (sessionId, entries) in entriesBySession {
            guard let first = entries.first,
                  let last = entries.max(by: { $0.timestamp < $1.timestamp }) else {
                continue
            }

            let meaningfulMessage = entries.first(where: {
                !$0.display.trimmingCharacters(in: .whitespaces).hasPrefix("/") &&
                $0.display.trimmingCharacters(in: .whitespaces).count > 1
            })?.display ?? first.display

            let trimmed = meaningfulMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = trimmed.count > 80 ? String(trimmed.prefix(77)) + "..." : trimmed

            sessions.append(ClaudeHistorySession(
                id: sessionId,
                sessionId: sessionId,
                project: first.project,
                firstMessage: title,
                lastTimestamp: last.timestamp,
                messageCount: entries.count
            ))
        }

        sessions.sort { $0.lastTimestamp > $1.lastTimestamp }
        return Array(sessions.prefix(30))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
