//
//  UITextFieldExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/7.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension UITextField {
    @objc func modifyClearButton(with image : UIImage, size: CGFloat = 0) {
        let clearButton = UIButton(type: .custom)
        clearButton.frame = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        clearButton.setImage(image, for: .normal)
        clearButton.addTarget(self, action: #selector(UITextField.clear(_:)), for: .touchUpInside)

        rightView = clearButton
        rightViewMode = .whileEditing
    }

    @objc func clear(_ sender : AnyObject) {
        if delegate?.textFieldShouldClear?(self) == true {
            self.text = ""
            sendActions(for: .editingChanged)
        }
    }
    
    
}
