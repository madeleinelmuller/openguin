import Foundation
import JavaScriptCore

actor SandboxService {
    static let shared = SandboxService()
    private init() {}

    private let workspaceRoot: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("AgentMemory/workspace/scripts")
    }()

    func execute(language: String, code: String, filename: String?) async -> String {
        switch language.lowercased() {
        case "javascript", "js":
            return executeJS(code: code)
        case "python", "py":
            return saveScript(code: code, extension: "py", filename: filename, language: "Python")
        case "shell", "bash", "sh":
            return saveScript(code: code, extension: "sh", filename: filename, language: "Shell")
        default:
            return saveScript(code: code, extension: language.lowercased(), filename: filename, language: language)
        }
    }

    private func executeJS(code: String) -> String {
        guard let context = JSContext() else {
            return "Error: Could not create JavaScript context."
        }

        var output: [String] = []

        // Capture console.log
        let log: @convention(block) (JSValue) -> Void = { value in
            output.append(value.toString() ?? "undefined")
        }
        context.setObject(log, forKeyedSubscript: "print" as NSString)
        let consoleObj = JSValue(object: ["log": log], in: context)
        context.setObject(consoleObj, forKeyedSubscript: "console" as NSString)

        var errorMsg: String? = nil
        context.exceptionHandler = { _, exception in
            errorMsg = exception?.toString()
        }

        let result = context.evaluateScript(code)

        if let err = errorMsg {
            return "JavaScript error: \(err)"
        }

        var response = ""
        if !output.isEmpty {
            response += "Output:\n" + output.joined(separator: "\n") + "\n"
        }
        if let resultStr = result?.toString(), resultStr != "undefined", resultStr != "null" {
            response += "Result: \(resultStr)"
        }
        return response.isEmpty ? "Code executed successfully (no output)." : response
    }

    private func saveScript(code: String, extension ext: String, filename: String?, language: String) -> String {
        let name = (filename ?? "script_\(Int(Date().timeIntervalSince1970))") + ".\(ext)"
        let url = workspaceRoot.appendingPathComponent(name)

        try? FileManager.default.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)

        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
            return "\(language) execution is not available on-device. Script saved to workspace/scripts/\(name). You can run it on your Mac or in a terminal."
        } catch {
            return "Error saving script: \(error.localizedDescription)"
        }
    }
}
