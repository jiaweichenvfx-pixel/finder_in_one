import Foundation
import UniformTypeIdentifiers

enum DropURLParsing {
    static let acceptedFileURLTypeIdentifiers = [
        UTType.fileURL.identifier,
        UTType.url.identifier
    ]

    static func fileURL(from item: NSSecureCoding?) -> URL? {
        let url: URL?
        if let value = item as? URL {
            url = value
        } else if let value = item as? NSURL {
            url = value as URL
        } else if let value = item as? String {
            url = URL(string: value)
        } else if let value = item as? NSString {
            url = URL(string: value as String)
        } else if let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) {
            url = URL(string: string)
        } else {
            url = nil
        }

        guard let url, url.isFileURL else {
            return nil
        }
        return url
    }

    static func loadFileURL(from provider: NSItemProvider, completion: @escaping @Sendable (URL?) -> Void) {
        guard let typeIdentifier = acceptedFileURLTypeIdentifiers.first(where: { typeIdentifier in
            provider.hasItemConformingToTypeIdentifier(typeIdentifier)
        }) else {
            completion(nil)
            return
        }

        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            completion(fileURL(from: item))
        }
    }
}
