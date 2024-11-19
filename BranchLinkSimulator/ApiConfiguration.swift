//
//  ApiDetails.swift
//  BranchLinkSimulator
//
//  Created by Brice Redmond on 11/19/24.
//

import Foundation

struct ApiConfiguration: Identifiable, Codable, Equatable {
    var id: String { appId }
    var branchKey: String
    var apiUrl: String
    var appId: String
    var staging: Bool
}

let STAGING = "Staging"
let PRODUCTION = "Production"
let STAGING_AC = "Staging AC"
let PRODUCTION_AC = "Production AC"


var apiConfigurationsMap: [String: ApiConfiguration] = [
    STAGING_AC: ApiConfiguration(
        branchKey: "key_live_juoZrlpzQZvBQbwR33GO5hicszlTGnVT",
        apiUrl: "https://protected-api.stage.branch.io",
        appId: "1387589751543976586",
        staging: true
    ),
    STAGING: ApiConfiguration(
        branchKey: "key_live_plqOidX7fW71Gzt0LdCThkemDEjCbTgx",
        apiUrl: "https://api.stage.branch.io",
        appId: "436637608899006753",
        staging: true
    ),
    PRODUCTION_AC: ApiConfiguration(
        branchKey: "key_live_hshD4wiPK2sSxfkZqkH30ggmyBfmGmD7",
        apiUrl: "https://protected-api.branch.io",
        appId: "1284289243903971463",
        staging: false
    ),
    PRODUCTION: ApiConfiguration(
        branchKey: "key_live_iDiV7ZewvDm9GIYxUnwdFdmmvrc9m3Aw",
        apiUrl: "https://api2.branch.io",
        appId: "1364964166783226677",
        staging: false
    )
]
