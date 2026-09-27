//
//  ShadowLabel.h
//  ManicEmu
//
//  Created by Daiuno on 2025/10/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for ShadowLabel.
FOUNDATION_EXPORT double ShadowLabelVersionNumber;

//! Project version string for ShadowLabel.
FOUNDATION_EXPORT const unsigned char ShadowLabelVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ShadowLabel/PublicHeader.h>


typedef NS_ENUM(NSInteger, ShadowLabelStrokePosition) {
    ShadowLabelStrokePositionOutside,
    ShadowLabelStrokePositionCenter,
    ShadowLabelStrokePositionInside
};

typedef NS_OPTIONS(NSUInteger, ShadowLabelFadeTruncatingMode) {
    ShadowLabelFadeTruncatingModeNone = 0,
    ShadowLabelFadeTruncatingModeTail = 1 << 0,
    ShadowLabelFadeTruncatingModeHead = 1 << 1,
    ShadowLabelFadeTruncatingModeHeadAndTail = ShadowLabelFadeTruncatingModeHead | ShadowLabelFadeTruncatingModeTail
};

@interface ShadowLabel : UILabel

@property (nonatomic, assign) CGFloat letterSpacing;
@property (nonatomic, assign) CGFloat lineSpacing;

@property (nonatomic, assign) CGFloat shadowBlur;

@property (nonatomic, assign) CGFloat innerShadowBlur;
@property (nonatomic, assign) CGSize innerShadowOffset;
@property (nonatomic, strong) UIColor *innerShadowColor;

@property (nonatomic, assign) CGFloat strokeSize;
@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) ShadowLabelStrokePosition strokePosition;

@property (nonatomic, strong) UIColor *gradientStartColor;
@property (nonatomic, strong) UIColor *gradientEndColor;
@property (nonatomic, copy) NSArray *gradientColors;
@property (nonatomic, assign) CGPoint gradientStartPoint;
@property (nonatomic, assign) CGPoint gradientEndPoint;

@property (nonatomic, assign) ShadowLabelFadeTruncatingMode fadeTruncatingMode;

@property (nonatomic, assign) UIEdgeInsets textInsets;
@property (nonatomic, assign) BOOL automaticallyAdjustTextInsets;

@end
