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
    @State private var showingToast = false

    var body: some View {
        List {
            Section(header: Text("Deep Link Parameters")) {
                if deepLinkParameters.isEmpty {
                    Text("Open Deep Link To View Parameters")
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
        .toast(isShowing: $showingToast, text: Text("Link Copied!"))
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
                    self.showToast()
                }
            }
        }
    }
    
    func stringRepresentation(of value: AnyObject) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return numberValue.boolValue ? "true" : "false"
            }
            return numberValue.stringValue
        } else {
            return "Invalid type"
        }
    }
    
    func showToast() {
        self.showingToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showingToast = false
        }
    }

}

extension View {
    func toast(isShowing: Binding<Bool>, text: Text) -> some View {
        ZStack(alignment: .bottom) {
            self
            
            if isShowing.wrappedValue {
                VStack {
                    Spacer()
                    text
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground).opacity(1))
                        .foregroundColor(Color.blue)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .transition(.opacity)
                .onTapGesture {
                    withAnimation {
                        isShowing.wrappedValue = false
                    }
                }
                .zIndex(1)
            }
        }
        .animation(.easeInOut, value: isShowing.wrappedValue)
    }
}

