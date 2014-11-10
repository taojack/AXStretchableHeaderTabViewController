//
//  AXStretchableHeaderTabViewController.m
//  Pods
//

#import "AXStretchableHeaderTabViewController.h"

static NSString * const AXStretchableHeaderTabViewControllerSelectedIndexKey = @"selectedIndex";
static int kNavigationToolbar = 44;

typedef void(^SingleLevelScrollView)(UIScrollView* scrollView);
typedef void(^MultiLevelScrollView)(UIScrollView* firstLevelScrollView, UIScrollView* secondLevelScrollView);
typedef void(^NoScrollView)();

@interface AXStretchableHeaderTabViewController ()

@end

@implementation AXStretchableHeaderTabViewController {
  CGFloat _headerViewTopConstraintConstant;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Custom initialization
        _shouldBounceHeaderView = YES;
        
        _tabBar = [[AXTabBar alloc] init];
        [_tabBar setDelegate:self];
        
        UINib *nib = [UINib nibWithNibName:NSStringFromClass([AXStretchableHeaderTabViewController class]) bundle:nil];
        UIView *subView = [[nib instantiateWithOwner:self options:nil] objectAtIndex:0];
        
        self.view = subView;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  // MEMO:
  // An inherited class does not load xib file.
  // So, this code assigns class name of AXStretchableHeaderTabViewController clearly.
  self = [super initWithNibName:NSStringFromClass([AXStretchableHeaderTabViewController class]) bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
    _shouldBounceHeaderView = YES;

    _tabBar = [[AXTabBar alloc] init];
    [_tabBar setDelegate:self];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [_tabBar sizeToFit];
  [self.view addSubview:_tabBar];

}

- (void)dealloc
{
  [_viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
    UIScrollView *scrollView = [self scrollViewWithSubViewController:viewController];
    if (scrollView) {
      [scrollView removeObserver:self forKeyPath:@"contentOffset"];
    }
      
    UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:viewController];
    if (secondLevelScrollView) {
        [secondLevelScrollView removeObserver:self forKeyPath:@"contentOffset"];
    }

    [viewController removeFromParentViewController];
  }];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
    
  //Animation when switch headerview should not reload (currently being use in change question)
  if (_headerView.frame.origin.x != 320 && _headerView.frame.origin.x != -320) {
  
    _headerView.topConstraint.constant = _headerViewTopConstraintConstant + _containerView.contentInset.top;
    [_headerView setFrame:(CGRect){
      0.0, 0.0,
      CGRectGetWidth(self.view.bounds), _headerView.maximumOfHeight + _containerView.contentInset.top
    }];

    [self layoutHeaderViewAndTabBar];
    [self layoutViewControllers];

  }
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Property

- (UIViewController *)selectedViewController
{
  return _viewControllers[_selectedIndex];
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
  NSInteger newIndex = [_viewControllers indexOfObject:selectedViewController];
  if (newIndex == NSNotFound) {
    return;
  }
  if (newIndex != _selectedIndex) {
    [self changeSelectedIndex:newIndex];
  }
}

- (void)setHeaderView:(AXStretchableHeaderView *)headerView
{
  if (_headerView != headerView) {
    [_headerView removeFromSuperview];
    _headerView = headerView;
    _headerViewTopConstraintConstant = _headerView.topConstraint.constant;
    [self.view addSubview:_headerView];
  }
}

