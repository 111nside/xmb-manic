//
//  ASInput.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASInput {
    enum Action {
        case textChange(String?)
        case tapClear
        case tapReturn(String?)
    }
    
    var textAttributes = ASText.Attributes(text: "",
                                           color: R.Color.LabelPrimary,
                                           font: R.Font.Body(emphasis: true))
    var placeholderAttributes: ASText.Attributes? = nil
    var icon: ASIcon? = nil
    var insets = UIEdgeInsets(inset: R.Size.ContentSpaceSmall)
    var spacing = R.Size.ContentSpaceExtraSmall
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .done
    var clearButtonMode: UITextField.ViewMode = .whileEditing
    var cornerStyle: ASCornerStyle = .circle
    var keyboardDistance = R.Size.KeyboardDistance
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var autocorrectionType: UITextAutocorrectionType = .default
    var isSecureTextEntry: Bool = false
    
    static func large(text: String? = nil,
                      placeholder: String? = nil,
                      icon: ASIcon? = nil) -> Self {
        var placeholderAttributes: ASText.Attributes? = nil
        if let placeholder {
            placeholderAttributes = ASText.Attributes(text: placeholder,
                                                      color: R.Color.LabelTertiary,
                                                      font: R.Font.Body())
        }
        
        return ASInput(textAttributes: .title(text: text ?? ""),
                       placeholderAttributes: placeholderAttributes,
                       icon: icon,
                       cornerStyle: .radius(R.Size.ContentSpaceMedium))
    }
    
    static func small(text: String? = nil,
                      placeholder: String? = nil,
                      icon: ASIcon? = nil) -> Self {
        let textAttributes = ASText.Attributes(text: text ?? "",
                                               color: R.Color.LabelPrimary,
                                               font: R.Font.Body2())
        
        var placeholderAttributes: ASText.Attributes? = nil
        if let placeholder {
            placeholderAttributes = ASText.Attributes(text: placeholder,
                                                      color: R.Color.LabelTertiary,
                                                      font: R.Font.Body2())
        }
        
        return ASInput(textAttributes: textAttributes,
                       placeholderAttributes: placeholderAttributes,
                       icon: icon,
                       insets: .init(horizontal: R.Size.ContentSpaceSmall*2, vertical: R.Size.ContentSpaceExtraExtraSmall*2),
                       spacing: R.Size.ContentSpaceTiny)
    }
    
}


