import Foundation

actor WebSearchService {
    static let shared = WebSearchService()
    private init() {}

    func search(query: String) async -> String {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1")
        else {
            return "Error: Could not form search URL."
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Error: Could not parse search results."
            }

            var result = "Search results for: \"\(query)\"\n\n"

            if let abstract = json["Abstract"] as? String, !abstract.isEmpty {
                result += "**Summary:** \(abstract)\n"
                if let abstractURL = json["AbstractURL"] as? String, !abstractURL.isEmpty {
                    result += "Source: \(abstractURL)\n"
                }
                result += "\n"
            }

            if let relatedTopics = json["RelatedTopics"] as? [[String: Any]] {
                let topics = relatedTopics.prefix(5).compactMap { topic -> String? in
                    guard let text = topic["Text"] as? String, !text.isEmpty else { return nil }
                    let firstURL = topic["FirstURL"] as? String ?? ""
                    return "- \(text)\n  \(firstURL)"
                }
                if !topics.isEmpty {
                    result += "**Related:**\n" + topics.joined(separator: "\n") + "\n"
                }
            }

            if let infoBox = json["Infobox"] as? [String: Any],
               let content = infoBox["content"] as? [[String: Any]] {
                let facts = content.prefix(5).compactMap { item -> String? in
                    guard let label = item["label"] as? String,
                          let value = item["value"] as? String else { return nil }
                    return "- **\(label):** \(value)"
                }
                if !facts.isEmpty {
                    result += "\n**Facts:**\n" + facts.joined(separator: "\n") + "\n"
                }
            }

            if result == "Search results for: \"\(query)\"\n\n" {
                result += "No direct results found. Try fetch_url with a specific page URL for more detail."
            }

            return result
        } catch {
            return "Search error: \(error.localizedDescription)"
        }
    }

    func fetchURL(_ urlStr: String) async -> String {
        guard let url = URL(string: urlStr) else {
            return "Error: Invalid URL."
        }

        do {
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (compatible; Openguin/1.0)", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return "Error: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) from \(urlStr)"
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return "Error: Could not decode page content."
            }

            let stripped = stripHTML(html)
            let truncated = String(stripped.prefix(3000))
            return "Content from \(urlStr):\n\n\(truncated)"
        } catch {
            return "Error fetching URL: \(error.localizedDescription)"
        }
    }

    private func stripHTML(_ html: String) -> String {
        var result = html
        // Remove script and style blocks
        result = result.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        // Remove HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