- (void)setViewControllers:(NSArray *)viewControllers
{
  if ([_viewControllers isEqualToArray:viewControllers] == NO) {
    // Load nib file, if self.view is nil.
    [self view];
    
    // Remove views in old view controllers
    [_viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
      [viewController.view removeFromSuperview];
      UIScrollView *scrollView = [self scrollViewWithSubViewController:viewController];
      if (scrollView) {
        [scrollView removeObserver:self forKeyPath:@"contentOffset"];
      }
      UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:viewController];
      if (secondLevelScrollView) {
          [secondLevelScrollView removeObserver:self forKeyPath:@"contentOffset"];
      }
      [viewController removeFromParentViewController];
    }];
    
    // Assign new view controllers
    _viewControllers = [viewControllers copy];
    
    // Add views in new view controllers
    NSMutableArray *tabItems = [NSMutableArray array];
    [_viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
      [_containerView addSubview:viewController.view];
      UIScrollView *scrollView = [self scrollViewWithSubViewController:viewController];
      if (scrollView) {
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
      }
      UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:viewController];
      if (secondLevelScrollView) {
        [secondLevelScrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
      }
      [self addChildViewController:viewController];
      [tabItems addObject:viewController.tabBarItem];
    }];
    [_tabBar setItems:tabItems];
    
    [self layoutViewControllers];
    
    // tab bar
    [_tabBar setSelectedItem:[_tabBar.items firstObject]];
    if (_selectedIndex != 0) {
      [self changeSelectedIndex:0];
    }
  }
}

#pragma mark - Layout

- (void)layoutHeaderViewAndTabBar
{
  UIViewController *selectedViewController = self.selectedViewController;
  
  // Get selected scroll view.
  UIScrollView *scrollView = [self scrollViewWithSubViewController:selectedViewController];
  UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:selectedViewController];

  if (secondLevelScrollView) {
      scrollView = [self currentScrollViewWithMultiLevelViewController:selectedViewController];
  }
  if (scrollView) {
    // Set header view frame
    CGFloat headerViewHeight = _headerView.maximumOfHeight - (scrollView.contentOffset.y + scrollView.contentInset.top);
    headerViewHeight = MAX(headerViewHeight, _headerView.minimumOfHeight);
    if (_headerView.bounces == NO) {
      headerViewHeight = MIN(headerViewHeight, _headerView.maximumOfHeight);
    }
    [_headerView setFrame:(CGRect){
      _headerView.frame.origin,
      CGRectGetWidth(_headerView.frame), headerViewHeight + _containerView.contentInset.top
    }];
    
    // Set scroll view indicator insets
    [scrollView setScrollIndicatorInsets:
     UIEdgeInsetsMake(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top, 0.0, scrollView.contentInset.bottom, 0.0)];
  } else {
    // Set header view frame
    [_headerView setFrame:(CGRect){
      _headerView.frame.origin,
      CGRectGetWidth(_headerView.frame), _headerView.maximumOfHeight + _containerView.contentInset.top
    }];
  }
  
  // Tab bar
  CGFloat tabBarY =
  (_headerView ?
   CGRectGetMaxY(_headerView.frame) :
   _containerView.contentInset.top
   );
  [_tabBar setFrame:(CGRect){
    0.0, tabBarY,
    _tabBar.frame.size
  }];
    
  if (secondLevelScrollView) {
      [((UINavigationController*)[selectedViewController childViewControllers][0]).navigationBar setFrame:CGRectMake(0, tabBarY + _tabBar.frame.size.height - kNavigationToolbar, 320, kNavigationToolbar)];
  }
  
}

