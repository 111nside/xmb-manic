//
//  swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASButton {
    enum State {
        case normal, disabled, highlight
    }
    
    enum Size {
        case fixHeight(CGFloat, insets: UIEdgeInsets = R.Size.ButtonInsets)
        case fixSize(CGSize, insets: UIEdgeInsets = R.Size.ButtonInsets)
    }
    
    struct Attributes {
        var icon: ASIcon? = nil
        var title: ASText? = nil
        var border: ASBorderStyle? = nil
        var background: UIColor = R.Color.BackgroundSecondary
    }
    
    var allAttributes: [State: Attributes] = [:]
    var state: State = .normal
    var sizeStyle: Size
    var enableGlass: Bool = false
    var ignoreBackgroundInGlass: Bool = true
    var cornerStyle: ASCornerStyle = .circle
    var titlePosition: UITextLayoutDirection = .right
    var tag: Int = 0
    
    ///The priority of normalAttributes is higher than that of allAttributes[.normal].
    init(normalAttributes: Attributes,
         allAttributes: [State : Attributes] = [:],
         state: State = .normal,
         sizeStyle: Size,
         enableGlass: Bool = false,
         cornerStyle: ASCornerStyle = .circle,
         titlePosition: UITextLayoutDirection = .right) {
        var temp = allAttributes
        temp[.normal] = normalAttributes
        self.allAttributes = temp
        self.state = state
        self.sizeStyle = sizeStyle
        self.enableGlass = enableGlass
        self.cornerStyle = cornerStyle
        self.titlePosition = titlePosition
    }
    
    func setAttributes(_ attributes: Attributes?, state: State) -> Self {
        var temp = self
        temp.allAttributes[state] = attributes
        return temp
    }
    
    func enableGlass(_ enable: Bool, ignoreBackground: Bool = true) -> Self {
        var button = self
        button.enableGlass = enable
        button.ignoreBackgroundInGlass = ignoreBackground
        return button
    }
    
    static func quickButton(icon: ASIcon? = nil,
                            title: String? = nil,
                            titleColor: UIColor = R.Color.LabelPrimary,
                            titleFont: UIFont = R.Font.Body(emphasis: true),
                            titleAlignment: NSTextAlignment = .left,
                            titlePosition: UITextLayoutDirection = .right,
                            background: UIColor = R.Color.BackgroundSecondary,
                            sizeStyle: Size) -> Self {
        
        var attributes = Attributes()
        if let icon {
            if case let .symbol(_, _, colors, _, _) = icon {
                if colors.count > 0 {
                    attributes.icon = icon.updateColorsIfNeed(colors: colors)
                } else {
                    attributes.icon = icon.updateColorsIfNeed(colors: [titleColor])
                }
            } else if case let .symbolImage(_, _, colors, _, _) = icon {
                if colors.count > 0 {
                    attributes.icon = icon.updateColorsIfNeed(colors: colors)
                } else {
                    attributes.icon = icon.updateColorsIfNeed(colors: [titleColor])
                }
            } else {
                attributes.icon = icon
            }
        }
        if let title {
            attributes.title = ASText(attributes: .init(text: title,
                                                        color: titleColor,
                                                        font: titleFont,
                                                        alignment: titleAlignment))
        }
        attributes.background = background
        return Self(normalAttributes: attributes, sizeStyle: sizeStyle, titlePosition: titlePosition)
    }
    
    ///The default font size is 15 medium.
    ///Works best with the sizes of ButtonExtraLarge 50.0
    static func extraLarge(icon: ASIcon? = nil,
                           title: String,
                           titleColor: UIColor = R.Color.LabelPrimary,
                           titleFont: UIFont = R.Font.Body(emphasis: true),
                           titleAlignment: NSTextAlignment = .left,
                           titlePosition: UITextLayoutDirection = .right,
                           background: UIColor = R.Color.BackgroundSecondary,
                           sizeStyle: Size = .fixHeight(R.Size.ButtonExtraLarge)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///The default font size is 15 medium.
    ///Works best with the sizes of ButtonExtraLarge 50.0 and ButtonLarge 44.0
    static func large(icon: ASIcon? = nil,
                      title: String,
                      titleColor: UIColor = R.Color.LabelPrimary,
                      titleFont: UIFont = R.Font.Body(emphasis: true),
                      titleAlignment: NSTextAlignment = .left,
                      titlePosition: UITextLayoutDirection = .right,
                      background: UIColor = R.Color.BackgroundSecondary,
                      sizeStyle: Size = .fixHeight(R.Size.ButtonLarge)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///The default font size is 14 regular.
    ///Works best with the sizes of ButtonMedium 40.0
    static func medium(icon: ASIcon? = nil,
                       title: String,
                       titleColor: UIColor = R.Color.LabelPrimary,
                       titleFont: UIFont = R.Font.Body2(),
                       titleAlignment: NSTextAlignment = .left,
                       titlePosition: UITextLayoutDirection = .right,
                       background: UIColor = R.Color.BackgroundSecondary,
                       sizeStyle: Size = .fixHeight(R.Size.ButtonMedium)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///The default font size is 14 regular.
    ///Works best with the sizes of ButtonSmall 36.0
    static func small(icon: ASIcon? = nil,
                      title: String,
                      titleColor: UIColor = R.Color.LabelPrimary,
                      titleFont: UIFont = R.Font.Body2(),
                      titleAlignment: NSTextAlignment = .left,
                      titlePosition: UITextLayoutDirection = .right,
                      background: UIColor = R.Color.BackgroundSecondary,
                      sizeStyle: Size = .fixHeight(R.Size.ButtonSmall)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///The default font size is 12 regular.
    ///Works best with the sizes of ButtonExtraSmall 30.0
    static func extraSmall(icon: ASIcon? = nil,
                           title: String,
                           titleColor: UIColor = R.Color.LabelPrimary,
                           titleFont: UIFont = R.Font.Footnote(),
                           titleAlignment: NSTextAlignment = .left,
                           titlePosition: UITextLayoutDirection = .right,
                           background: UIColor = R.Color.BackgroundSecondary,
                           sizeStyle: Size = .fixHeight(R.Size.ButtonExtraSmall)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///The default font size is 11 regular.
    ///Works best with the sizes of ButtonExtraExtraSmall 24.0
    static func extraExtraSmall(icon: ASIcon? = nil,
                                title: String,
                                titleColor: UIColor = R.Color.LabelPrimary,
                                titleFont: UIFont = R.Font.Caption(),
                                titleAlignment: NSTextAlignment = .left,
                                titlePosition: UITextLayoutDirection = .right,
                                background: UIColor = R.Color.BackgroundSecondary,
                                sizeStyle: Size = .fixHeight(R.Size.ButtonExtraExtraSmall)) -> Self {
        quickButton(icon: icon,
                    title: title,
                    titleColor: titleColor,
                    titleFont: titleFont,
                    titleAlignment: titleAlignment,
                    titlePosition: titlePosition,
                    background: background,
                    sizeStyle: sizeStyle)
    }
    
    ///Button with a chevron icon
    static func chevron(icon: ASIcon? = .symbol(.chevronRight, colors: [R.Color.LabelTertiary]),
                        title: String? = nil,
                        titleColor: UIColor = R.Color.LabelSecondary,
                        titleFont: UIFont = R.Font.Footnote(),
                        titleAlignment: NSTextAlignment = .left,
                        titlePosition: UITextLayoutDirection = .left,
                        background: UIColor = .clear,
                        sizeStyle: Size = .fixHeight(R.Size.ButtonExtraExtraSmall, insets: UIEdgeInsets(horizontal: 0, vertical: R.Size.ContentSpaceTiny*2))) -> Self {
        return quickButton(icon: icon,
                           title: title,
                           titleColor: titleColor,
                           titleFont: titleFont,
                           titleAlignment: titleAlignment,
                           titlePosition: titlePosition,
                           background: background,
                           sizeStyle: sizeStyle)
    }
    
    ///A button with just one icon
    static func iconOnly(icon: ASIcon,
                         iconSize: CGSize,
                         background: UIColor = .clear,
                         insets: UIEdgeInsets = .zero) -> Self {
        quickButton(icon: icon,
                    background: background,
                    sizeStyle: .fixSize(iconSize, insets: insets))
    }
    
    ///Standard default button Default: 36x36 insets: 4
    static func iconOnlyWithSmallSize(icon: ASIcon,
                                      iconSize: CGSize = CGSize(R.Size.ButtonSmall),
                                      background: UIColor = R.Color.BackgroundSecondary,
                                      insets: UIEdgeInsets = .init(inset: R.Size.ContentSpaceExtraExtraSmall)) -> ASButton {
        return iconOnly(icon: icon, iconSize: iconSize, background: background, insets: insets)
    }
    
    ///Text buttons on the navigation bar. font: 13 medium
    static func headerTitle(icon: ASIcon? = nil,
                            title: String,
                            titleColor: UIColor = R.Color.LabelSecondary,
                            titleFont: UIFont = R.Font.Subheadline(emphasis: true),
                            titlePosition: UITextLayoutDirection = .left,
                            background: UIColor = .clear,
                            sizeStyle: Size = .fixHeight(R.Size.SupplementaryButtonHeight, insets: .init(inset: 0))) -> Self {
        var modIcon = icon
        if let icon {
            modIcon = icon.updateColorsIfNeed(colors: [titleColor], forceUpdate: true)
        }
        return quickButton(icon: modIcon, title: title, titleColor: titleColor, titleFont: titleFont, titlePosition: titlePosition, background: background, sizeStyle: sizeStyle)
    }
    
    ///Text buttons. font: 12
    static func headerDetail(icon: ASIcon? = nil,
                             title: String,
                             titleColor: UIColor = R.Color.LabelSecondary,
                             titleFont: UIFont = R.Font.Footnote(),
                             titlePosition: UITextLayoutDirection = .left,
                             background: UIColor = .clear,
                             sizeStyle: Size = .fixHeight(R.Size.SupplementaryButtonHeight, insets: .init(inset: 0))) -> Self {
        var modIcon = icon
        if let icon {
            modIcon = icon.updateColorsIfNeed(colors: [titleColor], forceUpdate: true)
        }
        return quickButton(icon: modIcon, title: title, titleColor: titleColor, titleFont: titleFont, titlePosition: titlePosition, background: background, sizeStyle: sizeStyle)
    }
    
    static func smallIconButton(icon: ASIcon,
                                background: UIColor = R.Color.BackgroundSecondary,
                                insets: UIEdgeInsets = .init(inset: R.Size.ContentSpaceExtraSmall)) -> Self {
        .iconOnly(icon: icon,
                  iconSize: CGSize(R.Size.ButtonSmall),
                  background: background,
                  insets: insets)
    }
    
    static func smallCloseButton() -> Self {
        .smallIconButton(icon: .symbolImage(R.image.close_iconSymbols())).enableGlass(true)
    }
}
