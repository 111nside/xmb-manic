//
//  ShaderOrderView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import ProHUD

class ShaderOrderView: BaseView {
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        view.enableReorder(true,
                           scope: .section,
                           keepSupplementaryPlace: true,
                           beginReorder: { _ in true },
                           sectionReorderDidUpdate: { intent in
            if case let .moveSection(from, to) = intent {
                return from != to
            }
            return true
        }, sectionDidReorder: { [weak self] intent in
            guard let self,
                  case let .moveSection(from, to) = intent else { return }
            let shader = self.appendedShaders.remove(at: from)
            self.appendedShaders.insert(shader, at: to)
            self.updateBottom()
        })
        return view
    }()
    
    private let shader: Shader
    private var appendedShaders: [Shader]
    private var isOrderChange: Bool {
        var isOrderChange = false
        let modifiedAppendedShaders = appendedShaders
        var originalAppendedShaders = shader.appendedShaders
        originalAppendedShaders.insert(shader, at: shader.indexInAppendage)
        if modifiedAppendedShaders.count != originalAppendedShaders.count {
            isOrderChange = true
        } else {
            for (index, shader) in modifiedAppendedShaders.enumerated() {
                if shader.relativePath != originalAppendedShaders[index].relativePath {
                    isOrderChange = true
                    break
                }
            }
        }
        return isOrderChange
    }
    private var didChangeShader: ((Shader)->Void)? = nil
    
    required init?(parameters: Any...) {
        guard let shader = parameters.compactMap({ $0 as? Shader }).first else { return nil }
        self.shader = shader
        self.appendedShaders = shader.appendedShaders
        self.appendedShaders.insert(shader, at: shader.indexInAppendage)
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if let navigationValue = action.navigationValue {
            if navigationValue.isTapClose {
                //close
                self.hide()
                
            } else if let _ = navigationValue.tapToolsValue {
                //add shader
                let view = ShaderListView.show(initType: .preview,
                                               isGlsl: shader.relativePath.pathExtension.lowercased() == "glslp")
                view.didSelectShaderForPreview = { [weak self] newShader in
                    guard let self else { return }
                    self.appendedShaders.append(newShader)
                    self.updateContents()
                    self.updateBottom()
                }
                
            }
        } else if let normalItemValue = action.normalItemValue {
            //delete
            if let _ = normalItemValue.subActions {
                appendedShaders.remove(at: normalItemValue.indexPath.section)
                updateContents()
                updateBottom()
            }
            
        } else if action.isBottom {
            if isOrderChange {
                var shader = self.shader
                if let index = appendedShaders.firstIndex(where: { $0.isBase }) {
                    shader.indexInAppendage = index
                }
                appendedShaders.removeAll(where: { $0.isBase })
                shader.appendedShaders = appendedShaders
                didChangeShader?(shader)
            }
            self.hide()
        }
    }
    
    private func getListPage() -> ASListPage {
        var button = ASButton.large(title: R.string.localizable.saveTitle(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        button.state = .disabled
        
        
        return ASListPage(navigation: .defaultNavigation(title: R.string.localizable.shadersOrder(),
                                                         titleIcon: .symbol(.sparklesRectangleStackFill),
                                                         tools: [.symbolImage(R.image.copy_iconSymbols())]),
                          sections: getSections(),
                          bottom: button,
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func getSections() -> [ASListPage.Section] {
        return appendedShaders.enumerated().map({
            var styles = [ASListPage.Cell.Style]()
            styles.append(.title(.largeText($1.title + ($1.isBase ? " (\(R.string.localizable.base()))" : ""))))
            if !$1.isBase {
                styles.append(.button(.iconOnly(icon: .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                iconSize: CGSize(R.Size.ButtonExtraExtraSmall))))
            }
            var handler: ASButton = .iconOnly(icon: .symbol(.line3Horizontal, colors: [R.Color.LabelSecondary]),
                                              iconSize: CGSize(R.Size.ButtonExtraExtraSmall))
            handler.allAttributes[.disabled] = handler.allAttributes[.normal]
            handler.state = .disabled
            styles.append(.button(handler))
            if $0 == 0 {
                let text = R.string.localizable.shaderOrderDesc()
                var headerText: ASText = .smallText(text)
                headerText.textIcons = [.init(icon: .symbolImage(R.image.info_iconSymbols()),
                                              iconSize: R.Size.IconSizeExtraSmall.height)]
                return ASListPage.Section(cells: [ASListPage.Cell.normal(styles, enablePressEffect: false)],
                                          header: ASListPage.Supplementary.texts([headerText], pin: false))
            } else {
                return ASListPage.Section(cells: [ASListPage.Cell.normal(styles, enablePressEffect: false)])
            }
        })
    }
    
    private func updateBottom() {
        if var bottom = listPageView.bottom {
            bottom.state = isOrderChange ? .normal : .disabled
            listPageView.bottom = bottom
        }
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
}

extension ShaderOrderView: ShowableView {
    static func show(shader: Shader, didChangeShader: ((Shader?)->Void)? = nil) {
        Self.show(parameters: shader)?.didChangeShader = didChangeShader
    }
}
