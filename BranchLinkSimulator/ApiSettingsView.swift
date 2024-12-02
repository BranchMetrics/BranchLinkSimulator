import SwiftUI
import BranchSDK

let SELECTED_CONFIG_NAME = "selectedConfigName"

struct ApiSettingsView: View {
    @State private var selectedConfig: ApiConfiguration
    @State private var showReloadAlert = false
    private var store: RoundTripStore

    init(store: RoundTripStore) {
        selectedConfig = loadConfigOrDefault()
        self.store = store
    }
    
    var body: some View {
        ApiInfoView(label: "Branch Key", value: selectedConfig.branchKey)
        ApiInfoView(label: "API URL", value: selectedConfig.apiUrl)
        ApiInfoView(label: "App ID", value: selectedConfig.appId)

        HStack {
            Text("API Config")
                .font(.headline)

            Spacer()
            
            Menu {
                ForEach(apiConfigurationsMap.keys.sorted(), id: \.self) { configName in
                    Button(action: { switchToConfig(key: configName) }) {
                        Text(configName)
                    }
                }
            } label: {
                HStack {
                    Text("\(selectedConfig.name)")
                    Image(systemName: "chevron.down")
                }
            }
            .alert(isPresented: $showReloadAlert) {
                Alert(
                    title: Text("Configuration Changed"),
                    message: Text("You need to reload the app to apply the new API configuration."),
                    primaryButton: .default(Text("Close App")) {
                        exit(0)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        
        NavigationLink(destination: RoundTripView(store: store)) {
            Label("API Request Log", systemImage: "doc.text.below.ecg.fill")
        }
    }
    
    private func switchToConfig(key: String) {
        guard let config = apiConfigurationsMap[key] else { return }
        if selectedConfig != config {
            selectedConfig = config
            saveConfig(configName: getConfigName(selectedConfig))
            showReloadAlert = true
        }
    }
    
    func getConfigName(_ config: ApiConfiguration) -> String {
        for (key, value) in apiConfigurationsMap {
            if value == config {
                return key
            }
        }
        return STAGING
    }
    
    func saveConfig(configName: String) {
        UserDefaults.standard.set(configName, forKey: SELECTED_CONFIG_NAME)
    }
}

func loadConfigOrDefault() -> ApiConfiguration {
    loadConfig() ?? apiConfigurationsMap[STAGING] ?? ApiConfiguration(name: "N/A", branchKey: "N/A", apiUrl: "N/A", appId: "N/A", staging: false)
}

func loadConfig() -> ApiConfiguration? {
    if let configName = UserDefaults.standard.string(forKey: SELECTED_CONFIG_NAME),
       let config = apiConfigurationsMap[configName] {
        return config
    }
    return nil
}

struct ApiInfoView: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(label)")
                .font(.headline)
                .multilineTextAlignment(.leading)
            HStack {
                Text("\(value)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = value
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.blue)
                }
            }
        }
        .multilineTextAlignment(.leading)
    }
}
