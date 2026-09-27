//
//  GameMetadataSearchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/12.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class GameMetadataSearchView: BaseView {
    
    private let game: Game
    private var results = [GameMetadata]()
    var didSelectMetadata: ((GameMetadata) -> Void)?
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            self?.handleAction(action)
        }
        view.didScroll = { [weak self] _ in
            self?.searchInputView.resignFirstResponder()
        }
        return view
    }()
    
    private lazy var searchInputView: ASListInputView = {
        var input = ASInput.large(
            text: game.displayName,
            placeholder: R.string.localizable.gamesSearchPlaceHolder(),
            icon: .symbolImage(R.image.searchRegular_iconSymbols())
        )
        input.returnKeyType = .search
        let view = ASListInputView(input)
        view.didTapReturn = { [weak self] searchText in
            guard let self else { return }
            self.searchInputView.resignFirstResponder()
            self.performSearch(text: searchText)
        }
        view.didInputChange = { [weak self] searchText in
            // 清空时同步清空结果
            if searchText?.trimmed.isEmpty ?? true {
                self?.results = []
                self?.updateContents()
            }
        }
        return view
    }()
    
    private lazy var topView: UIView = {
        let view = UIView()
        view.addSubview(searchInputView)
        searchInputView.snp.makeConstraints { make in
            make.top.equalTo(R.Size.ContentSpaceLarge)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightSmall)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let game = parameters.first as? Game else { return nil }
        self.game = game
        super.init(frame: .zero)
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func handleAction(_ action: ASListPage.Action) {
        if action.navigationValue?.isTapClose == true {
            hide()
            return
        }
        
        if let index = action.normalItemValue?.indexPath.section,
           results.indices.contains(index) {
            let metadata = results[index]
            didSelectMetadata?(metadata)
            hide()
        }
    }
    
    private func performSearch(text: String?) {
        guard let text = text?.trimmed, !text.isEmpty else {
            results = []
            updateContents()
            return
        }
        
        UIView.makeLoading()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let searched = GameMetadataKit.searchGameInfo(displayName: text)
            DispatchQueue.main.async {
                guard let self else { return }
                UIView.hideLoading()
                self.results = searched
                self.updateContents()
                self.listPageView.collectionView.scrollToTop()
            }
        }
    }
    
    private func getSections() -> [ASListPage.Section] {
        results.map { metadata in
            let detailParts = [metadata.platform, metadata.genre, metadata.releaseDateDisplay]
                .filter { !$0.isEmpty && $0 != "—" }
            let detail = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")
            return ASListPage.Section(cells: [
                .iconTitleDetailChevronCell(title: metadata.displayName.isEmpty ? metadata.fullName : metadata.displayName,
                                            detail: detail)
            ])
        }
    }
    
    private func getListPage() -> ASListPage {
        ASListPage(navigation: .defaultNavigation(title: R.string.localizable.searchMetadata(),
                                                  titleIcon: .symbolImage(R.image.searchRegular_iconSymbols())),
                   top: (topView, .fixedHeight(R.Size.ItemHeightExtraLarge), true),
                   sections: getSections(),
                   blankSlate: .init(),
                   backgroundColor: .clear,
                   pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
}

extension GameMetadataSearchView: ShowableView {
    static func show(game: Game, didSelectMetadata: ((GameMetadata) -> Void)? = nil) {
        let view = Self.show(parameters: game)
        view?.didSelectMetadata = didSelectMetadata
    }
    
    func didShowUp() {
        // 打开时用当前游戏名预填并自动搜一次
        if let text = searchInputView.text?.trimmed, !text.isEmpty {
            performSearch(text: text)
        } else {
            searchInputView.becomeFirstResponder()
        }
    }
}
