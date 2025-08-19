
import SwiftUI
import AppKit

struct FontPickerView: NSViewRepresentable {
    @Binding var selection: String

    func makeNSView(context: Context) -> NSPopUpButton {
        let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popUpButton.target = context.coordinator
        popUpButton.action = #selector(Coordinator.fontChanged(_:))
        
        let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
        
        for familyName in fontFamilies {
            let localizedName = localizedFontName(for: familyName)
            let item = NSMenuItem(title: localizedName, action: nil, keyEquivalent: "")
            item.representedObject = familyName
            
            // Preview the font
            if let font = NSFont(name: familyName, size: 14) {
                item.attributedTitle = NSAttributedString(string: localizedName, attributes: [.font: font])
            }
            
            popUpButton.menu?.addItem(item)
        }
        
        updateSelection(for: popUpButton)
        
        return popUpButton
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        updateSelection(for: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateSelection(for popUpButton: NSPopUpButton) {
        // Try to select the item matching the binding's value.
        if let itemToSelect = popUpButton.menu?.items.first(where: { ($0.representedObject as? String) == selection }) {
            popUpButton.select(itemToSelect)
        } else {
            // If the selection from the model is not found (e.g., font uninstalled),
            // visually select the first item as a fallback.
            // Crucially, DO NOT update the binding. This preserves the original value in the model.
            if let firstItem = popUpButton.menu?.items.first {
                popUpButton.select(firstItem)
            }
        }
    }
    
    private func localizedFontName(for familyName: String) -> String {
        let attributes = [kCTFontFamilyNameAttribute: familyName] as CFDictionary
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes)
        
        if let localized = CTFontDescriptorCopyLocalizedAttribute(descriptor, kCTFontFamilyNameAttribute, nil) {
            if let localizedString = localized as? String {
                return localizedString
            }
        }
        return familyName
    }

    class Coordinator: NSObject {
        var parent: FontPickerView

        init(_ parent: FontPickerView) {
            self.parent = parent
        }

        @objc func fontChanged(_ sender: NSPopUpButton) {
            if let selectedFamilyName = sender.selectedItem?.representedObject as? String {
                parent.selection = selectedFamilyName
            }
        }
    }
}
