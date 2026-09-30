//
//  GridSafeOverlayView.swift
//  InstaCrop
//
//  Shows which part of the post stays visible in Instagram's 3:4 profile grid thumbnail.
//

import UIKit

class GridSafeOverlayView: UIView {

    /// Profile grid thumbnails are 3:4 (width / height)
    private let gridRatio: CGFloat = 3.0 / 4.0

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {

        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        addSubview(label)
    }

    private var visibleRect: CGRect {

        guard bounds.height > 0 else { return bounds }

        if bounds.width / bounds.height > gridRatio {
            let width = bounds.height * gridRatio
            return CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: bounds.height)
        } else {
            let height = bounds.width / gridRatio
            return CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
        }
    }

    private var isFullyVisible: Bool {
        abs(visibleRect.width - bounds.width) < 1 && abs(visibleRect.height - bounds.height) < 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        label.text = isFullyVisible
            ? NSLocalizedString("gridSafeFull", comment: "Fully visible on profile grid")
            : NSLocalizedString("gridSafeLabel", comment: "Profile grid shows this area")
        let size = label.intrinsicContentSize
        label.frame = CGRect(x: (bounds.width - size.width - 12) / 2,
                             y: 8,
                             width: size.width + 12,
                             height: size.height + 6)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {

        guard let context = UIGraphicsGetCurrentContext() else { return }

        let visible = visibleRect

        // Dim the parts the grid thumbnail cuts off
        context.setFillColor(UIColor.black.withAlphaComponent(0.45).cgColor)
        context.addRect(bounds)
        context.addRect(visible)
        context.fillPath(using: .evenOdd)

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(visible.insetBy(dx: 0.75, dy: 0.75))
    }
}
