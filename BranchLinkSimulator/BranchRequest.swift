//
//  BranchRequest.swift
//  BranchLinkSimulator
//
//  Created by Brice Redmond on 11/20/24.
//

import Foundation

struct RoundTrip: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let request: BranchRequest
    var response: BranchResponse?

    init(id: UUID = UUID(), timestamp: Date, request: BranchRequest, response: BranchResponse? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.request = request
        self.response = response
    }
}


struct BranchRequest: Codable {
    var url: String
    var headers: String
    var body: String
}

struct BranchResponse: Codable {
    var url: String
    var statusCode: String
    var headers: String
    var body: String
}

let FAILED = "failed to parse"

let requestViewModel = RequestViewModel()

func processLog(_ log: String) {
    if log.contains("[BNCServerInterface preparePostRequest"){
        let request = parseRequestLog(log)
        requestViewModel.addRequest(request)
    } else if log.contains("[BNCServerInterface processServerResponse") {
        let response = parseResponseLog(log)
        requestViewModel.addResponse(response)
    } else {
        print(log)
    }
}

func parseUrl(_ log: String) -> String? {
    if let urlRange = log.range(of: "(?<=URL: ).*?(?= \\})", options: .regularExpression) {
        return String(log[urlRange])
    }
    return nil
}

func parseHeaders(_ log: String) -> String? {
    if let headersStart = log.range(of: "Headers {")?.upperBound,
       let headersEnd = log.range(of: "}\nBody {")?.lowerBound {
        return String("{\(log[headersStart..<headersEnd])").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return nil
}

func parseBody(_ log: String) -> String? {
    if let bodyStart = log.range(of: "Body {")?.upperBound {
        return String("{\(log[bodyStart...])").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return nil
}


func parseRequestLog(_ log: String) -> BranchRequest {
    return BranchRequest(
        url: parseUrl(log) ?? FAILED,
        headers: parseHeaders(log) ?? FAILED,
        body: parseBody(log) ?? FAILED
    )
}


func parseResponseLog(_ log: String) -> BranchResponse {
    let statusCode = log.range(of: "(?<=Status Code: )\\d+", options: .regularExpression)
        .flatMap { Int(log[$0]) }
        .map { String($0) }

    return BranchResponse(
        url: parseUrl(log) ?? FAILED,
        statusCode: statusCode ?? FAILED,
        headers: parseHeaders(log) ?? FAILED,
        body: parseBody(log) ?? FAILED
    )
}
