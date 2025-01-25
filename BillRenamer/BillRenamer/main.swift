//
//  main.swift
//  BillRenamer
//
//  Created by John Peden on 1/24/25.
//

import Foundation
import FeedKit
import OpenAI

try await RSSFeed(urlString: "https://www.whitehouse.gov/presidential-actions/feed")
    .channel?
    .items?
    .prefix(3)
    .map {
        ChatQuery(
            messages: [
                .system(.init(content: Prompts.preprompt)),
                .user(.init(content: .string($0.content?.encoded ?? "")))
            ],
            model: .gpt4_o_mini
        )
    }
    .asyncMap {
        try await OpenAI(apiToken: Keys.openAI).chats(query: $0)
    }
    .map {
        return AIResponseInfo(
            response: $0.choices.first?.message.content?.string ?? "",
            usage: $0.usage! // yeah, I know
        )
    }
    .forEach {
        print("\($0.response)\nCost: \($0.cost)\n\n")
    }

struct AIResponseInfo {
    let response: String
    let usage: ChatResult.CompletionUsage
    var cost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        return formatter.string(
            from: NSNumber(
                value: calculatePrompt(usage.promptTokens) + calculateCompletion(usage.completionTokens)
            )
        )! // yeah ! is bad I know
    }
    
    
    private func calculatePrompt(_ x: Int) -> Double {
        (Double(x) / 1000.0) * 0.00250
    }
    
    private func calculateCompletion(_ x: Int) -> Double {
        (Double(x) / 1000.0) * 0.01000
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

