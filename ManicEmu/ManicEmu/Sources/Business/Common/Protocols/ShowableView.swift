//
//  ShowableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/30.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import ProHUD

protocol UIViewAndControllerType: AnyObject {}

extension UIView: UIViewAndControllerType {}

extension UIViewController: UIViewAndControllerType {}

protocol ShowableView: UIViewAndControllerType {
    static var hasShownInstance: Bool { get }
    
    var isShow: Bool { get }
    
    //sheet identifier
    var identifier: String { get }
    
    ///Expected height of the sheet to display, default is SheetWindowMaxSize.height
    ///If it returns nil, it will try to use automatic constraints.
    var prefferdConstraintHeight: CGFloat? { get }
    
    ///The view that implements Showable View must implement this initialization method.
    init?(parameters: Any...)
    
    ///For external use, this view is displayed in a sheet format.
    static func show(parameters: Any...) -> Self?
    
    ///hide sheet
    func hide()
    
    //When about to display the sheet, you can modify the data source.
    func dataForShow(_ defaultData: ASSheet) -> ASSheet
    
    //Page show success callback
    func didShowUp()
    
    //Page hide callback
    func didHide()
    
    func preferredFocusView() -> UIView?
}

extension ShowableView where Self: UIView {
    static var hasShownInstance: Bool {
        Sheet.findAll().count(where: {
            $0.identifier.hasPrefix("\(String(describing: self))")
        }) > 0 ? true : false
    }
    
    var isShow: Bool {
        Sheet.find(identifier: identifier).count > 0 ? true : false
    }
    
    var identifier: String {
        "\(String(describing: type(of: self)))_\(Unmanaged.passUnretained(self).toOpaque())"
    }
    
    var prefferdConstraintHeight: CGFloat? {
        return R.Size.SheetWindowMaxSize.height
    }
    
    @discardableResult
    static func show(parameters: Any...) -> Self? {
        if let view = Self(parameters: parameters) {
            view.showAsSheet = true
            let sheetData = ASSheet.init(style: .custom(view, constraintMaker: { make in
                make.edges.equalToSuperview()
            }))
            ASSheetView.show(view.dataForShow(sheetData),
                             identifier: view.identifier,
                             showSuccess: { [weak view] _ in
                view?.didShowUp()
            }, dismiss: { [weak view] in
                view?.didHide()
            }, preferredFocusView: { [weak view] in
                return view?.preferredFocusView()
            })
            return view
        }
        return nil
    }
    
    func hide() {
        Sheet.find(identifier: identifier).last?.pop()
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        return defaultData
    }
    
    func didShowUp() {}
    
    func didHide() {}
    
    func preferredFocusView() -> UIView? {
        return nil
    }
}

fileprivate var ShowableViewShowAsSheetKey: UInt8 = 0

extension ShowableView {
    ///Should it be displayed in a sheet format?
    ///⚠️ Note: The real value cannot be obtained in the init method.
    private(set) var showAsSheet: Bool {
        get { (objc_getAssociatedObject(self, &ShowableViewShowAsSheetKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &ShowableViewShowAsSheetKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
