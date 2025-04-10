//
//  ApiDetails.swift
//  BranchLinkSimulator
//
//  Created by Brice Redmond on 11/19/24.
//

import Foundation

struct ApiConfiguration: Identifiable, Codable, Equatable {
    var id: String { appId }
    var name: String
    var branchKey: String
    var apiUrl: String
    var appId: String
    var staging: Bool
}

let STAGING = "[Stage] External Services"
let PRODUCTION = "Pro Production"
let STAGING_AC = "[Stage] Adv. Compliance Sandbox"
let PRODUCTION_AC = "Adv. Compliance Sandbox"
let STAGING_LS = "[Stage] LS + ENGMT Ess. Demo"
let PRODUCTION_LS = "LS + ENGMT Ess. Demo"


var apiConfigurationsMap: [String: ApiConfiguration] = [
    STAGING_LS: ApiConfiguration(
        name: STAGING_LS,
        branchKey: "key_live_nFc30jPoTV53LhvHat5XXffntufA4O0l",
        apiUrl: "https://api.stage.branch.io",
        appId: "1425582272655938028",
        staging: true
    ),
    STAGING_AC: ApiConfiguration(
        name: STAGING_AC,
        branchKey: "key_live_juoZrlpzQZvBQbwR33GO5hicszlTGnVT",
        apiUrl: "https://protected-api.stage.branch.io",
        appId: "1387589751543976586",
        staging: true
    ),
    STAGING: ApiConfiguration(
        name: STAGING,
        branchKey: "key_live_plqOidX7fW71Gzt0LdCThkemDEjCbTgx",
        apiUrl: "https://api.stage.branch.io",
        appId: "436637608899006753",
        staging: true
    ),
    PRODUCTION_LS: ApiConfiguration(
        name: PRODUCTION_LS,
        branchKey: "key_live_hsdXYiNiH9pfDv50xrFt0gbgEEiMIqFO",
        apiUrl: "https://api3.branch.io",
        appId: "1425583205569811094",
        staging: false
    ),
    PRODUCTION_AC: ApiConfiguration(
        name: PRODUCTION_AC,
        branchKey: "key_live_hshD4wiPK2sSxfkZqkH30ggmyBfmGmD7",
        apiUrl: "https://protected-api.branch.io",
        appId: "1284289243903971463",
        staging: false
    ),
    PRODUCTION: ApiConfiguration(
        name: PRODUCTION,
        branchKey: "key_live_iCh53eMdH5aIibeOqRYBojgpyrmU4gd8",
        apiUrl: "https://api3.branch.io",
        appId: "1425585005551178435",
        staging: false
    )
]
