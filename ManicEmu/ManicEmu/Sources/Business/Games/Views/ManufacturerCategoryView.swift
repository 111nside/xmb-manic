//
//  ManufacturerCategoryView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/9.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class ManufacturerCategoryView: BaseView {
    class ManufacturerCategoryCell: UICollectionViewCell {
        let normalImageView = ASIconView()
        let selectedImageView = ASIconView()
        
        var onLongPress: (()->Void)? = nil
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            enablePressEffect = true
            enableFocusEffects = false
            
            
            addSubview(normalImageView)
            normalImageView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.centerY.equalToSuperview()
            }
            
            addSubview(selectedImageView)
            selectedImageView.isHidden = true
            selectedImageView.snp.makeConstraints { make in
                make.edges.equalTo(normalImageView)
            }
            
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5
            longPress.cancelsTouchesInView = true
            longPress.delaysTouchesBegan = false
            longPress.delaysTouchesEnded = true
            addGestureRecognizer(longPress)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                onLongPress?()
            }
        }
        
        override var isSelected: Bool {
            willSet {
                normalImageView.isHidden = newValue
                selectedImageView.isHidden = !newValue
            }
        }
        
        func setDatas(normalImage: UIImage, highlightImage: UIImage) {
            normalImageView.icon = .image(normalImage)
            selectedImageView.icon = .image(highlightImage)
        }
    }
    
    private var manufacturers: [Manufacturer] = {
        return Theme.defalut.manufacturerOrder
    }()
    
    private var manufacturerOrderUpdateNotification: Any? = nil
    
    var didManufacturerChange: ((Manufacturer?)->Bool)? = nil
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: ManufacturerCategoryCell.self)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.isFocusable = true
        view.alwaysBounceHorizontal = false
        view.alwaysBounceVertical = false
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        return view
    }()
    
    deinit {
        if let manufacturerOrderUpdateNotification {
            NotificationCenter.default.removeObserver(manufacturerOrderUpdateNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        manufacturerOrderUpdateNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.ManufacturerOrderUpdate, object: nil, queue: .main, using: { [weak self] _ in
            self?.updateDatas()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(80),
                                                                                 heightDimension: .fractionalHeight(1)))
            

            
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(80),
                                                                                              heightDimension: .fractionalHeight(1)),
                                                           subitems: [item])
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = R.Size.ContentSpaceLarge
            section.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                            leading: R.Size.ContentSpaceMedium,
                                                            bottom: 0,
                                                            trailing: R.Size.ContentSpaceMedium)
            
            return section
        }
        return layout
    }
    
    func deselectAll() {
        if let indexPaths = collectionView.indexPathsForSelectedItems {
            for indexPath in indexPaths {
                collectionView.deselectItem(at: indexPath, animated: false)
            }
            _ = didManufacturerChange?(nil)
        }
    }
    
    private func updateDatas() {
        deselectAll()
        manufacturers = Theme.defalut.manufacturerOrder
        collectionView.reloadData()
    }
}

extension ManufacturerCategoryView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return manufacturers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: ManufacturerCategoryCell.self, for: indexPath)
        let manufacturer = manufacturers[indexPath.row]
        cell.setDatas(normalImage: manufacturer.normalImage, highlightImage: manufacturer.highlightImage)
        cell.onLongPress = {
            ASWebView.show(url: R.URLs.manufacturer(manufacturer))
        }
        cell.onFocusConfirm = { [weak self] in
            guard let self else { return false }
            if self.collectionView(self.collectionView, shouldSelectItemAt: indexPath) {
                self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
            }
            return true
        }
        return cell
    }
}

extension ManufacturerCategoryView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let cell = collectionView.cellForItem(at: indexPath), cell.isSelected {
            collectionView.deselectItem(at: indexPath, animated: true)
            return didManufacturerChange?(nil) ?? false
        }
        return didManufacturerChange?(manufacturers[indexPath.row]) ?? false
    }
}
