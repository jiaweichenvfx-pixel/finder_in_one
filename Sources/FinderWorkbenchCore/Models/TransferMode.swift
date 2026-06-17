import Foundation

public enum TransferMode: String, Codable, Equatable, Sendable {
    case copy
    case moveOnce
}

public enum FileTransferOperation: String, Codable, Equatable, Sendable {
    case copy
    case move
}

public final class TransferModeController {
    public private(set) var mode: TransferMode

    public init(mode: TransferMode = .copy) {
        self.mode = mode
    }

    public var currentOperation: FileTransferOperation {
        switch mode {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }

    public func enableCopy() {
        mode = .copy
    }

    public func enableMoveOnce() {
        mode = .moveOnce
    }

    public func operationDidFinish() {
        mode = .copy
    }

    public func operationDidFail() {
        mode = .copy
    }
}
