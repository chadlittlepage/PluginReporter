import Foundation

// MARK: - User Feedback HTTP Client

/// Handles sending bug reports and feature requests to the server
class UserFeedbackClient {

    static let shared = UserFeedbackClient()

    private init() {}

    // MARK: - Send Bug Report

    func sendBugReport(_ report: BugReport) async throws {
        let serverURL = UserDefaults.standard.string(forKey: "dashboard_server_url") ?? ""
        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/bug-report") else {
            throw FeedbackError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        if let apiKey = KeychainHelper.load(key: "dashboard_api_key") {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(report)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw FeedbackError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            } else {
                throw FeedbackError.serverError(statusCode: httpResponse.statusCode, message: "Unknown error")
            }
        }

        // Log successful submission
        dashboardLogError(
            message: "Bug report submitted: \(report.title)",
            severity: "info",
            context: "User Feedback"
        )
    }

    // MARK: - Send Feature Request

    func sendFeatureRequest(_ request: FeatureRequest) async throws {
        let serverURL = UserDefaults.standard.string(forKey: "dashboard_server_url") ?? ""
        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/feature-request") else {
            throw FeedbackError.invalidServerURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        if let apiKey = KeychainHelper.load(key: "dashboard_api_key") {
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw FeedbackError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            } else {
                throw FeedbackError.serverError(statusCode: httpResponse.statusCode, message: "Unknown error")
            }
        }

        // Log successful submission
        dashboardLogError(
            message: "Feature request submitted: \(request.title)",
            severity: "info",
            context: "User Feedback"
        )
    }
}

// MARK: - Feedback Error

enum FeedbackError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid server URL. Please configure your server in Dashboard Settings."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}
