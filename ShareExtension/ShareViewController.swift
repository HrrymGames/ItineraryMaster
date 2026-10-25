import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ItineraryCore

/// "Save to Itinerary" in the iOS share sheet. Puts the link in the shared
/// queue; the app picks it up and sorts it next time it opens.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        model.onFinish = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: ShareCard(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        extractLink()
    }

    private func extractLink() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        var texts: [String] = items.compactMap { $0.attributedContentText?.string }

        let group = DispatchGroup()
        var foundURL: URL?
        let lock = NSLock()

        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    lock.lock()
                    if foundURL == nil, let url = item as? URL, url.scheme?.hasPrefix("http") == true { foundURL = url }
                    lock.unlock()
                    group.leave()
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    lock.lock()
                    if let s = item as? String { texts.append(s) }
                    lock.unlock()
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let joined = texts.joined(separator: "\n")
            let url = foundURL ?? TikTokLink.firstURL(in: joined) ?? TikTokLink.anyURL(in: joined)
            self.model.link = url?.absoluteString
            self.model.sharedText = joined
            self.model.state = url == nil ? .noLink : .ready
        }
    }
}

final class ShareModel: ObservableObject {
    enum State { case loading, ready, saved, copied, noLink }

    @Published var state: State = .loading
    @Published var link: String?
    @Published var sharedText = ""
    @Published var note = ""
    @Published var folder: VideoFolder?
    var onFinish: () -> Void = {}

    func save() {
        guard let link else { return }
        let ok = ImportQueue.append(PendingImport(url: link, note: note.isEmpty ? nil : note, date: Date(), folder: folder?.rawValue))
        if ok {
            state = .saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.onFinish() }
        } else {
            // App group not available (signing quirk) - hand over via the clipboard instead.
            UIPasteboard.general.string = link
            state = .copied
        }
    }
}

struct ShareCard: View {
    @ObservedObject var model: ShareModel
    private var accent: Color { Color(red: 0.937, green: 0.329, blue: 0.420) }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "map.fill").foregroundStyle(accent)
                    Text("Save to Itinerary").font(.headline)
                    Spacer()
                    Button { model.onFinish() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }
                switch model.state {
                case .loading:
                    ProgressView().padding()
                case .noLink:
                    Text("No link found in what you shared.").foregroundStyle(.secondary)
                case .ready:
                    Text(model.link ?? "")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder (optional - otherwise sorted automatically)").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(VideoFolder.allCases) { f in
                                    Button {
                                        model.folder = model.folder == f ? nil : f
                                    } label: {
                                        Label(f.label, systemImage: f.symbol)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(model.folder == f ? accent : Color(uiColor: .tertiarySystemFill), in: Capsule())
                                            .foregroundStyle(model.folder == f ? Color.white : Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    TextField("Add a note (optional)", text: $model.note, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    Button { model.save() } label: {
                        Text("Save").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(accent, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                    }
                case .saved:
                    Label("Saved! It'll be sorted next time you open the app.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).multilineTextAlignment(.center)
                case .copied:
                    VStack(spacing: 8) {
                        Label("Link copied", systemImage: "doc.on.clipboard.fill").font(.headline)
                        Text("Open Itinerary → Saved and tap Paste to finish saving.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Done") { model.onFinish() }.buttonStyle(.borderedProminent).tint(accent)
                    }
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding()
        }
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }
}
