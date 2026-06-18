import Foundation

public struct WorkspaceTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var workspace: Workspace
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        workspace: Workspace,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workspace = workspace
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceTemplateSlot: Codable, Equatable, Identifiable, Sendable {
    public var index: Int
    public var template: WorkspaceTemplate?

    public init(index: Int, template: WorkspaceTemplate? = nil) {
        self.index = index
        self.template = template
    }

    public var id: Int { index }

    public var displayName: String {
        template?.name ?? "T\(index + 1)"
    }
}

public struct WorkspaceTemplateLibrary: Codable, Equatable, Sendable {
    public static let defaultSlotCount = 5

    public private(set) var slots: [WorkspaceTemplateSlot]

    public init(slots: [WorkspaceTemplateSlot]? = nil) {
        self.slots = Self.normalized(slots ?? Self.emptySlots())
    }

    @discardableResult
    public mutating func saveTemplate(_ workspace: Workspace, at index: Int, name: String) -> Bool {
        guard let slotIndex = slots.firstIndex(where: { $0.index == index }) else {
            return false
        }
        let trimmedName = Self.normalizedName(name, fallback: "T\(index + 1)")
        let id = slots[slotIndex].template?.id ?? UUID()
        slots[slotIndex].template = WorkspaceTemplate(id: id, name: trimmedName, workspace: workspace)
        return true
    }

    @discardableResult
    public mutating func overwriteTemplate(_ workspace: Workspace, at index: Int) -> Bool {
        guard let slotIndex = slots.firstIndex(where: { $0.index == index }),
              let template = slots[slotIndex].template else {
            return false
        }
        slots[slotIndex].template = WorkspaceTemplate(
            id: template.id,
            name: template.name,
            workspace: workspace
        )
        return true
    }

    @discardableResult
    public mutating func renameTemplate(at index: Int, name: String) -> Bool {
        guard let slotIndex = slots.firstIndex(where: { $0.index == index }),
              var template = slots[slotIndex].template else {
            return false
        }
        template.name = Self.normalizedName(name, fallback: template.name)
        template.updatedAt = Date()
        slots[slotIndex].template = template
        return true
    }

    @discardableResult
    public mutating func deleteTemplate(at index: Int) -> Bool {
        guard let slotIndex = slots.firstIndex(where: { $0.index == index }),
              slots[slotIndex].template != nil else {
            return false
        }
        slots[slotIndex].template = nil
        return true
    }

    public func template(at index: Int) -> WorkspaceTemplate? {
        slots.first(where: { $0.index == index })?.template
    }

    private static func emptySlots() -> [WorkspaceTemplateSlot] {
        (0..<defaultSlotCount).map { WorkspaceTemplateSlot(index: $0) }
    }

    private static func normalized(_ slots: [WorkspaceTemplateSlot]) -> [WorkspaceTemplateSlot] {
        (0..<defaultSlotCount).map { index in
            slots.first(where: { $0.index == index }) ?? WorkspaceTemplateSlot(index: index)
        }
    }

    private static func normalizedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
