import UIKit
import VisionKit

@objc(SPKLiveTextBridge)
@available(iOS 16.0, *)
@MainActor
final class SPKLiveTextBridge: NSObject {
    private weak var imageView: UIImageView?
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()
    private var generation = 0

    @objc static var supported: Bool {
        if #available(iOS 16.0, *) { return ImageAnalyzer.isSupported }
        return false
    }

    @objc init(imageView: UIImageView) {
        self.imageView = imageView
        super.init()
        interaction.preferredInteractionTypes = [.textSelection, .dataDetectors]
        imageView.isUserInteractionEnabled = true
        imageView.addInteraction(interaction)
    }

    @objc func analyzeImage(_ image: UIImage) {
        guard Self.supported else { return }
        generation += 1
        let expectedGeneration = generation
        interaction.analysis = nil
        Task { @MainActor in
            do {
                let configuration = ImageAnalyzer.Configuration([.text])
                let analysis = try await analyzer.analyze(image, configuration: configuration)
                guard expectedGeneration == generation else { return }
                interaction.analysis = analysis
            } catch {
                guard expectedGeneration == generation else { return }
                interaction.analysis = nil
            }
        }
    }

    @objc func cleanup() {
        generation += 1
        interaction.analysis = nil
        imageView?.removeInteraction(interaction)
        imageView = nil
    }
}
