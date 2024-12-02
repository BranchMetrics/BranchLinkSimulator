import SwiftUI
import BranchSDK

let SELECTED_CONFIG_NAME = "selectedConfigName"

struct ApiSettingsView: View {
    @State private var selectedConfig: ApiConfiguration
    @State private var showReloadAlert = false

    init() {
        selectedConfig = loadConfigOrDefault()
    }
    
    var body: some View {
        ApiInfoView(label: "Branch Key", value: selectedConfig.branchKey)
        ApiInfoView(label: "Api Url", value: selectedConfig.apiUrl)
        ApiInfoView(label: "App Id", value: selectedConfig.appId)

        Menu {
            ForEach(apiConfigurationsMap.keys.sorted(), id: \.self) { configName in
                Button(action: { switchToConfig(key: configName) }) {
                    Text(configName)
                }
            }
        } label: {
            HStack {
                Text("Selected: \(selectedConfig.name)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                Spacer()
                Image(systemName: "chevron.down")
                    .padding(.trailing)
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
            Text("\(label):")
                .font(.body)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
            HStack {
                Text("\(value)")
                    .font(.body)
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
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct ApiSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        ApiSettingsView()
    }
}
