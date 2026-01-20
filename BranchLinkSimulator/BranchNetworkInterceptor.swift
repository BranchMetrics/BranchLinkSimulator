//
//  BranchNetworkInterceptor.swift
//  BranchLinkSimulator
//
//  Intercepts Branch SDK network requests to count OPEN requests
//

import Foundation

/// URLProtocol subclass to intercept and log Branch SDK network requests
class BranchNetworkInterceptor: URLProtocol {
    // Static store reference for logging
    weak static var store: RoundTripStore?

    // Track which requests we've handled to avoid duplicates
    private static let handledKey = "BranchNetworkInterceptor.handled"

    // MARK: - URLProtocol Override

    override class func canInit(with request: URLRequest) -> Bool {
        // Avoid handling the same request twice
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }

        // Only intercept Branch API requests
        guard let url = request.url?.absoluteString else { return false }

        let branchDomains = [
            "api.branch.io",
            "api2.branch.io",
            "protected-api.branch.io",
            "api-stg.branch.io",
            "api2-stg.branch.io",
        ]

        return branchDomains.contains { url.contains($0) }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Mark this request as handled
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "BranchInterceptor", code: -1))
            return
        }

        URLProtocol.setProperty(true, forKey: BranchNetworkInterceptor.handledKey, in: mutableRequest)

        // Log the request
        logRequest(mutableRequest as URLRequest)

        // Forward the request
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: mutableRequest as URLRequest)
        task.resume()
    }

    override func stopLoading() {
        // No-op
    }

    // MARK: - Request Logging

    private func logRequest(_ request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Check if this is an OPEN request
        let isOpenRequest = isOpenRequest(url: url, body: body)

        if isOpenRequest {
            DispatchQueue.main.async {
                BranchNetworkInterceptor.store?.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                BranchNetworkInterceptor.store?.addLogEntry("[INTERCEPTOR] 🔴 OPEN REQUEST DETECTED!")
                BranchNetworkInterceptor.store?.addLogEntry("[INTERCEPTOR] URL: \(url)")
                BranchNetworkInterceptor.store?.addLogEntry("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Add round trip for counting
                let branchRequest = BranchRequest(
                    headers: request.allHTTPHeaderFields?.description ?? "none",
                    body: body
                )
                BranchNetworkInterceptor.store?.addRoundTrip(with: branchRequest, url: url)
            }
        }
    }

    private func isOpenRequest(url: String, body: String) -> Bool {
        // Check for /v1/open endpoint
        if url.contains("/v1/open") {
            return true
        }

        // Check for /v2/event with "open" event
        if url.contains("/v2/event") {
            return body.contains("\"name\":\"open\"") || body.contains("\"name\": \"open\"")
        }

        return false
    }
}

// MARK: - URLSessionDataDelegate

extension BranchNetworkInterceptor: URLSessionDataDelegate {
    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)

        // Log response status
        if let httpResponse = response as? HTTPURLResponse {
            let url = dataTask.originalRequest?.url?.absoluteString ?? "unknown"
            let body = dataTask.originalRequest?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            if isOpenRequest(url: url, body: body) {
                DispatchQueue.main.async {
                    BranchNetworkInterceptor.store?.addLogEntry("[INTERCEPTOR] OPEN Response: \(httpResponse.statusCode)")

                    // Add response to the most recent round trip
                    let branchResponse = BranchResponse(
                        statusCode: String(httpResponse.statusCode),
                        body: "Response received"
                    )
                    BranchNetworkInterceptor.store?.addResponse(branchResponse)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        session.invalidateAndCancel()
    }
}