- (void)layoutChangeNavigation
{
    UIViewController *selectedViewController = [self selectedViewController];
    UIScrollView *firstLevelScrollView = [self scrollViewWithSubViewController:selectedViewController];
    if (!firstLevelScrollView) {
        return;
    }
    UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:selectedViewController];

    UIScrollView *currentSelectedScrollView = [self currentScrollViewWithMultiLevelViewController:selectedViewController];
    
    // Define relative y calculator
    CGFloat (^calcRelativeY)(CGFloat contentOffsetY, CGFloat contentInsetTop) = ^CGFloat(CGFloat contentOffsetY, CGFloat contentInsetTop) {
        return _headerView.maximumOfHeight - _headerView.minimumOfHeight - (contentOffsetY + contentInsetTop);
    };
    
    CGFloat relativePositionY = calcRelativeY(currentSelectedScrollView.contentOffset.y, currentSelectedScrollView.contentInset.top);
    if (relativePositionY > 0) {
        if (currentSelectedScrollView == firstLevelScrollView) {
            [secondLevelScrollView setContentOffset:(CGPoint) {currentSelectedScrollView.contentOffset.x, currentSelectedScrollView.contentOffset.y}];
        } else {
            [firstLevelScrollView setContentOffset:(CGPoint) {currentSelectedScrollView.contentOffset.x, currentSelectedScrollView.contentOffset.y + kNavigationToolbar}];
        }
    } else {
        CGFloat targetRelativePositionY = 0.0;
        if (currentSelectedScrollView == firstLevelScrollView) {
            targetRelativePositionY = calcRelativeY(secondLevelScrollView.contentOffset.y, secondLevelScrollView.contentInset.top);
        } else {
            targetRelativePositionY = calcRelativeY(firstLevelScrollView.contentOffset.y, firstLevelScrollView.contentInset.top);
        }
        if (targetRelativePositionY > 0) {
            if (currentSelectedScrollView == firstLevelScrollView) {
                secondLevelScrollView.contentOffset = (CGPoint){
                    secondLevelScrollView.contentOffset.x,
                    -(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top)
                };
            } else {
                firstLevelScrollView.contentOffset = (CGPoint){
                    firstLevelScrollView.contentOffset.x,
                    -(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top)
                };
            }
        }
    }
    return;
}

- (CGFloat)calculateNewBottomLevelYOffset {
    UIViewController *selectedViewController = [self selectedViewController];
    UIScrollView *firstLevelScrollView = [self scrollViewWithSubViewController:selectedViewController];
    UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:selectedViewController];
    if ([self currentScrollViewWithMultiLevelViewController:selectedViewController] != secondLevelScrollView || !firstLevelScrollView) {
        return 0;
    }
    
    // Define relative y calculator
    CGFloat (^calcRelativeY)(CGFloat contentOffsetY, CGFloat contentInsetTop) = ^CGFloat(CGFloat contentOffsetY, CGFloat contentInsetTop) {
        return _headerView.maximumOfHeight - _headerView.minimumOfHeight - (contentOffsetY + contentInsetTop);
    };
    
    CGFloat relativePositionY = calcRelativeY(secondLevelScrollView.contentOffset.y, secondLevelScrollView.contentInset.top);
    
    if (relativePositionY > 0) {
        return secondLevelScrollView.contentOffset.y;
    } else {
        CGFloat targetRelativePositionY = 0.0;
        targetRelativePositionY = calcRelativeY(firstLevelScrollView.contentOffset.y, firstLevelScrollView.contentInset.top);
        return -(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top);
    }
}


- (void)layoutViewControllers
{
  [self.view layoutSubviews];
  CGSize size = _containerView.bounds.size;
  
  CGFloat headerOffset =
  (_headerView ?
   _headerView.maximumOfHeight :
   0.0
  );
  UIEdgeInsets contentInsets = UIEdgeInsetsMake(headerOffset + CGRectGetHeight(_tabBar.bounds), 0.0, _containerView.contentInset.top, 0.0);
  
  // Resize sub view controllers
  [_viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
    CGRect newFrame = (CGRect){size.width * idx, 0.0, size};
      
    [self setupScrollViewWithSubViewController:viewController singleLevelBlock:^(UIScrollView *scrollView) {
        [viewController.view setFrame:newFrame];
        [scrollView setContentInset:contentInsets];
    } multiLevelBlock:^(UIScrollView *firstLevelScrollView, UIScrollView *secondLevelScrollView) {
        if ([self currentScrollViewWithMultiLevelViewController:viewController] != secondLevelScrollView) {
            [viewController.view setFrame:CGRectMake(newFrame.origin.x, newFrame.origin.y+ kNavigationToolbar, newFrame.size.width, newFrame.size.height)];
        } else {
            [viewController.view setFrame:CGRectMake(newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height)];
        }
        
        [firstLevelScrollView setContentInset:UIEdgeInsetsMake(contentInsets.top, contentInsets.left, contentInsets.bottom + kNavigationToolbar, contentInsets.right)];
        [secondLevelScrollView setContentInset:UIEdgeInsetsMake(contentInsets.top, contentInsets.left, contentInsets.bottom, contentInsets.right)];
    } noScrollViewBlock:^{
        [viewController.view setFrame:UIEdgeInsetsInsetRect(newFrame, contentInsets)];
    }];
  }];
  [_containerView setContentSize:(CGSize){size.width * _viewControllers.count, 0.0}];
}

