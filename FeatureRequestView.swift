import SwiftUI

// MARK: - Feature Request View

struct FeatureRequestView: View {
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var useCase: String = ""
    @State private var priority: Priority = .medium
    @State private var category: Category = .enhancement
    @State private var email: String = ""

    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var color: Color {
            switch self {
            case .low: return .yellow
            case .medium: return Color(red: 1.0, green: 0.6, blue: 0.2) // Light orange
            case .high: return .red
            }
        }
    }

    enum Category: String, CaseIterable {
        case enhancement = "Enhancement"
        case newFeature = "New Feature"
        case integration = "Integration"
        case uiUx = "UI/UX"
        case performance = "Performance"
        case other = "Other"
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                TextField("", text: $title, prompt: Text("Feature Title"))
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $description)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color(red: 24/255, green: 24/255, blue: 26/255))
                    .cornerRadius(8)
            }

            Section {
                HStack {
                    Picker("", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    Text("Category")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    ForEach(Priority.allCases, id: \.self) { pri in
                        Button(action: {
                            priority = pri
                        }) {
                            Text(pri.rawValue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(priority == pri ? pri.color : Color.clear)
                                .foregroundColor(priority == pri ? .white : pri.color)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Context") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use Case / Why You Need This")
                        .font(.subheadline)
                    TextEditor(text: $useCase)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(red: 24/255, green: 24/255, blue: 26/255))
                        .cornerRadius(8)
                }
                Text("Help us understand how this feature would benefit you.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Contact") {
                TextField("", text: $email, prompt: Text("Email"))
                    .textFieldStyle(.roundedBorder)
                Text("Provide your email if you'd like updates on this request.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 24/255, green: 24/255, blue: 26/255))

            HStack {
                Spacer()
                Button(action: sendFeatureRequest) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isSending ? "Sending..." : "Submit Feature Request")
                }
                .disabled(isSending || title.isEmpty || description.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 20)
        .background(Color(red: 24/255, green: 24/255, blue: 26/255))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Request Submitted!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your suggestion! We'll review it and consider it for future updates.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
    }

    private func sendFeatureRequest() {
        guard !title.isEmpty, !description.isEmpty else { return }

        isSending = true

        Task {
            do {
                let request = FeatureRequest(
                    title: title,
                    description: description,
                    useCase: useCase.isEmpty ? nil : useCase,
                    priority: priority.rawValue,
                    category: category.rawValue,
                    email: email.isEmpty ? nil : email,
                    timestamp: Date()
                )

                try await UserFeedbackClient.shared.sendFeatureRequest(request)

                await MainActor.run {
                    isSending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Failed to send request: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Feature Request Model

struct FeatureRequest: Codable {
    let title: String
    let description: String
    let useCase: String?
    let priority: String
    let category: String
    let email: String?
    let timestamp: Date
}
