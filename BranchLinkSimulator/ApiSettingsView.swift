import SwiftUI
import BranchSDK

let SELECTED_CONFIG_NAME = "selectedConfigName"

struct ApiSettingsView: View {
    @State private var selectedConfig: ApiConfiguration = loadConfigOrDefault()

    var body: some View {
        VStack(spacing: 10) {
            ApiInfoView(label: "Branch Key", value: selectedConfig.branchKey)
            ApiInfoView(label: "Api Url", value: selectedConfig.apiUrl)
            ApiInfoView(label: "App Id", value: selectedConfig.appId)

            VStack {
                HStack(spacing: 5) {
                    ApiButton(configName: STAGING, selectedConfig: $selectedConfig)
                    ApiButton(configName: PRODUCTION, selectedConfig: $selectedConfig)
                }.frame(maxWidth: .infinity)

                HStack(spacing: 5) {
                    ApiButton(configName: STAGING_AC, selectedConfig: $selectedConfig)
                    ApiButton(configName: PRODUCTION_AC, selectedConfig: $selectedConfig)
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(BorderlessButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

func loadConfigOrDefault() -> ApiConfiguration {
    loadConfig() ?? apiConfigurationsMap[STAGING] ?? ApiConfiguration(branchKey: "N/A", apiUrl: "N/A", appId: "N/A", staging: false)
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

struct ApiButton: View {
    var configName: String
    @State private var showReloadAlert = false
    @Binding var selectedConfig: ApiConfiguration
    
    var body: some View {
        Button(action: { switchToConfig(key: configName) }) {
            Text(configName)
                .frame(maxWidth: .infinity)
                .padding()
                .background(getButtonColor())
                .foregroundColor(.white)
                .cornerRadius(8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .truncationMode(.tail)
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
        .frame(maxWidth: .infinity)
    }
    
    private func switchToConfig(key: String) {
        guard let config = apiConfigurationsMap[key] else { return }
        if selectedConfig != config {
            selectedConfig = config
            saveConfig(configName: getConfigName(selectedConfig))
            showReloadAlert = true
        }
    }
    
    private func getButtonColor() -> Color {
        return selectedConfig == apiConfigurationsMap[configName] ? Color.blue : Color.gray
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

struct ApiSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        ApiSettingsView()
    }
}
