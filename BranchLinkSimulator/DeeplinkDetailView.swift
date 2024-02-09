//
//  DeeplinkDetailView.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK

struct DeeplinkDetailView: View {
    let pageTitle: String
    let deepLinkParameters: [String: AnyObject]

    var body: some View {
        List {
            Section(header: Text("Deep Link Parameters")) {
                if deepLinkParameters.isEmpty {
                    Text("No Deep Link")
                } else {
                    ForEach(Array(deepLinkParameters.enumerated()), id: \.element.key) { index, element in
                        HStack {
                            Text(element.key)
                                .bold()
                            Spacer()
                            Text("\(stringRepresentation(of: element.value))")
                        }
                    }
                }
            }
            
            Section {
                Button(action: generateAndCopyBranchLink) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.white)
                        Text("Copy Link")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func generateAndCopyBranchLink() {
        let buo: BranchUniversalObject = BranchUniversalObject(canonicalIdentifier: "item/\(pageTitle)")
        buo.title = pageTitle
        buo.contentMetadata.customMetadata["page"] = pageTitle
        
        let lp: BranchLinkProperties = BranchLinkProperties()

        buo.getShortUrl(with: lp) { url, error in
            if let url = url {
                print(url)
                DispatchQueue.main.async {
                    UIPasteboard.general.string = url
                }
            }
        }
    }
    
    func stringRepresentation(of value: AnyObject) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            // NSNumber can represent both Bool and numeric values, handle Bool separately
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return numberValue.boolValue ? "true" : "false"
            }
            // For numeric values, use stringValue of NSNumber
            return numberValue.stringValue
        } else {
            // Default case, should not be reached if all values are String, Number, or Bool
            return "Invalid type"
        }
    }

}

