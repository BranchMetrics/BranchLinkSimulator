//
//  RoundTrip.swift
//  BranchLinkSimulator
//
//  Created by Brice Redmond on 11/20/24.
//

import Foundation

struct RoundTrip: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let url: String
    let request: BranchRequest
    var response: BranchResponse?

    init(id: UUID = UUID(), timestamp: Date, url: String, request: BranchRequest, response: BranchResponse? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.request = request
        self.response = response
    }
}

struct BranchRequest: Codable {
    var headers: String
    var body: String
}

struct BranchResponse: Codable {
    var statusCode: String
    var headers: String
    var body: String
}


