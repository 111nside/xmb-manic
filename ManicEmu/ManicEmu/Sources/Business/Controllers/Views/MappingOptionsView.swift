//
//  MappingOptionsView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class MappingOptionsView: BaseView {
    private var mappingOptions = [MappingOption]()
    
    var didTapOption: ((MappingOption) -> Void)? = nil
    
    lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let index = action.normalItemValue?.indexPath.section {
                self.didTapOption?(mappingOptions[index])
            }
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getListPage() -> ASListPage {
        let sections: [ASListPage.Section] = mappingOptions.map({
            .init(cells: [.iconTitleChevronCell(icon: $0.icon,
                                                title: $0.title,
                                                titleColor: $0 == .quit ? R.Color.Red : R.Color.LabelPrimary)],
                  decoration: .init(style: .primary))
        })
        return ASListPage(sections: sections,
                          backgroundColor: .clear,
                          listInsets: .insets(top: -R.Size.ContentSpaceLarge))
    }
    
    func updateContents(games: [Game]) {
        mappingOptions = MappingOption.availableOptions(games: games)
        listPageView.updatePage(getListPage())
    }
}
