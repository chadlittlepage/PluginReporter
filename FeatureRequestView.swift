import SwiftUI

// MARK: - Feature Request View

struct FeatureRequestView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

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

    // Match Settings card background colors
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
    }

    private var appBackground: Color {
        colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private var textEditorBackground: Color {
        Color.black
    }

    // Gradient background matching Settings window
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.15, green: 0.15, blue: 0.17),
                Color(red: 0.10, green: 0.10, blue: 0.12)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var body: some View {
        #if os(macOS)
        macOSView
        #else
        iOSView
        #endif
    }

    // macOS-specific view with gradient
    @ViewBuilder
    private var macOSView: some View {
        ZStack {
            gradientBackground

            ScrollView(.vertical, showsIndicators: true) {
                contentView
            }
        }
        .frame(minWidth: 700, minHeight: 800)
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

    #if os(iOS)
    // iOS-specific view with navigation
    @ViewBuilder
    private var iOSView: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                contentView
            }
            .background(appBackground)
            .navigationTitle("Request a Feature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
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
    #endif

    // Shared content view
    @ViewBuilder
    private var contentView: some View {
                VStack(alignment: .leading, spacing: 20) {

                // MARK: - Feature Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Feature Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("", text: $title, prompt: Text("Feature Title"))
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $description)
                                .scrollContentBackground(.hidden)
                                .background(textEditorBackground)
                                .frame(height: 150)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Category & Priority
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category & Priority")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Category")
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $category) {
                                ForEach(Category.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Divider()
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Priority")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Context")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use Case / Why You Need This")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextEditor(text: $useCase)
                                .scrollContentBackground(.hidden)
                                .background(textEditorBackground)
                                .frame(height: 120)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Text("Help us understand how this feature would benefit you.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Contact
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        TextField("", text: $email, prompt: Text("Email"))
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Text("Provide your email if you'd like updates on this request.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .background(cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - Submit Button
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
                    Spacer()
                }
                .padding(.vertical, 16)

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
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
