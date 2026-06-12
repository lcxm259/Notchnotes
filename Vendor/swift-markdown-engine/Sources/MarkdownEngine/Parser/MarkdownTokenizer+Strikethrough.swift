//
//  MarkdownTokenizer+Strikethrough.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 13.06.26.
//
//  Parser for `~~`-delimited strikethrough (GitHub Flavored Markdown).
//

import Foundation

extension MarkdownTokenizer {
    static func parseStrikethroughTokens(in text: String) -> [MarkdownToken] {
        let nsText = text as NSString
        let len = nsText.length
        guard len > 0 else { return [] }

        let runs = collectTildeRuns(in: nsText, length: len)
        guard !runs.isEmpty else { return [] }

        var tokens: [MarkdownToken] = []
        var openers: [TildeRun] = []

        for run in runs {
            if run.openable && run.closeable {
                // Intra-word run — can be either opener or closer, prefer closer.
                if let openerIdx = openers.lastIndex(where: { $0.lineIdx == run.lineIdx }) {
                    let opener = openers[openerIdx]
                    tokens.append(makeToken(opener: opener, closer: run))
                    openers.remove(at: openerIdx)
                } else {
                    openers.append(run)
                }
            } else if run.openable {
                openers.append(run)
            } else if run.closeable {
                // Find matching opener on the same line
                if let openerIdx = openers.lastIndex(where: { $0.lineIdx == run.lineIdx }) {
                    let opener = openers[openerIdx]
                    tokens.append(makeToken(opener: opener, closer: run))
                    openers.remove(at: openerIdx)
                }
            }
        }

        return tokens
    }

    private struct TildeRun {
        let start: Int        // index of first tilde
        let end: Int          // index after last tilde
        let openable: Bool
        let closeable: Bool
        let lineIdx: Int
    }

    private static func collectTildeRuns(in nsText: NSString, length len: Int) -> [TildeRun] {
        var result: [TildeRun] = []
        var lineIdx = 0
        var i = 0
        while i < len {
            let c = nsText.character(at: i)
            if c == 0x0A {
                lineIdx += 1
                i += 1
                continue
            }
            // 0x7E is '~'
            if c != 0x7E {
                i += 1
                continue
            }
            // Count consecutive tildes
            var j = i
            while j < len, nsText.character(at: j) == 0x7E {
                j += 1
            }
            let runLen = j - i
            // Only runs of exactly 2 tildes matter for strikethrough
            if runLen == 2 {
                let beforeIdx = i - 1
                let afterIdx = j
                let beforeWs = isWhitespaceOrBoundary(at: beforeIdx, in: nsText, length: len)
                let beforePunct = isAsciiPunctuation(at: beforeIdx, in: nsText, length: len)
                let afterWs = isWhitespaceOrBoundary(at: afterIdx, in: nsText, length: len)
                let afterPunct = isAsciiPunctuation(at: afterIdx, in: nsText, length: len)

                // CommonMark flanking rules: left-flanking = can open, right-flanking = can close
                let leftFlanking = !afterWs && (!afterPunct || beforeWs || beforePunct)
                let rightFlanking = !beforeWs && (!beforePunct || afterWs || afterPunct)

                result.append(TildeRun(
                    start: i,
                    end: j,
                    openable: leftFlanking,
                    closeable: rightFlanking,
                    lineIdx: lineIdx
                ))
            }
            i = j
        }
        return result
    }

    private static func makeToken(opener: TildeRun, closer: TildeRun) -> MarkdownToken {
        let fullStart = opener.start
        let fullEnd = closer.end
        let contentStart = opener.end  // right after `~~`
        let contentEnd = closer.start  // right before `~~`

        return MarkdownToken(
            kind: .strikethrough,
            range: NSRange(location: fullStart, length: fullEnd - fullStart),
            contentRange: NSRange(location: contentStart, length: max(0, contentEnd - contentStart)),
            markerRanges: [
                NSRange(location: opener.start, length: 2),
                NSRange(location: closer.start, length: 2)
            ]
        )
    }

    // MARK: - Character classification (mirrors Emphasis helpers)

    private static func isWhitespaceOrBoundary(at idx: Int, in nsText: NSString, length len: Int) -> Bool {
        guard idx >= 0 && idx < len else { return true }
        let c = nsText.character(at: idx)
        return c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }

    private static func isAsciiPunctuation(at idx: Int, in nsText: NSString, length len: Int) -> Bool {
        guard idx >= 0 && idx < len else { return false }
        let c = nsText.character(at: idx)
        return (c >= 0x21 && c <= 0x2F)
            || (c >= 0x3A && c <= 0x40)
            || (c >= 0x5B && c <= 0x60)
            || (c >= 0x7B && c <= 0x7E)
    }
}
