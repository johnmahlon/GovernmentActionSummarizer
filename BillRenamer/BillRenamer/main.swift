//
//  main.swift
//  BillRenamer
//
//  Created by John Peden on 1/24/25.
//

import Foundation
import FeedKit


let feed = try await RSSFeed(urlString: "https://www.whitehouse.gov/presidential-actions/feed")

feed.channel?.items?.forEach {
    print($0.content)
}
