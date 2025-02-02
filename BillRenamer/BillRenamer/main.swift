//
//  main.swift
//  BillRenamer
//
//  Created by John Peden on 1/24/25.
//

import Foundation
import FeedKit
import OpenAI

let presActionItems = try await RSSFeed(urlString: "https://www.whitehouse.gov/presidential-actions/feed")
    .channel?
    .items?
    .filter {
        guard let pubDate = $0.pubDate else { return false }
            let today = Date()
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            return pubDate >= oneWeekAgo && pubDate <= today
    }
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
    .map {
        try JSONDecoder().decode(GPTResponse.self, from: $0.response.data(using: .utf8)!)
    }
    .map {
        RSSFeedItem(title: $0.title, description: "\($0.summary)\n\n\($0.bias)")
    }
   

let feed = RSSFeed(channel: .init(title: "Non-Political Orders", items: presActionItems))

print(try feed.toXMLString(formatted: true))

struct GPTResponse: Decodable {
    let title: String
    let summary: String
    let bias: String
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

