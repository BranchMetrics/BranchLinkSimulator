import SwiftUI
import BranchSDK

let SELECTED_CONFIG_NAME = "selectedConfigName"

struct ApiSettingsView: View {
    @State private var selectedConfig: ApiConfiguration
    @State private var showReloadAlert = false
    @State private var newApiUrl: String
    private var store: RoundTripStore
    
    private var customApiKey = "custom_api_url_override"

    init(store: RoundTripStore) {
        _selectedConfig = State(initialValue: loadConfigOrDefault())
        self.store = store
        _newApiUrl = State(initialValue: _selectedConfig.wrappedValue.apiUrl)
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
                    Image(systemName: "chevron.up.chevron.down")
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
        
        VStack(alignment: .leading) {
            Text("Update Current API URL")
                .font(.headline)
            HStack {
                TextField("Enter new API URL", text: $newApiUrl)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Apply") {
                    applyCustomApiUrl()
                }
                .buttonStyle(.borderedProminent)
            }
            Text("This will override the API URL for the current configuration.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)

        NavigationLink(destination: RoundTripView(store: store)) {
            Label("API Request Log", systemImage: "doc.text.below.ecg.fill")
        }
    }
    
    private func switchToConfig(key: String) {
        guard let config = apiConfigurationsMap[key] else { return }
        if selectedConfig != config {
            selectedConfig = config
            saveConfig(configName: getConfigName(selectedConfig))
            UserDefaults.standard.removeObject(forKey: customApiKey)
            showReloadAlert = true
        }
    }
    
    private func applyCustomApiUrl() {
        UserDefaults.standard.set(newApiUrl, forKey: customApiKey)
        showReloadAlert = true
    }
    
    func getConfigName(_ config: ApiConfiguration) -> String {
        for (key, value) in apiConfigurationsMap {
            if value == config {
                return key
            }
        }
        return PRODUCTION
    }
    
    func saveConfig(configName: String) {
        UserDefaults.standard.set(configName, forKey: SELECTED_CONFIG_NAME)
    }
}

func loadConfigOrDefault() -> ApiConfiguration {
    var baseConfig = loadConfig() ?? apiConfigurationsMap[PRODUCTION] ?? ApiConfiguration(name: "N/A", branchKey: "N/A", apiUrl: "N/A", appId: "N/A", staging: false)
    
    if let customUrl = UserDefaults.standard.string(forKey: "custom_api_url_override") {
        baseConfig.apiUrl = customUrl
    }
    return baseConfig
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
