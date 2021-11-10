//
//  GridCollectionViewLayout.swift
//  StickyGridCollectionView-Final
//
//  Created by Vadim Bulavin on 10/1/18.
//  Copyright © 2018 Vadim Bulavin. All rights reserved.
//

import UIKit

protocol StickyGridCollectionViewLayoutDelegate: AnyObject {
    func heightForRows() -> CGFloat
}

class StickyGridCollectionViewLayout: UICollectionViewFlowLayout {

	var stickyRowsCount = 0 {
		didSet {
			invalidateLayout()
		}
	}

	var stickyColumnsCount = 0 {
		didSet {
			invalidateLayout()
		}
	}

    weak var delegate: StickyGridCollectionViewLayoutDelegate?
    
	private var allAttributes: [[UICollectionViewLayoutAttributes]] = []
	private var contentSize = CGSize.zero

	func isItemSticky(at indexPath: IndexPath) -> Bool {
		return indexPath.item < stickyColumnsCount || indexPath.section < stickyRowsCount
	}
    
    func resetLayout() {
        allAttributes = []
        invalidateLayout()
    }

	// MARK: - Collection view flow layout methods

	override var collectionViewContentSize: CGSize {
		return contentSize
	}

	override func prepare() {
        if allAttributes.isEmpty {
            setupAttributes()
        } else {
            updateStickyAttributes()
        }
		updateStickyItemsPositions()

		let lastItemFrame = allAttributes.last?.last?.frame ?? .zero
		contentSize = CGSize(width: lastItemFrame.maxX, height: lastItemFrame.maxY)
	}

	override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		var layoutAttributes = [UICollectionViewLayoutAttributes]()

		for rowAttrs in allAttributes {
			for itemAttrs in rowAttrs where rect.intersects(itemAttrs.frame) {
				layoutAttributes.append(itemAttrs)
			}
		}

		return layoutAttributes
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}

	// MARK: - Helpers

	private func setupAttributes() {
		var xOffset: CGFloat = 0
		var yOffset: CGFloat = 0

        for row in 0..<rowsCount {
			var rowAttrs: [UICollectionViewLayoutAttributes] = []
			xOffset = 0

			for col in 0..<columnsCount(in: row) {
				let itemSize = size(forRow: row, column: col)
				let indexPath = IndexPath(row: row, column: col)
				let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
				attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemSize.width, height: itemSize.height).integral

				rowAttrs.append(attributes)

				xOffset += itemSize.width
			}

			yOffset += rowAttrs.last?.frame.height ?? 0.0
			allAttributes.append(rowAttrs)
		}
	}
    
    private func updateStickyAttributes() {
        guard
            let visibleRange = visibleRange(),
            let height = delegate?.heightForRows()
        else {
            return
        }
                
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0

        for row in visibleRange {
            var rowAttrs: [UICollectionViewLayoutAttributes] = []
            xOffset = 0

            for col in row == 0 ? 0..<columnsCount(in: row) : 0..<stickyColumnsCount {
                let itemSize = size(forRow: row, column: col)
                let indexPath = IndexPath(row: row, column: col)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemSize.width, height: itemSize.height).integral

                rowAttrs.append(attributes)

                xOffset += itemSize.width
            }

            yOffset = height + height * CGFloat(row)
            
            for column in 0..<stickyColumnsCount {
                if allAttributes.indices.contains(row) && allAttributes[row].indices.contains(column) {
                    allAttributes[row][column] = rowAttrs[column]
                } else {
                    resetLayout()
                    break
                }
            }
        }
    }

    private func updateStickyItemsPositions() {
        guard
            let collectionView = collectionView,
            let currentRange = visibleRange(minimum: stickyRowsCount),
            let cellHeight = delegate?.heightForRows()
        else {
            return
        }

        // Set frames of sticky rows
        for row in 0..<stickyRowsCount {
            for col in 0..<columnsCount(in: row) {
                guard allAttributes.indices.contains(row) && allAttributes[row].indices.contains(col) else {
                    resetLayout()
                    break
                }
                
                let attributes = allAttributes[row][col]
                
                var frame = attributes.frame
                frame.origin.y = collectionView.contentOffset.y + cellHeight * CGFloat(row)

                // Fixed position cells
                if col < stickyColumnsCount {
                    frame.origin.x = collectionView.contentOffset.x + offsetLeft(forRow: row, column: col)
                }
                
                attributes.frame = frame
                attributes.zIndex = zIndex(forRow: row, column: col)
            }
        }

        // Set frames of sticky columns
        for row in currentRange {
            for col in 0..<stickyColumnsCount {
                let attributes = allAttributes[row][col]
                
                var frame = attributes.frame
                frame.origin.x += collectionView.contentOffset.x
                attributes.frame = frame
                
                attributes.zIndex = zIndex(forRow: row, column: col)
            }
        }
    }
    
    private func visibleRange(minimum: Int = 0) -> Range<Int>? {
        guard
            let collectionView = collectionView,
            let cellHeight = delegate?.heightForRows()
        else {
            return nil
        }
            
        let srollViewOffset = collectionView.contentOffset.y
        let collectionViewHeight = collectionView.frame.height
        
        if collectionViewHeight <= Double(Int.min) || collectionViewHeight > Double(Int.max) {
            return nil
        }

        let lowerIndex = (Int((srollViewOffset / cellHeight).rounded(.down))).clamped(to: 0...rowsCount)
        let count = Int((collectionViewHeight / cellHeight).rounded(.up)).clamped(to: 0...rowsCount)
        let upperIndex = lowerIndex + count + 1 // Padding
    
        let lowerBound = max(minimum, lowerIndex)
        let upperBound = min(upperIndex, collectionView.numberOfSections)
        
        if lowerBound > upperBound {
            return nil
        }
        
        return lowerBound..<upperBound
    }

    private func offsetLeft(forRow row: Int, column: Int) -> CGFloat {
        var offsetLeft: CGFloat = 0
        for col in 0..<column {
            offsetLeft += size(forRow: row, column: col).width
        }
        return offsetLeft
    }
    
	private func zIndex(forRow row: Int, column col: Int) -> Int {
		if row < stickyRowsCount && col < stickyColumnsCount {
			return ZOrder.staticStickyItem
		} else if row < stickyRowsCount || col < stickyColumnsCount {
			return ZOrder.stickyItem
		} else {
			return ZOrder.commonItem
		}
	}

	// MARK: - Sizing

	private var rowsCount: Int {
		return collectionView!.numberOfSections
	}

	private func columnsCount(in row: Int) -> Int {
		return collectionView!.numberOfItems(inSection: row)
	}

	private func size(forRow row: Int, column: Int) -> CGSize {
		guard let delegate = collectionView?.delegate as? UICollectionViewDelegateFlowLayout,
			let size = delegate.collectionView?(collectionView!, layout: self, sizeForItemAt: IndexPath(row: row, column: column)) else {
			assertionFailure("Implement collectionView(_,layout:,sizeForItemAt: in UICollectionViewDelegateFlowLayout")
			return .zero
		}

		return size
	}
}

// MARK: - IndexPath

private extension IndexPath {
	init(row: Int, column: Int) {
		self = IndexPath(item: column, section: row)
	}
}

// MARK: - ZOrder

private enum ZOrder {
	static let commonItem = 0
	static let stickyItem = 1
	static let staticStickyItem = 2
}

// MARK: - Comparable

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
