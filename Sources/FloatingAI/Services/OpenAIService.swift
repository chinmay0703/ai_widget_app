import Foundation

/// Talks to the OpenAI Responses API (`POST /v1/responses`).
///
/// Supports key validation, a one-shot request, and token streaming over SSE.
final class OpenAIService {
    private let apiKey: String
    private let session: URLSession

    private static let baseURL = URL(string: "https://api.openai.com/v1")!

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Key validation

    /// Lightweight check that the key is accepted by the API.
    func validateKey() async -> Result<Void, AppError> {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.network("No HTTP response"))
            }
            switch http.statusCode {
            case 200:
                return .success(())
            case 401:
                return .failure(.invalidAPIKey)
            default:
                return .failure(.httpStatus(http.statusCode, Self.errorMessage(from: data)))
            }
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    // MARK: - One-shot request

    func respond(messages: [ChatMessage],
                 instructions: String,
                 model: String,
                 temperature: Double) async throws -> String {
        let request = try makeRequest(messages: messages,
                                      instructions: instructions,
                                      model: model,
                                      temperature: temperature,
                                      stream: false)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network("No HTTP response")
        }
        guard http.statusCode == 200 else {
            throw Self.httpError(status: http.statusCode, data: data)
        }
        let decoded = try JSONDecoder().decode(ResponsesResult.self, from: data)
        if let apiError = decoded.error {
            throw AppError.httpStatus(http.statusCode, apiError.message)
        }
        let text = decoded.outputText
        guard !text.isEmpty else { throw AppError.emptyResponse }
        return text
    }

    // MARK: - Streaming request

    /// Streams the assistant's reply as incremental text chunks.
    func streamResponse(messages: [ChatMessage],
                        instructions: String,
                        model: String,
                        temperature: Double) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(messages: messages,
                                                  instructions: instructions,
                                                  model: model,
                                                  temperature: temperature,
                                                  stream: true)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AppError.network("No HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        // Drain the (small) error body so we can surface a message.
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        throw Self.httpError(status: http.statusCode, data: body)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst("data:".count)
                            .trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else {
                            continue
                        }
                        switch event.type {
                        case "response.output_text.delta":
                            if let delta = event.delta, !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        case "response.error", "error":
                            throw AppError.httpStatus(http.statusCode, event.error?.message ?? "Streaming error")
                        case "response.failed":
                            throw AppError.httpStatus(http.statusCode,
                                                      event.response?.error?.message ?? "The response failed.")
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AppError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Request building

    private func makeRequest(messages: [ChatMessage],
                             instructions: String,
                             model: String,
                             temperature: Double,
                             stream: Bool) throws -> URLRequest {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("responses"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let input = messages
            .filter { $0.role != .system }
            .map { RequestMessage(role: $0.role.rawValue, content: $0.text) }

        let body = ResponsesRequest(
            model: model,
            instructions: instructions.isEmpty ? nil : instructions,
            input: input,
            // Reasoning (o-series) models reject a custom temperature.
            temperature: Self.supportsTemperature(model) ? temperature : nil,
            stream: stream
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private static func supportsTemperature(_ model: String) -> Bool {
        !model.lowercased().hasPrefix("o")
    }

    private static func httpError(status: Int, data: Data) -> AppError {
        if status == 401 { return .invalidAPIKey }
        return .httpStatus(status, errorMessage(from: data))
    }

    private static func errorMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(ResponsesResult.self, from: data),
           let message = decoded.error?.message {
            return message
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        return "Unknown error"
    }
}

// MARK: - Wire models

private struct RequestMessage: Encodable {
    let role: String
    let content: String
}

private struct ResponsesRequest: Encodable {
    let model: String
    let instructions: String?
    let input: [RequestMessage]
    let temperature: Double?
    let stream: Bool
}

/// Decodes a non-streaming `/v1/responses` result.
private struct ResponsesResult: Decodable {
    struct OutputItem: Decodable {
        let type: String
        let content: [ContentItem]?
    }
    struct ContentItem: Decodable {
        let type: String
        let text: String?
    }
    struct APIError: Decodable {
        let message: String
    }

    let output: [OutputItem]?
    let error: APIError?

    /// Reconstruct the assistant text from message → output_text content parts.
    var outputText: String {
        guard let output else { return "" }
        var parts: [String] = []
        for item in output where item.type == "message" {
            guard let content = item.content else { continue }
            for part in content where part.type == "output_text" {
                if let text = part.text { parts.append(text) }
            }
        }
        return parts.joined()
    }
}

/// Decodes a single SSE event from a streaming `/v1/responses` result.
private struct StreamEvent: Decodable {
    struct NestedResponse: Decodable {
        let error: ResponsesResult.APIError?
    }
    let type: String
    let delta: String?
    let error: ResponsesResult.APIError?
    let response: NestedResponse?
}