- (void)layoutSubViewControllerToSelectedViewController
{
  UIViewController *selectedViewController = [self selectedViewController];
  // Define selected scroll view
  UIScrollView *selectedScrollView = [self scrollViewWithSubViewController:selectedViewController];
  if (!selectedScrollView) {
    return;
  }
  UIScrollView *secondLevelSelectedScrollView = [self parentScrollViewWithSubViewController:selectedViewController];
  if (secondLevelSelectedScrollView) {
     selectedScrollView = [self currentScrollViewWithMultiLevelViewController:selectedViewController];
  }
  
  // Define relative y calculator
  CGFloat (^calcRelativeY)(CGFloat contentOffsetY, CGFloat contentInsetTop) = ^CGFloat(CGFloat contentOffsetY, CGFloat contentInsetTop) {
    return _headerView.maximumOfHeight - _headerView.minimumOfHeight - (contentOffsetY + contentInsetTop);
  };
  
  // Adjustment offset or frame for sub views.
  [_viewControllers enumerateObjectsUsingBlock:^(UIViewController *viewController, NSUInteger idx, BOOL *stop) {
    
    UIScrollView *targetScrollView = [self scrollViewWithSubViewController:viewController];
    UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:viewController];
    if (selectedViewController == viewController) {
      return;
    }
      
    if ([targetScrollView isKindOfClass:[UIScrollView class]]) {
      // Scroll view
      // -> Adjust offset
      CGFloat relativePositionY = calcRelativeY(selectedScrollView.contentOffset.y, selectedScrollView.contentInset.top);//headerViewHeight - _headerView.minimumOfHeight;
      if (relativePositionY > 0) {
        // The header view's height is higher than minimum height.
        // -> Adjust same offset.
          [targetScrollView setContentOffset:(CGPoint) {selectedScrollView.contentOffset.x, selectedScrollView.contentOffset.y}];
          if (secondLevelScrollView) {
              [secondLevelScrollView setContentOffset:(CGPoint) {selectedScrollView.contentOffset.x, selectedScrollView.contentOffset.y}];
          }
      } else {
        // The header view height is lower than minimum height.
        // -> Adjust top of scrollview, If target header view's height is higher than minimum height.
        CGFloat targetRelativePositionY = calcRelativeY(targetScrollView.contentOffset.y, targetScrollView.contentInset.top);
        if (targetRelativePositionY > 0) {
          targetScrollView.contentOffset = (CGPoint){
            targetScrollView.contentOffset.x,
            -(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top)
          };
          if (secondLevelScrollView) {
            secondLevelScrollView.contentOffset = (CGPoint){
                secondLevelScrollView.contentOffset.x,
                -(CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top)
            };
          }
        }
      }
    } else {
      // Not scroll view
      // -> Adjust frame to area at the bottom of tab bar.
      CGFloat y = CGRectGetMaxY(_tabBar.frame) - _containerView.contentInset.top;
      [targetScrollView setFrame:(CGRect){
        CGRectGetMinX(targetScrollView.frame), y,
        CGRectGetMinX(targetScrollView.frame), CGRectGetHeight(_containerView.frame) - y
      }];
    }
  }];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  UIViewController *selectedViewController = [self selectedViewController];
  if ([keyPath isEqualToString:@"contentOffset"]) {
    UIScrollView *scrollView = [self scrollViewWithSubViewController:selectedViewController];
    UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:selectedViewController];
    if (secondLevelScrollView) {
        scrollView = [self currentScrollViewWithMultiLevelViewController:selectedViewController];
    }
      
    if (scrollView != object) {
      return;
    }
    [self layoutHeaderViewAndTabBar];
  }
}

