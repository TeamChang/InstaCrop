//
//  SplitVC.swift
//  InstaCrop
//
//  Splits one photo into a profile grid (3×N tiles) or a seamless carousel (swipe panorama).
//

import UIKit
import Photos
import SVProgressHUD

class SplitVC: UIViewController {

    enum Mode: Int {
        case grid
        case carousel
    }

    var sourceImage: UIImage?

    private let extensions = Extensions()

    private var mode: Mode = .grid
    private var slideCount = 3
    private var slideRatio: SplitRenderer.Ratio = .square
    private var gridRows = 3
    private var isNoCrop = false

    // Downscaled copy + its blur, cached so option changes re-render instantly
    private var previewSource: UIImage?
    private var previewBlur: UIImage?
    private var fullBlur: UIImage?

    // Current layout's preview canvas and full resolution tiles (row-major, top-left first)
    private var previewCanvas: UIImage?
    private var fullTiles: [UIImage]?

    /// Row-major indexes of grid tiles already sent to Instagram
    private var postedTiles = Set<Int>()

    private let modeControl = UISegmentedControl(items: [NSLocalizedString("splitGrid", comment: "Grid"),
                                                         NSLocalizedString("splitCarousel", comment: "Carousel")])
    private let fitControl = UISegmentedControl(items: [NSLocalizedString("splitFill", comment: "Fill"),
                                                        NSLocalizedString("splitNoCrop", comment: "No Crop")])
    private let ratioControl = UISegmentedControl(items: SplitRenderer.Ratio.allCases.map { $0.title })
    private let rowsControl = UISegmentedControl(items: (1...6).map { "3×\($0)" })
    private let slidesLabel = UILabel()
    private let slidesStepper = UIStepper()
    private let previewImageView = UIImageView()
    private let hintLabel = UILabel()
    private let openInstagramBtn = UIButton(type: .system)

    private var carouselOptions = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("splitTitle", comment: "Split")
        view.backgroundColor = .systemBackground

