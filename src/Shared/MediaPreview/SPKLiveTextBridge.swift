import UIKit
import VisionKit

@objc(SPKLiveTextBridge)
@available(iOS 16.0, *)
@MainActor
final class SPKLiveTextBridge: NSObject, @preconcurrency ImageAnalysisInteractionDelegate {
    private weak var imageView: UIImageView?
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()
    private var generation = 0
    private var lastReportedHighlight = false
    private var lastReportedAvailability = false

    /// Reports whether Live Text is currently highlighting the recognized text.
    /// While it is, VisionKit draws its own "Copy All" quick action over the
    /// bottom of the image, where the host may be drawing chrome of its own.
    @objc var onHighlightChange: ((Bool) -> Void)?

    /// Reports whether the analyzed image contains text worth a button. Driven by the
    /// analysis result, since `liveTextButtonVisible` tracks VisionKit's suppressed button.
    @objc var onTextAvailabilityChange: ((Bool) -> Void)?

    /// Whether Live Text is highlighting the recognized text right now. Settable so
    /// the host's own button can drive VisionKit's built-in one out of the picture.
    @objc var highlighted: Bool {
        get { interaction.selectableItemsHighlighted }
        set {
            interaction.selectableItemsHighlighted = newValue
            setHighlighted(newValue)
        }
    }

    /// The full recognized text, or nil when nothing was found.
    @objc var transcript: String? {
        guard let analysis = interaction.analysis else { return nil }
        let text = analysis.transcript
        return text.isEmpty ? nil : text
    }

    @objc static var supported: Bool {
        if #available(iOS 16.0, *) { return ImageAnalyzer.isSupported }
        return false
    }

    @objc init(imageView: UIImageView) {
        self.imageView = imageView
        super.init()
        interaction.preferredInteractionTypes = [.textSelection, .dataDetectors]
        interaction.delegate = self
        // The host draws its own OCR button in the same corner, styled like the rest
        // of its chrome, so VisionKit's floating one would just be a duplicate.
        interaction.setSupplementaryInterfaceHidden(true, animated: false)
        imageView.isUserInteractionEnabled = true
        imageView.addInteraction(interaction)
    }

    @objc func analyzeImage(_ image: UIImage) {
        guard Self.supported else { return }
        generation += 1
        let expectedGeneration = generation
        setHighlighted(false)
        setTextAvailable(false)
        interaction.analysis = nil
        Task { @MainActor in
            do {
                let configuration = ImageAnalyzer.Configuration([.text])
                let analysis = try await analyzer.analyze(image, configuration: configuration)
                guard expectedGeneration == generation else { return }
                interaction.analysis = analysis
                setTextAvailable(analysis.hasResults(for: [.text]))
            } catch {
                guard expectedGeneration == generation else { return }
                interaction.analysis = nil
            }
        }
    }

    @objc func cleanup() {
        generation += 1
        setHighlighted(false)
        setTextAvailable(false)
        interaction.analysis = nil
        imageView?.removeInteraction(interaction)
        imageView = nil
        onHighlightChange = nil
        onTextAvailabilityChange = nil
    }

    func interaction(_ interaction: ImageAnalysisInteraction,
                     highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
        setHighlighted(highlightSelectedItems)
    }

    private func setHighlighted(_ highlighted: Bool) {
        guard highlighted != lastReportedHighlight else { return }
        lastReportedHighlight = highlighted
        onHighlightChange?(highlighted)
    }

    private func setTextAvailable(_ available: Bool) {
        guard available != lastReportedAvailability else { return }
        lastReportedAvailability = available
        onTextAvailabilityChange?(available)
    }
}
