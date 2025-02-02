//
//  models.swift
//  BillRenamer
//
//  Created by John Peden on 2/2/25.
//
import Foundation
import OpenAI

struct GPTResponse: Decodable {
    let title: String
    let summary: String
    let link: String
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
        )!
    }
    
    
    private func calculatePrompt(_ x: Int) -> Double {
        (Double(x) / 1000.0) * 0.00250
    }
    
    private func calculateCompletion(_ x: Int) -> Double {
        (Double(x) / 1000.0) * 0.01000
    }
}