        prepareSources()
        setupViews()
        updateOptionsVisibility()
        rebuildPreview()
    }

    // MARK: - Setup

    private func prepareSources() {

        guard let image = sourceImage else { return }

        previewSource = SplitRenderer.downscaled(image, maxSide: 1200)
        if let small = previewSource {
            previewBlur = extensions.applyBlur(to: small, intensity: 3.0)
        }
    }

    private func setupViews() {

        modeControl.selectedSegmentIndex = mode.rawValue
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        fitControl.selectedSegmentIndex = isNoCrop ? 1 : 0
        fitControl.addTarget(self, action: #selector(fitChanged), for: .valueChanged)

        ratioControl.selectedSegmentIndex = SplitRenderer.Ratio.allCases.firstIndex(of: slideRatio) ?? 0
        ratioControl.addTarget(self, action: #selector(ratioChanged), for: .valueChanged)

        rowsControl.selectedSegmentIndex = gridRows - 1
        rowsControl.addTarget(self, action: #selector(rowsChanged), for: .valueChanged)

        slidesStepper.minimumValue = 2
        slidesStepper.maximumValue = 10
        slidesStepper.value = Double(slideCount)
        slidesStepper.addTarget(self, action: #selector(slidesChanged), for: .valueChanged)
        slidesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        updateSlidesLabel()

        let slidesRow = UIStackView(arrangedSubviews: [slidesLabel, UIView(), slidesStepper])
        slidesRow.axis = .horizontal
        slidesRow.alignment = .center

        carouselOptions = UIStackView(arrangedSubviews: [slidesRow, ratioControl])
        carouselOptions.axis = .vertical
        carouselOptions.spacing = 12

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.backgroundColor = .secondarySystemBackground
        previewImageView.layer.cornerRadius = 8
        previewImageView.clipsToBounds = true
        previewImageView.isUserInteractionEnabled = true
        previewImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        previewImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        previewImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(previewTapped(_:))))

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center

        openInstagramBtn.setTitle(NSLocalizedString("splitOpenInstagram", comment: "Save & Open Instagram"), for: .normal)
        openInstagramBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        openInstagramBtn.setTitleColor(.white, for: .normal)
        openInstagramBtn.backgroundColor = UIColor(named: "violet") ?? .systemPurple
        openInstagramBtn.layer.cornerRadius = 25
        openInstagramBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        openInstagramBtn.addTarget(self, action: #selector(openInstagramBtnPressed), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [modeControl, previewImageView, carouselOptions, rowsControl, fitControl, hintLabel, openInstagramBtn])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .grid
        updateOptionsVisibility()
        rebuildPreview()
    }

    @objc private func fitChanged() {
        isNoCrop = fitControl.selectedSegmentIndex == 1
        rebuildPreview()
    }

    @objc private func ratioChanged() {
        slideRatio = SplitRenderer.Ratio.allCases[ratioControl.selectedSegmentIndex]
        rebuildPreview()
    }

    @objc private func rowsChanged() {
        gridRows = rowsControl.selectedSegmentIndex + 1
        rebuildPreview()
    }

    @objc private func slidesChanged() {
        slideCount = Int(slidesStepper.value)
        updateSlidesLabel()
        rebuildPreview()
    }

    /// Grid mode: tapping a tile posts just that tile to Instagram
    @objc private func previewTapped(_ gesture: UITapGestureRecognizer) {

        guard mode == .grid, let index = tileIndex(at: gesture.location(in: previewImageView)) else { return }

        renderTiles { [weak self] tiles in
            guard let self = self, index < tiles.count else { return }

            self.postToInstagram([tiles[index]]) { posted in
                guard posted else { return }
                self.postedTiles.insert(index)
                self.redrawPreview()
            }
        }
    }

    /// Carousel mode: saves every slide in order, then opens Instagram on slide 1
    @objc private func openInstagramBtnPressed() {

        renderTiles { [weak self] tiles in
            self?.postToInstagram(tiles) { _ in }
        }
    }

    // MARK: - Preview

    private var layout: SplitRenderer.Layout {
        switch mode {
        case .carousel:
            return SplitRenderer.Layout(columns: slideCount, rows: 1, tileRatio: slideRatio)
        case .grid:
            // Profile grid thumbnails are 3:4 since Instagram's 2025 grid update
            return SplitRenderer.Layout(columns: 3, rows: gridRows, tileRatio: .portrait34)
        }
    }

    private func updateOptionsVisibility() {

        carouselOptions.isHidden = mode != .carousel
        rowsControl.isHidden = mode != .grid
        openInstagramBtn.isHidden = mode != .carousel
        hintLabel.text = mode == .carousel
            ? NSLocalizedString("splitCarouselHint", comment: "carousel hint")
            : NSLocalizedString("splitGridHint", comment: "grid hint")
    }

    private func updateSlidesLabel() {
        slidesLabel.text = String.localizedStringWithFormat(NSLocalizedString("splitSlides %d", comment: "Slides: n"), slideCount)
    }

    /// Options changed: new tiles, so start over
    private func rebuildPreview() {

        fullTiles = nil
        postedTiles.removeAll()

        guard let source = previewSource else { return }

        let layout = self.layout
        let size = layout.canvasSize(tileWidth: 1200 / CGFloat(max(layout.columns, layout.rows)))
        previewCanvas = SplitRenderer.compose(image: source,
                                              blurredBackground: isNoCrop ? previewBlur : nil,
                                              canvasSize: size)
        redrawPreview()
    }

    private func redrawPreview() {

        guard let canvas = previewCanvas else { return }

        let layout = self.layout
        let total = layout.columns * layout.rows

        if mode == .grid {
            // Posting order is bottom-right first, so the newest post lands top-left on the profile
            let nextToPost = (0..<total).reversed().first { !postedTiles.contains($0) }
            previewImageView.image = SplitRenderer.previewWithDividers(canvas,
                                                                       layout: layout,
                                                                       number: { total - $0 },
                                                                       posted: postedTiles,
                                                                       highlighted: nextToPost)
        } else {
            previewImageView.image = SplitRenderer.previewWithDividers(canvas,
                                                                       layout: layout,
                                                                       number: { $0 + 1 },
                                                                       posted: [],
                                                                       highlighted: nil)
        }
    }

    /// Converts a tap in the aspect-fit image view to a row-major tile index
    private func tileIndex(at point: CGPoint) -> Int? {

        guard let image = previewImageView.image, image.size.width > 0, image.size.height > 0 else { return nil }

        let bounds = previewImageView.bounds
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let imageRect = CGRect(x: (bounds.width - image.size.width * scale) / 2,
                               y: (bounds.height - image.size.height * scale) / 2,
                               width: image.size.width * scale,
                               height: image.size.height * scale)
        guard imageRect.contains(point) else { return nil }

        let layout = self.layout
        let column = min(layout.columns - 1, Int((point.x - imageRect.minX) / (imageRect.width / CGFloat(layout.columns))))
        let row = min(layout.rows - 1, Int((point.y - imageRect.minY) / (imageRect.height / CGFloat(layout.rows))))
        return row * layout.columns + column
    }

    // MARK: - Rendering

    /// Renders full resolution tiles off the main thread (cached until options change)
    private func renderTiles(completion: @escaping ([UIImage]) -> Void) {

        if let tiles = fullTiles {
            completion(tiles)
            return
        }

        guard let image = sourceImage else { return }

        let layout = self.layout
        let isNoCrop = self.isNoCrop
        let cachedBlur = fullBlur

        SVProgressHUD.show()
        DispatchQueue.global(qos: .userInitiated).async { [extensions] in

            var blur = cachedBlur
            if isNoCrop && blur == nil, let small = SplitRenderer.downscaled(image, maxSide: 1500) {
                blur = extensions.applyBlur(to: small, intensity: 3.0)
            }

            let canvas = SplitRenderer.compose(image: image,
                                               blurredBackground: isNoCrop ? blur : nil,
                                               canvasSize: layout.canvasSize(tileWidth: SplitRenderer.tileWidth))
            let tiles = SplitRenderer.slice(canvas, layout: layout)

            DispatchQueue.main.async {
                if isNoCrop { self.fullBlur = blur }
                self.fullTiles = tiles
                SVProgressHUD.dismiss()
                completion(tiles)
            }
        }
    }

    // MARK: - Instagram

    /// Saves the images to Photos and opens Instagram's composer on the first one.
    /// Falls back to the share sheet when Instagram isn't installed.
    private func postToInstagram(_ images: [UIImage], completion: @escaping (Bool) -> Void) {

        guard let instagramURL = URL(string: "instagram://app"), UIApplication.shared.canOpenURL(instagramURL) else {
            shareImages(images, completion: completion)
            return
        }

        SVProgressHUD.show()
        saveSequentially(images) { [weak self] identifiers in
            SVProgressHUD.dismiss()
            guard let self = self else { return }

            guard let first = identifiers.first,
                  let encoded = first.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "instagram://library?LocalIdentifier=\(encoded)") else {

                self.extensions.presentAlert(title: nil,
                                             message: NSLocalizedString("imageNotSaved", comment: "imageNotSaved"),
                                             imageName: "icons-error",
                                             viewController: self)
                completion(false)
                return
            }

            UIApplication.shared.open(url) { opened in
                completion(opened)
            }
        }
    }

    private func shareImages(_ images: [UIImage], completion: @escaping (Bool) -> Void) {

        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = previewImageView // so that iPads won't crash
        activityViewController.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        present(activityViewController, animated: true)
    }

    /// Saves one at a time so Photos keeps them in order. Returns the new assets' identifiers (empty on failure).
    private func saveSequentially(_ images: [UIImage], completion: @escaping ([String]) -> Void) {

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var identifiers = [String]()

            func save(_ index: Int) {
                guard index < images.count else {
                    DispatchQueue.main.async { completion(identifiers) }
                    return
                }

                var placeholder: PHObjectPlaceholder?
                PHPhotoLibrary.shared().performChanges({
                    placeholder = PHAssetChangeRequest.creationRequestForAsset(from: images[index]).placeholderForCreatedAsset
                }) { success, _ in
                    if success, let identifier = placeholder?.localIdentifier {
                        identifiers.append(identifier)
                        save(index + 1)
                    } else {
                        DispatchQueue.main.async { completion([]) }
                    }
                }
            }

            save(0)
        }
    }
}

