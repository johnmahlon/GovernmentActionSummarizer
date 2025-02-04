//
//  main.swift
//  BillRenamer
//
//  Created by John Peden on 1/24/25.
//

import Foundation
import FeedKit
import OpenAI

let previousRunPath = "/Users/johnpeden/Developer/BillRenamer/bill_feed_old.xml"
let prevRunStr = try String(contentsOfFile: previousRunPath, encoding: .utf8)
let prevRun = try RSSFeed(data: prevRunStr.data(using: .utf8)!)

print(try await createFeed())

func createFeed() async throws -> String {
    guard let presActionItems = try await RSSFeed(
        urlString: "https://www.whitehouse.gov/presidential-actions/feed"
    ).channel?.items else {
        print("Initial RSS Feed Failes")
        return prevRunStr
    }

    let limitedItems = presActionItems
        .filter {
            guard let pubDate = $0.pubDate else { return false }
                let today = Date()
                let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
                return pubDate >= oneWeekAgo && pubDate <= today
        }
        .sorted {
            $0.pubDate! > $1.pubDate!
        }
        .prefix(10)
        .filter { curr in
            return !prevRun.channel!.items!.contains { prev in
                prev.link! == curr.link!
            }
        }

    let queries = limitedItems
        .map {
            ChatQuery(
                messages: [
                    .system(.init(content: Prompts.preprompt)),
                    .user(.init(content: .string($0.content?.encoded ?? ""))),
                    .user(.init(content: .string($0.link ?? "No Link")))
                    
                ],
                model: .gpt4_o_mini
            )
        }

    let responses = try await queries
        .asyncMap {
            try await OpenAI(apiToken: Keys.openAI).chats(query: $0)
        }
        .map {
            return AIResponseInfo(
                response: $0.choices.first?.message.content?.string ?? "",
                usage: $0.usage!
            )
        }
        .map {
            try JSONDecoder().decode(GPTResponse.self, from: $0.response.data(using: .utf8)!)
        }

    let newFeedItems = responses
        .map {
            var description = $0.summary
            description += "\n\nDisclaimer: This response is AI-generated and may contain inaccuracies, outdated information, or absurd claims. Use at your own risk."
            return RSSFeedItem(title: $0.title, link: $0.link, description: description)
        }
        

    let totalFeed = newFeedItems + (prevRun.channel?.items ?? [])
        .prefix(10)
       

    let feed = RSSFeed(channel: .init(title: "Presidential Action Summaries", items: totalFeed))
    return try feed.toXMLString(formatted: true)
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

