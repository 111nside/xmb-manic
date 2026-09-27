//
//  ShaderInfoView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
import ProHUD

class ShaderInfoView: BaseView {
    
    private var originShader: Shader
    private var editShader: Shader
    private var libretroEngine: Any? = nil
    
    private var didSavedShader: ((Shader) -> Void)? = nil
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            self.handleAction(action)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard var shader = parameters.compactMap({ $0 as? Shader }).first else {
            return nil
        }
        shader.isBase = true
        self.originShader = shader
        self.editShader = shader
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        UIView.makeLoading()
        DispatchQueue.main.asyncAfter(delay: 0.35, execute: { [weak self] in
            guard let self else { return }
            if !PlayViewController.isGaming {
                self.libretroEngine = LibretroCore.sharedInstance().start(withCustomSaveDir: nil)
                LibretroCore.sharedInstance().pause()
            }
            
            if LibretroCore.sharedInstance().setShader(self.editShader.forceBasePath ?? self.editShader.filePath) {
                self.originShader.fulfillAppendedShaders()
                self.originShader.updateAppendedShadersForEngine()
                self.originShader.updateForceBasePrameters()
                self.originShader.fulfillParameters()
                self.editShader = self.originShader
                UIView.hideLoading()
                self.updateContents()
            } else {
                DispatchQueue.main.asyncAfter(delay: 1.5) {
                    UIView.hideLoading()
                    UIView.makeToast(message: R.string.localizable.shaderLoadFailed())
                    self.hide()
                }
            }
        })
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if action.isBottom {
            //save action
            if editShader.title == "retroarch" {
                UIView.makeToast(message: R.string.localizable.customShaderTitleWrong())
                return
            }
            
            func saveShader() {
                if !FileManager.default.fileExists(atPath: editShader.changingPath) {
                    UIView.makeAlert(detail: R.string.localizable.customShaderSaveFailed(),
                                     cancelTitle: R.string.localizable.confirmTitle())
                    return
                }
                editShader.optimizeConfig()
                try? FileManager.safeCopyItem(at: URL(fileURLWithPath: editShader.changingPath),
                                              to: URL(fileURLWithPath: editShader.customPath),
                                              shouldReplace: true)
                UIView.makeToast(message: R.string.localizable.customShaderSaveSuccess(editShader.title))
                didSavedShader?(editShader)
                self.hide()
            }
            
            if FileManager.default.fileExists(atPath: editShader.customPath) {
                UIView.makeAlert(detail: R.string.localizable.customShaderExists(),
                                 confirmTitle: R.string.localizable.confirmTitle(),
                                 confirmAction: {
                    saveShader()
                })
            } else {
                saveShader()
            }
        } else if action.navigationValue?.isTapClose ?? false {
            //close
            if editShader != originShader {
                UIView.makeAlert(detail: R.string.localizable.changeAlert(),
                                 confirmTitle: R.string.localizable.multiDiscContinueClose(),
                                 confirmAction: {
                    self.hide()
                })
            } else {
                self.hide()
            }
        } else if let inputItemValue = action.inputValue?.action {
            
            func validateString(_ string: String?, reload: Bool) {
                var text = string
                if let string {
                    if string.count > 255 {
                        text = String(string[...255])
                    }
                }
                editShader.title = text ?? ""
                updateBottom()
                if reload {
                    updateContents()
                }
            }
            
            switch inputItemValue {
            case .textChange(let string):
                validateString(string, reload: false)
            case .tapClear:
                validateString("", reload: false)
            case .tapReturn(let string):
                validateString(string, reload: true)
            }
            
            
            
        } else if let normalItemValue = action.normalItemValue {
            let indexPath = normalItemValue.indexPath
            if indexPath.section == 2 {
                //append shaders
                ShaderOrderView.show(shader: editShader, didChangeShader: { [weak self] modifiedShader in
                    guard let self, let modifiedShader else { return }
                    UIView.makeLoading()
                    DispatchQueue.main.asyncAfter(delay: 0.35, execute: {
                        self.editShader = modifiedShader
                        self.editShader.updateAppendedShadersForEngine()
                        let changingParameters = self.editShader.getChangingParameters(with: self.originShader)
                        for parameter in changingParameters {
                            self.editShader.updateParameters(identifier: parameter.identifier, value: parameter.value)
                        }
                        self.editShader.fulfillParameters()
                        self.updateContents()
                        self.updateBottom()
                        UIView.hideLoading()
                    })
                })

            } else if indexPath.section == 3 {
                let param = editShader.parameters[indexPath.row]

                let values = Array(stride(from: Double(param.minimum), through: Double(param.maximum), by: Double(param.step)))
                let datas = values.map({ $0.roundedDecimal(scale: 4) }).map({ "\($0.stringValue(minFraction: 1, maxFraction: 4))" })
                let selectedIndex = values.firstIndex(of: Double(param.current)) ?? 0
                
                ASSheetView.show(.init(style: .picker(title: param.desc,
                                                      datas: datas,
                                                      selectedIndex: selectedIndex)),
                                 action: { [weak self] action, _ in
                    guard let self else { return .dismiss() }
                    
                    if let pickerValue = action.pickerValue {
                        let value = values[pickerValue.index]
                        self.editShader.parameters[indexPath.row].current = Float(value)
                        self.editShader.updateParameters(identifier: self.editShader.parameters[indexPath.row].identifier,
                                                         value: Float(value))
                        self.updateContents()
                        self.updateBottom()
                        return .none
                    } else {
                        return .dismiss()
                    }
                })
            }
        }
    }
    
    private func getListPage() -> ASListPage {
        return ASListPage(navigation: .defaultNavigation(),
                          sections: getSections(),
                          bottom: getBottom(),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func getSections() -> [ASListPage.Section] {
        var sections = [ASListPage.Section]()
        //desc
        sections.append(.init(cells: [],
                              header: .texts([.smallText(R.string.localizable.shaderEditAlert(),
                                                         numberOfLines: 0)],
                                             pin: false)))
        
        //title
        sections.append(.init(cells: [.input(.large(text: editShader.title,
                                                    placeholder: R.string.localizable.cheatCodeNamePlaceHolder(),
                                                    icon: .symbolImage(R.image.renameRegular_iconSymbols())))],
                              header: .defaultHeader(title: R.string.localizable.shaderName())))
        
        //append shaders
        sections.append(.init(cells: [.iconTitleDetailChevronCell(icon: .symbolImage(R.image.shaders_iconSymbols()),
                                                                  title: R.string.localizable.appendShadersTitle(),
                                                                  detail: R.string.localizable.appendShadersDetail(),
                                                                  chevronTitle: "\(editShader.appendedShaders.count)")],
                              header: .defaultHeader(title: R.string.localizable.appendShadersTitle())))
        
        //parameters
        sections.append(.init(cells: editShader.parameters.map({
            .iconTitleChevronCell(title: $0.desc,
                                  chevronTitle: "\($0.current.roundedString(scale: 4, minFraction: 1, maxFraction: 4))")
        }),
                              header: .defaultHeader(title: R.string.localizable.parameters())))
        
        return sections
        
    }
    
    private func getBottom() -> ASButton {
        var button = ASButton.large(title: R.string.localizable.saveTitle(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        var disableAttributes = button.allAttributes[.normal]!
        disableAttributes.background = R.Color.BackgroundSecondary
        disableAttributes.title?.attributes?.color = R.Color.LabelTertiary
        button.allAttributes[.disabled] = disableAttributes
        button.state = .disabled
        return button
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
    
    private func updateBottom() {
        if var bottom = listPageView.bottom {
            bottom.state = (originShader == editShader || editShader.title.trimmed.isEmpty) ? .disabled : .normal
            listPageView.bottom = bottom
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let _ = libretroEngine {
            LibretroCore.sharedInstance().resume()
            LibretroCore.sharedInstance().stop()
        }
    }
}

extension ShaderInfoView: ShowableView {
    static func show(shader: Shader, didSavedShader: ((Shader) -> Void)? = nil) {
        Self.show(parameters: shader)?.didSavedShader = didSavedShader
    }
}