// MARK: - Renderer

enum SplitRenderer {

    /// Instagram's recommended width for feed images
    static let tileWidth: CGFloat = 1080

    enum Ratio: CaseIterable {
        case square
        case portrait45
        case portrait34

        var title: String {
            switch self {
            case .square: return "1:1"
            case .portrait45: return "4:5"
            case .portrait34: return "3:4"
            }
        }

        /// height / width
        var heightMultiplier: CGFloat {
            switch self {
            case .square: return 1
            case .portrait45: return 5.0 / 4.0
            case .portrait34: return 4.0 / 3.0
            }
        }
    }

    struct Layout {
        let columns: Int
        let rows: Int
        let tileRatio: Ratio

        func canvasSize(tileWidth: CGFloat) -> CGSize {
            let tileHeight = (tileWidth * tileRatio.heightMultiplier).rounded()
            return CGSize(width: tileWidth * CGFloat(columns), height: tileHeight * CGFloat(rows))
        }
    }

    static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage? {

        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let factor = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * factor).rounded(), height: (image.size.height * factor).rounded())
        return render(size: size) { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Fills the canvas with the image. With a blurred background, the whole image is fitted (no crop) on top of the blur.
    static func compose(image: UIImage, blurredBackground: UIImage?, canvasSize: CGSize) -> UIImage {

        let bounds = CGRect(origin: .zero, size: canvasSize)

        return render(size: canvasSize) { _ in
            if let blur = blurredBackground {
                blur.draw(in: aspectRect(for: blur.size, in: bounds, fill: true))
                image.draw(in: aspectRect(for: image.size, in: bounds, fill: false))
            } else {
                image.draw(in: aspectRect(for: image.size, in: bounds, fill: true))
            }
        }
    }

    /// Row-major, top-left tile first
    static func slice(_ canvas: UIImage, layout: Layout) -> [UIImage] {

        guard let cgImage = canvas.cgImage else { return [] }

        let tileWidth = CGFloat(cgImage.width) / CGFloat(layout.columns)
        let tileHeight = CGFloat(cgImage.height) / CGFloat(layout.rows)
        var tiles = [UIImage]()

        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let rect = CGRect(x: CGFloat(column) * tileWidth,
                                  y: CGFloat(row) * tileHeight,
                                  width: tileWidth,
                                  height: tileHeight).integral
                if let tile = cgImage.cropping(to: rect) {
                    tiles.append(UIImage(cgImage: tile))
                }
            }
        }

        return tiles
    }

    /// Draws tile dividers and number badges. Posted tiles are greyed out with a checkmark, the highlighted tile's badge is coloured.
    static func previewWithDividers(_ canvas: UIImage,
                                    layout: Layout,
                                    number: (Int) -> Int,
                                    posted: Set<Int>,
                                    highlighted: Int?) -> UIImage {

        let size = canvas.size
        let tileWidth = size.width / CGFloat(layout.columns)
        let tileHeight = size.height / CGFloat(layout.rows)
        let total = layout.columns * layout.rows

        func tileRect(_ index: Int) -> CGRect {
            CGRect(x: CGFloat(index % layout.columns) * tileWidth,
                   y: CGFloat(index / layout.columns) * tileHeight,
                   width: tileWidth,
                   height: tileHeight)
        }

        return render(size: size) { context in
            canvas.draw(at: .zero)

            let cg = context.cgContext

            for index in posted where index < total {
                cg.setFillColor(UIColor.systemGray.withAlphaComponent(0.7).cgColor)
                cg.fill(tileRect(index))
            }

            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(max(2, size.width / 400))
            for column in 1..<max(layout.columns, 1) {
                cg.move(to: CGPoint(x: CGFloat(column) * tileWidth, y: 0))
                cg.addLine(to: CGPoint(x: CGFloat(column) * tileWidth, y: size.height))
            }
            for row in 1..<max(layout.rows, 1) {
                cg.move(to: CGPoint(x: 0, y: CGFloat(row) * tileHeight))
                cg.addLine(to: CGPoint(x: size.width, y: CGFloat(row) * tileHeight))
            }
            cg.strokePath()

            let badgeSize = min(tileWidth, tileHeight) * 0.3
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: badgeSize * 0.55, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            for index in 0..<total {
                let isPosted = posted.contains(index)
                let tile = tileRect(index)
                let badge = CGRect(x: tile.midX - badgeSize / 2,
                                   y: tile.midY - badgeSize / 2,
                                   width: badgeSize,
                                   height: badgeSize)

                let badgeColor: UIColor
                if isPosted {
                    badgeColor = .darkGray
                } else if index == highlighted {
                    badgeColor = UIColor(named: "violet") ?? .systemPurple
                } else {
                    badgeColor = UIColor.black.withAlphaComponent(0.55)
                }
                cg.setFillColor(badgeColor.cgColor)
                cg.fillEllipse(in: badge)

                if index == highlighted {
                    cg.setStrokeColor(UIColor.white.cgColor)
                    cg.setLineWidth(badgeSize * 0.06)
                    cg.strokeEllipse(in: badge.insetBy(dx: badgeSize * 0.03, dy: badgeSize * 0.03))
                }

                let text = (isPosted ? "✓" : "\(number(index))") as NSString
                let textSize = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2),
                          withAttributes: attributes)
            }
        }
    }

    private static func aspectRect(for imageSize: CGSize, in bounds: CGRect, fill: Bool) -> CGRect {

        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    /// Scale 1 renderer so the output is exactly `size` pixels
    private static func render(size: CGSize, actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage {

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: actions)
    }
}
