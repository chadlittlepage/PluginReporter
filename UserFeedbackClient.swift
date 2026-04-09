import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - User Feedback Firestore Client

/// Handles sending bug reports and feature requests directly to Firebase Firestore
class UserFeedbackClient {

    static let shared = UserFeedbackClient()

    private init() {}

    // MARK: - Send Bug Report

    func sendBugReport(_ report: BugReport) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        // Convert report to dictionary
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)

        guard let reportDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FeedbackError.invalidData
        }

        // Add to Firestore
        try await db.collection("bug_reports").addDocument(data: reportDict)

        // Log successful submission
        dashboardLogError(
            message: "Bug report submitted to Firebase: \(report.title)", severity: "info", context: "User Feedback"
        )

        // print("✅ Bug report submitted to Firebase Firestore: \(report.title)")
        #else
        throw FeedbackError.firebaseNotAvailable
        #endif
    }

    // MARK: - Send Feature Request

    func sendFeatureRequest(_ request: FeatureRequest) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        // Convert request to dictionary
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)

        guard let requestDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FeedbackError.invalidData
        }

        // Add to Firestore
        try await db.collection("feature_requests").addDocument(data: requestDict)

        // Log successful submission
        dashboardLogError(
            message: "Feature request submitted to Firebase: \(request.title)", severity: "info", context: "User Feedback"
        )

        // print("✅ Feature request submitted to Firebase Firestore: \(request.title)")
        #else
        throw FeedbackError.firebaseNotAvailable
        #endif
    }
}

// MARK: - Feedback Error

enum FeedbackError: LocalizedError {
    case invalidData
    case firebaseNotAvailable
    case submissionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidData: 
            return "Failed to convert feedback data for submission."
        case .firebaseNotAvailable:
            return "Firebase is not available. Please ensure Firebase is properly configured."
        case .submissionFailed(let message):
            return "Failed to submit feedback: \(message)"
        }
    }
}
