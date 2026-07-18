import Foundation

public struct ProgressHTTPTransport: @unchecked Sendable {
    public var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }

    public static let live = ProgressHTTPTransport { request in
        try await URLSession.shared.data(for: request)
    }
}

public enum ProgressAPIError: Error, Equatable, Sendable {
    case invalidBaseURL
    case nonHTTPResponse
    case rejected(statusCode: Int, message: String?)
    case invalidResponse
}

public struct ProgressAPIClient: Sendable {
    private let endpoint: URL
    private let transport: ProgressHTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL, transport: ProgressHTTPTransport = .live) throws {
        guard baseURL.scheme?.lowercased() == "https",
              baseURL.host != nil,
              let endpoint = URL(string: "progress", relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL else {
            throw ProgressAPIError.invalidBaseURL
        }
        self.endpoint = endpoint
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func fetchCourseProgress(_ query: ProgressQueryDTO) async throws -> CourseProgressSnapshotDTO {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = query.queryItems
        guard let url = components?.url else { throw ProgressAPIError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request, response: CourseProgressSnapshotDTO.self)
    }

    public func fetchProgressOverview(userID: String, mode: ProgressStudyModeDTO) async throws -> WordProgressSnapshotDTO {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = ProgressQueryDTO(userID: userID, mode: mode).queryItems
        guard let url = components?.url else { throw ProgressAPIError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request, response: WordProgressSnapshotDTO.self)
    }

    public func selectCourse(_ requestDTO: SelectCourseRequestDTO) async throws -> SelectCourseResponseDTO {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestDTO)
        return try await perform(request, response: SelectCourseResponseDTO.self)
    }

    public func sendCourseProgress(_ requestDTO: CourseProgressRequestDTO) async throws -> CourseProgressResponseDTO {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestDTO)
        return try await perform(request, response: CourseProgressResponseDTO.self)
    }

    private func perform<Response: Decodable & Sendable>(
        _ request: URLRequest,
        response: Response.Type
    ) async throws -> Response {
        let (data, rawResponse) = try await transport.data(request)
        guard let http = rawResponse as? HTTPURLResponse else {
            throw ProgressAPIError.nonHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = try? decoder.decode(ProgressErrorDTO.self, from: data).error
            throw ProgressAPIError.rejected(statusCode: http.statusCode, message: message)
        }
        do {
            return try decoder.decode(response, from: data)
        } catch {
            throw ProgressAPIError.invalidResponse
        }
    }
}
