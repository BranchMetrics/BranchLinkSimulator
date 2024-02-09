//
//  ContentView.swift
//  BranchLinkSimulator
//
//  Created by Nipun Singh on 2/8/24.
//

import SwiftUI
import BranchSDK

struct ContentView: View {
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel

    var body: some View {
        NavigationView {
            VStack {
                if deepLinkViewModel.deepLinkHandled, let deepLinkData = deepLinkViewModel.deepLinkData {
                    NavigationLink(destination: DeeplinkDetailView(pageTitle: deepLinkData["page"] as? String ?? "Data", deepLinkParameters: deepLinkData), isActive: $deepLinkViewModel.deepLinkHandled) {
                        EmptyView()
                    }
                } else {
                    List {
                        Section(header: Text("Deep Link Pages")) {
                            NavigationLink("Go to Page A", destination: DeeplinkDetailView(pageTitle: "Page A", deepLinkParameters: [:]) )
                            NavigationLink("Go to Page B", destination: DeeplinkDetailView(pageTitle: "Page B", deepLinkParameters: [:]) )
                            NavigationLink("Go to Page C", destination: DeeplinkDetailView(pageTitle: "Page C", deepLinkParameters: [:]) )
                        }
                    }
                }
            }
        }
        .onAppear {
            // Reset the deep link handling flag if needed
            deepLinkViewModel.deepLinkHandled = false
        }
    }
}


#Preview {
    ContentView()
}
