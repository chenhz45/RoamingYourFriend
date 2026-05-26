import Foundation

/// Runs the face_crop binary (or python3 + script) as a subprocess and returns the result.
struct PythonBridge {

    enum Mode {
        case binary(String)     // standalone PyInstaller binary
        case script(String)     // python3 + .py script
    }

    private let mode: Mode

    init(binaryPath: String) {
        self.mode = .binary(binaryPath)
    }

    init(scriptPath: String) {
        self.mode = .script(scriptPath)
    }

    // MARK: - Result

    enum Result {
        case success(outputPath: String)
        case noFace(outputPath: String)
        case failure(message: String)
    }

    // MARK: - Process

    func process(inputPath: String,
                 outputPath: String,
                 size: Int = 100,
                 pixelBlock: Int = 6,
                 completion: @escaping @MainActor (Result) -> Void) {
        let mode = self.mode

        DispatchQueue.global().async {
            let process = Process()

            switch mode {
            case .binary(let path):
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = [
                    "--input", inputPath,
                    "--output", outputPath,
                    "--size", "\(size)",
                    "--pixel-block", "\(pixelBlock)",
                ]
            case .script(let path):
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [
                    "python3", path,
                    "--input", inputPath,
                    "--output", outputPath,
                    "--size", "\(size)",
                    "--pixel-block", "\(pixelBlock)",
                ]
            }

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()

                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    let msg = stderr.isEmpty ? "exit code \(process.terminationStatus)" : stderr
                    Task { @MainActor in completion(.failure(message: msg)) }
                    return
                }

                let result: Result
                switch stdout {
                case "success":
                    result = .success(outputPath: outputPath)
                case "no_face":
                    result = .noFace(outputPath: outputPath)
                default:
                    result = .success(outputPath: outputPath)
                }

                Task { @MainActor in completion(result) }
            } catch {
                Task { @MainActor in completion(.failure(message: error.localizedDescription)) }
            }
        }
    }
}