#pragma mark - Scroll view delegate (tab view controllers)

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  [self layoutSubViewControllerToSelectedViewController];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (scrollView.isDragging) {
    NSUInteger numberOfViewControllers = _viewControllers.count;
    NSInteger newSelectedIndex = round(scrollView.contentOffset.x / scrollView.contentSize.width * numberOfViewControllers);
    newSelectedIndex = MIN(numberOfViewControllers - 1, MAX(0, newSelectedIndex));
    if (_selectedIndex != newSelectedIndex) {
      [_tabBar setSelectedItem:_tabBar.items[newSelectedIndex]];
      [self changeSelectedIndex:newSelectedIndex];
    }
  }
}

#pragma mark - Tab bar delegate

- (BOOL)tabBar:(AXTabBar *)tabBar shouldSelectItem:(UITabBarItem *)item
{
  [self layoutSubViewControllerToSelectedViewController];
  return YES;
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
  NSInteger newSelectedIndex = [[tabBar items] indexOfObject:item];
  if (_selectedIndex != newSelectedIndex) {
    [_containerView setContentOffset:(CGPoint){newSelectedIndex * CGRectGetWidth(_containerView.bounds), _containerView.contentOffset.y} animated:YES];
    [self changeSelectedIndex:newSelectedIndex];
  }
}

#pragma mark - Private Method

- (UIScrollView *)scrollViewWithSubViewController:(UIViewController *)viewController
{
  if ([viewController respondsToSelector:@selector(stretchableSubViewInSubViewController:)]) {
      return [(id<AXStretchableSubViewControllerViewSource>)viewController stretchableSubViewInSubViewController:viewController];
  } else if ([viewController.view isKindOfClass:[UIScrollView class]]) {
    return (id)viewController.view;
  } else {
    return nil;
  }
}

- (UIScrollView *)parentScrollViewWithSubViewController:(UIViewController *)viewController
{
    if ([viewController respondsToSelector:@selector(stretchableParentViewInSubViewController:)]) {
        return [(id<AXStretchableSubViewControllerViewSource>)viewController stretchableParentViewInSubViewController:viewController];
    } else {
        return nil;
    }
}

- (UIScrollView *)currentScrollViewWithMultiLevelViewController:(UIViewController *)viewController
{
    if ([viewController respondsToSelector:@selector(currentNavigationView:)]) {
        return [(id<AXStretchableSubViewControllerViewSource>)viewController currentNavigationView:viewController];
    } else {
        return nil;
    }
}

- (void)changeSelectedIndex:(NSInteger)selectedIndex
{
  [self willChangeValueForKey:@"selectedIndex"];
  [self willChangeValueForKey:@"selectedViewController"];
  _selectedIndex = selectedIndex;
  [self layoutHeaderViewAndTabBar];
  [self layoutViewControllers];
  [self didChangeValueForKey:@"selectedIndex"];
  [self didChangeValueForKey:@"selectedViewController"];
}

- (void)setupScrollViewWithSubViewController:(UIViewController*)viewController singleLevelBlock:(SingleLevelScrollView)singleLevelBlock multiLevelBlock:(MultiLevelScrollView)multiLevelBlock noScrollViewBlock:(NoScrollView)noScrollViewBlock {
    UIScrollView *firstLevelScrollView = [self scrollViewWithSubViewController:viewController];
    if (firstLevelScrollView) {
        UIScrollView *secondLevelScrollView = [self parentScrollViewWithSubViewController:viewController];
        if (secondLevelScrollView) {
            if (multiLevelBlock) multiLevelBlock(firstLevelScrollView, secondLevelScrollView);
        } else {
            if (singleLevelBlock) singleLevelBlock(firstLevelScrollView);
        }
    } else {
        if (noScrollViewBlock) noScrollViewBlock();
    }
}

@end
