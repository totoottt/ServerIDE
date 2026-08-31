import SwiftUI
import UIKit

@MainActor
final class TerminalSelectionController: ObservableObject {
    weak var textView: UITextView?
    func beginFreeSelection() {
        guard let view = textView, !view.text.isEmpty else { return }
        view.becomeFirstResponder()
        let length = (view.text as NSString).length
        let location = min(max(0, view.selectedRange.location), length - 1)
        view.selectedRange = NSRange(location: location, length: 1)
        view.scrollRangeToVisible(view.selectedRange)
    }
    func selectAll() {
        guard let view = textView else { return }
        view.becomeFirstResponder()
        view.selectedRange = NSRange(location: 0, length: (view.text as NSString).length)
    }
    func copySelection() {
        guard let view = textView else { return }
        let text = view.text as NSString
        let range = view.selectedRange
        guard range.length > 0, NSMaxRange(range) <= text.length else { return }
        UIPasteboard.general.string = text.substring(with: range)
    }
    func find(_ query: String) {
        guard let view = textView, !query.isEmpty else { return }
        let range = (view.text as NSString).range(of: query, options: [.caseInsensitive])
        guard range.location != NSNotFound else { return }
        view.selectedRange = range
        view.scrollRangeToVisible(range)
    }
}

final class TerminalOutputTextView: UITextView {
    var wrapsLines = true
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = wrapsLines ? max(1, bounds.width - textContainerInset.left - textContainerInset.right) : 100_000
        if abs(textContainer.size.width - width) > 0.5 {
            textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        }
    }
}

struct SelectableTerminalOutput: UIViewRepresentable {
    let text: String
    let fontSize: Double
    let ink: Color
    let background: Color
    let followOutput: Bool
    let wrapLines: Bool
    let controller: TerminalSelectionController

    func makeUIView(context: Context) -> UITextView {
        let view = TerminalOutputTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isUserInteractionEnabled = true
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        view.accessibilityLabel = "SSH command output"
        controller.textView = view
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        controller.textView = view
        view.font = .monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .medium)
        view.textColor = UIColor(ink)
        view.backgroundColor = UIColor(background)
        (view as? TerminalOutputTextView)?.wrapsLines = wrapLines
        view.textContainer.widthTracksTextView = false
        view.textContainer.lineBreakMode = .byCharWrapping
        view.setNeedsLayout()
        view.alwaysBounceHorizontal = !wrapLines
        if view.text != text {
            let range = view.selectedRange
            view.text = text
            let length = (text as NSString).length
            if range.length > 0 && NSMaxRange(range) <= length { view.selectedRange = range }
            else if followOutput && length > 0 {
                view.scrollRangeToVisible(NSRange(location: length - 1, length: 1))
            }
        }
    }
}
