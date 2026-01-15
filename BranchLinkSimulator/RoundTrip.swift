//
//  RoundTrip.swift
//  BranchLinkSimulator
//
//  Created by Brice Redmond on 11/20/24.
//

import BranchSDK
import Foundation

struct RoundTrip: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let url: String
    let request: BranchRequest
    var response: BranchResponse?
    var isOpenRequest: Bool

    init(id: UUID = UUID(), timestamp: Date, url: String, request: BranchRequest, response: BranchResponse? = nil, isOpenRequest: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.request = request
        self.response = response
        self.isOpenRequest = isOpenRequest
    }
}

struct BranchRequest: Codable {
    var headers: String
    var body: String
}

struct BranchResponse: Codable {
    var statusCode: String
    var body: String
}
