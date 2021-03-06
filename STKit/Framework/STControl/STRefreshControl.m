//
//  STRefreshControl.m
//  STKit
//
//  Created by SunJiangting on 14-9-17.
//  Copyright (c) 2014年 SunJiangting. All rights reserved.
//

#import "STRefreshControl.h"
#import "STResourceManager.h"

#pragma mark - STRefhresControl
@interface STRefreshControl () {
}

@property(nonatomic, assign) CGFloat contentInsetTop;

@property(nonatomic, assign) STRefreshControlState refreshControlState;

@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, strong) NSDate     *startLoadingDate;

@end

@implementation STRefreshControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.animationDuration = 0.25;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.hidden = !enabled;
}

- (void)beginRefreshing {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _changedRefreshControlToState:STRefreshControlStateLoading animated:YES];
    });
}

- (void)endRefreshing {
    NSTimeInterval duration = self.minimumLoadingDuration;
    if (self.startLoadingDate) {
        duration = [[NSDate date] timeIntervalSinceDate:self.startLoadingDate];
    }
    CGFloat delay = MAX(0, self.minimumLoadingDuration - duration);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       [self _changedRefreshControlToState:STRefreshControlStateNormal animated:YES];
    });
}

- (void)refreshControlWillChangedToState:(STRefreshControlState)refreshControlState {
    
}
- (void)refreshControlDidChangedToState:(STRefreshControlState)refreshControlState {
    
}

- (void)_changedRefreshControlToState:(STRefreshControlState)refreshControlState animated:(BOOL)animated {
    if (_refreshControlState != STRefreshControlStateLoading) {
        /// 如果不是刷新状态，则一定读取到正确的contentInset
        self.contentInsetTop = self.scrollView.contentInset.top;
    }
    if (_refreshControlState == refreshControlState) {
        return;
    }
    __weak UIScrollView *scrollView = self.scrollView;
    void (^animations)(void) = ^{
        CGFloat height = CGRectGetHeight(self.frame);
        UIEdgeInsets inset = scrollView.contentInset;
        if (refreshControlState == STRefreshControlStateLoading) {
            inset.top = self.contentInsetTop + height;
            scrollView.contentOffset = CGPointMake(0, -inset.top);
        } else {
            inset.top = self.contentInsetTop;
        }
        scrollView.contentInset = inset;
        [self refreshControlWillChangedToState:refreshControlState];
    };
    _refreshControlState = refreshControlState;
    void (^completion)(BOOL) = ^(BOOL finished) {
        if (refreshControlState == STRefreshControlStateLoading) {
            [self sendActionsForControlEvents:UIControlEventValueChanged];
            self.startLoadingDate = [NSDate date];
        }
        [self refreshControlDidChangedToState:refreshControlState];
    };
    if (animated) {
        [UIView animateWithDuration:self.animationDuration
                         animations:animations
                         completion:completion];
    } else {
        animations();
        completion(YES);
    }
}

- (BOOL)isRefreshing {
    return _refreshControlState == STRefreshControlStateLoading;
}

- (void)scrollViewDidChangeContentOffset:(CGPoint)contentOffset {
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat contentOffsetY = scrollView.contentOffset.y;
    CGFloat absOffsetY = ABS(contentOffsetY);
    if (contentOffsetY < 0 &&
        self.refreshControlState != STRefreshControlStateLoading &&
        !self.hidden && self.enabled == YES) {
        /// 触发下拉刷新
        CGFloat pullDistance = absOffsetY - self.contentInsetTop;
        if (self.scrollView.dragging) {
            if (pullDistance >= self.threshold) {
                /// 松开可以刷新
                [self _changedRefreshControlToState:STRefreshControlStateReachedThreshold animated:YES];
            } else {
                /// 下拉可以刷新
                [self _changedRefreshControlToState:STRefreshControlStateNormal
                                           animated:YES];
            }
        } else {
            if (self.refreshControlState == STRefreshControlStateReachedThreshold) {
                /// 如果状态为松开可以刷新，并且手松开了，则直接刷新
                [self _changedRefreshControlToState:STRefreshControlStateLoading animated:YES];
            }
        }
        [self scrollViewDidChangeContentOffset:CGPointMake(scrollView.contentOffset.x, -pullDistance)];
    }
}

- (CGFloat)threshold {
    if (_threshold == 0) {
        return CGRectGetHeight(self.bounds);
    }
    return _threshold;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if ([newSuperview isKindOfClass:[UIScrollView class]]) {
        self.scrollView = (UIScrollView *)newSuperview;
    } else {
        self.scrollView = nil;
    }
    self.frame = CGRectMake(0, -CGRectGetHeight(self.bounds), CGRectGetWidth(newSuperview.bounds), CGRectGetHeight(self.bounds));
    [self _changedRefreshControlToState:STRefreshControlStateNormal animated:NO];
    [super willMoveToSuperview:newSuperview];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    static BOOL hasSet = NO;
    if (!hasSet) {
        self.contentInsetTop = self.scrollView.contentInset.top;
        hasSet = YES;
    }
}

- (void)setScrollView:(UIScrollView *)scrollView {
    if (_scrollView) {
        [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:NULL];
    }
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
    _scrollView = scrollView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == self.scrollView && [keyPath isEqualToString:@"contentOffset"]) {
        if (self.enabled && CGRectGetHeight(self.frame) > 20 &&
            self.threshold > 20 && !self.hidden) {
            [self scrollViewDidScroll:self.scrollView];
        }
    }
}

@end

