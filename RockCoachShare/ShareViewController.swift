//
//  ShareViewController.swift
//  RockCoachShare
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.055, green: 0.063, blue: 0.078, alpha: 1)
        Task { await consume() }
    }

    private func consume() async {
        defer { extensionContext?.completeRequest(returningItems: nil) }

        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        for provider in providers {
            if let data = await loadData(from: provider), !data.isEmpty {
                let name = suggestedName(for: provider)
                try? CoachInbox.saveData(data, suggestedName: name)
                openHost()
                return
            }
        }
    }

    private func suggestedName(for provider: NSItemProvider) -> String {
        if let name = provider.suggestedName, !name.isEmpty {
            if (name as NSString).pathExtension.isEmpty {
                return "\(name).\(CoachFormat.pathExtension)"
            }
            return name
        }
        return "\(UUID().uuidString).\(CoachFormat.pathExtension)"
    }

    private func loadData(from provider: NSItemProvider) async -> Data? {
        let dataTypes = [
            CoachFormat.utTypeIdentifier,
            UTType.json.identifier,
            UTType.data.identifier,
        ]
        for type in dataTypes where provider.hasItemConformingToTypeIdentifier(type) {
            if let data = await loadDataRepresentation(provider, type: type), !data.isEmpty {
                return data
            }
        }

        let urlTypes = [UTType.fileURL.identifier, UTType.url.identifier]
        for type in urlTypes where provider.hasItemConformingToTypeIdentifier(type) {
            if let url = await loadFileURL(provider, type: type),
               let data = try? CoachInbox.readData(from: url),
               !data.isEmpty {
                return data
            }
        }
        return nil
    }

    private func loadDataRepresentation(_ provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                cont.resume(returning: data)
            }
        }
    }

    private func loadFileURL(_ provider: NSItemProvider, type: String) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    cont.resume(returning: url)
                    return
                }
                if let data = item as? Data,
                   let text = String(data: data, encoding: .utf8),
                   let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    cont.resume(returning: url)
                    return
                }
                cont.resume(returning: nil)
            }
        }
    }

    private func openHost() {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(CoachInbox.hostURL)
                return
            }
            responder = current.next
        }
    }
}