@implementation STDefaultRefreshControl {
    NSMutableDictionary *_titles;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (frame.size.width < STRefreshControlSize.width) {
        frame.size.width = STRefreshControlSize.width;
    }
    if (frame.size.height < STRefreshControlSize.height) {
        frame.size.height = STRefreshControlSize.height;
    }
    self = [super initWithFrame:frame];
    if (self) {
        _titles = [NSMutableDictionary dictionaryWithCapacity:3];
        [self setTitle:@"下拉可以刷新" forState:STRefreshControlStateNormal];
        [self setTitle:@"正在刷新" forState:STRefreshControlStateLoading];
        [self setTitle:@"松开开始刷新" forState:STRefreshControlStateReachedThreshold];
        self.threshold = STRefreshControlSize.height + 10;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        CGFloat width = CGRectGetWidth(frame), height = CGRectGetHeight(frame);
        self.backgroundColor = [UIColor clearColor];
        {
            UILabel *refreshStatusLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, 20)];
            refreshStatusLabel.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
            refreshStatusLabel.backgroundColor = [UIColor clearColor];
            refreshStatusLabel.font = [UIFont systemFontOfSize:13.];
            refreshStatusLabel.textAlignment = NSTextAlignmentCenter;
            [self addSubview:refreshStatusLabel];
            self.refreshStatusLabel = refreshStatusLabel;
            
            UILabel *refreshTimeLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 30, width, 20)];
            refreshTimeLabel.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleBottomMargin;
            refreshTimeLabel.backgroundColor = [UIColor clearColor];
            refreshTimeLabel.font = [UIFont systemFontOfSize:12.];
            refreshTimeLabel.textAlignment = NSTextAlignmentCenter;
            [self addSubview:refreshTimeLabel];
            self.refreshTimeLabel = refreshTimeLabel;
            
            /// 30 * 80 px
            UIImageView *arrawImageView = [[UIImageView alloc]
                                           initWithImage:
                                           [STResourceManager
                                            imageWithResourceID:STImageResourceRefreshControlArrowID]];
            arrawImageView.frame = CGRectMake(60, (height - 40) / 2, 15, 40);
            arrawImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleBottomMargin;
            [self addSubview:arrawImageView];
            self.arrowImageView = arrawImageView;
            
            UIActivityIndicatorView *activityIndicatorView =
            [[UIActivityIndicatorView alloc]
             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            activityIndicatorView.hidesWhenStopped = YES;
            activityIndicatorView.center = arrawImageView.center;
            activityIndicatorView.autoresizingMask = arrawImageView.autoresizingMask;
            [self addSubview:activityIndicatorView];
            self.indicatorView = activityIndicatorView;
            
            self.refreshTime = nil;
        }
        self.enabled = YES;
    }
    return self;
}

- (void)setRefreshTime:(NSDate *)refreshTime {
    _refreshTime = refreshTime;
    if (refreshTime) {
        [[NSUserDefaults standardUserDefaults] setValue:refreshTime
                                                 forKey:@"STRefreshTimeKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if (!refreshTime) {
        refreshTime =
        [[NSUserDefaults standardUserDefaults] valueForKey:@"STRefreshTimeKey"];
        if (![refreshTime isKindOfClass:[NSDate class]]) {
            refreshTime = nil;
        }
    }
    if (!refreshTime) {
        return;
    }
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |
    NSDayCalendarUnit | NSHourCalendarUnit |
    NSMinuteCalendarUnit;
    NSDateComponents *cmp1 = [calendar components:unitFlags fromDate:refreshTime];
    NSDateComponents *cmp2 =
    [calendar components:unitFlags fromDate:[NSDate date]];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if ([cmp1 day] == [cmp2 day]) { // 今天
        formatter.dateFormat = @"今天 HH:mm";
    } else if ([cmp1 year] == [cmp2 year]) { // 今年
        formatter.dateFormat = @"MM-dd HH:mm";
    } else {
        formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    }
    NSString *time = [formatter stringFromDate:refreshTime];
    self.refreshTimeLabel.text =
    [NSString stringWithFormat:@"最后更新：%@", time];
}

#pragma mark - PrivateMethod
- (void)refreshControlWillChangedToState:(STRefreshControlState)refreshControlState {
    BOOL shouldAnimating = NO;
    switch (refreshControlState) {
        case STRefreshControlStateReachedThreshold:
            shouldAnimating = NO;
            self.arrowImageView.hidden = NO;
            self.arrowImageView.transform = CGAffineTransformMakeRotation(M_PI);
            break;
        case STRefreshControlStateLoading:
            self.arrowImageView.hidden = YES;
            shouldAnimating = YES;
            break;
        case STRefreshControlStateNormal:
        default:
            shouldAnimating = NO;
            self.arrowImageView.hidden = NO;
            self.arrowImageView.transform = CGAffineTransformIdentity;
            [self setRefreshTime:[NSDate date]];
            break;
    }
    self.refreshStatusLabel.text = [self titleForState:refreshControlState];
    if (shouldAnimating && ![self.indicatorView isAnimating]) {
        [self.indicatorView startAnimating];
    }
    if (!shouldAnimating && [self.indicatorView isAnimating]) {
        [self.indicatorView stopAnimating];
    }
}

- (void)setTitle:(NSString *)title forState:(STRefreshControlState)state {
    NSString *key = [NSString stringWithFormat:@"%ld", (long)state];
    _titles[key] = title;
}

- (NSString *)titleForState:(STRefreshControlState)state {
    NSString *key = [NSString stringWithFormat:@"%ld", (long)state];
    return _titles[key];
}

@end

CGSize const STRefreshControlSize = {200, 60};
