//
//  RMMapContents.m
//
// Copyright (c) 2008-2009, Route-Me Contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
#import "RMGlobalConstants.h"
#import "RMMapContents.h"

#import "RMMapView.h"

#import "RMFoundation.h"
#import "RMProjection.h"
#import "RMMercatorToScreenProjection.h"
#import "RMMercatorToTileProjection.h"

#import "RMTileSource.h"
#import "RMTileLoader.h"
#import "RMTileImageSet.h"

#import "RMOpenStreetMapSource.h"
#import "RMCoreAnimationRenderer.h"
#import "RMCachedTileSource.h"

#import "RMLayerCollection.h"
#import "RMMarkerManager.h"

#import "RMMarker.h"

#import "MapView_Prefix.pch"




@interface RMMapContents (PrivateMethods)
- (void)animatedZoomStep:(NSTimer *)timer;
@end

@implementation RMMapContents (Internal)
	BOOL delegateHasRegionUpdate;
@end

@implementation RMMapContents

@synthesize boundingMask;
@synthesize minZoom;
@synthesize maxZoom;
@synthesize screenScale;
@synthesize markerManager;

#pragma mark --- begin constants ----
#define kZoomAnimationStepTime 0.03f
#define kZoomAnimationAnimationTime 0.1f
#define kiPhoneMilimeteresPerPixel .1543
#define kZoomRectPixelBuffer 50
#pragma mark --- end constants ----

#pragma mark Initialisation

- (id)initWithView: (UIView*) view
{	
	LogMethod();
	CLLocationCoordinate2D here;
	here.latitude = kDefaultInitialLatitude;
	here.longitude = kDefaultInitialLongitude;
	
	return [self initWithView:view
				   tilesource:[[RMOpenStreetMapSource alloc] init]
				 centerLatLon:here
	  			    zoomLevel:kDefaultInitialZoomLevel
				 maxZoomLevel:kDefaultMaximumZoomLevel
				 minZoomLevel:kDefaultMinimumZoomLevel
			  backgroundImage:nil
                  screenScale:0];
}

- (id)initWithView: (UIView*) view screenScale:(float)theScreenScale {
    LogMethod();
	CLLocationCoordinate2D here;
	here.latitude = kDefaultInitialLatitude;
	here.longitude = kDefaultInitialLongitude;
	
	return [self initWithView:view
				   tilesource:[[RMOpenStreetMapSource alloc] init]
				 centerLatLon:here
	  			    zoomLevel:kDefaultInitialZoomLevel
				 maxZoomLevel:kDefaultMaximumZoomLevel
				 minZoomLevel:kDefaultMinimumZoomLevel
			  backgroundImage:nil
                  screenScale:theScreenScale];
}

- (id)initWithView: (UIView*) view
		tilesource:(id<RMTileSource>)newTilesource
{
    return [self initWithView:view tilesource:newTilesource screenScale:0.0];
}

-(id)initWithView:(UIView *)view tilesource:(id<RMTileSource>)newTilesource screenScale:(float)theScreenScale
{	
	LogMethod();
    
    float maximumZoomLevel=[newTilesource numberZoomLevels];

	CLLocationCoordinate2D here;
	here.latitude = kDefaultInitialLatitude;
	here.longitude = kDefaultInitialLongitude;
       	return [self initWithView:view
				   tilesource:newTilesource
				 centerLatLon:here
					zoomLevel:kDefaultInitialZoomLevel
				 maxZoomLevel:maximumZoomLevel
				 minZoomLevel:kDefaultMinimumZoomLevel
			  backgroundImage:nil
                  screenScale:theScreenScale];
}

- (id)initWithView:(UIView*)newView
		tilesource:(id<RMTileSource>)newTilesource
	  centerLatLon:(CLLocationCoordinate2D)initialCenter  ///地图的中心点
		 zoomLevel:(float)initialZoomLevel                ///地图初始化时的缩放级别
	  maxZoomLevel:(float)maxZoomLevel
	  minZoomLevel:(float)minZoomLevel
   backgroundImage:(UIImage *)backgroundImage
       screenScale:(float)theScreenScale                  ///设备的屏幕分辨率的属性值
{
	LogMethod();
	if (![super init])
		return nil;

	NSAssert1([newView isKindOfClass:[RMMapView class]], @"view %@ must be a subclass of RMMapView", newView);
	[(RMMapView *)newView setContents:self];

	tileSource = nil;
	projection = nil;
	mercatorToTileProjection = nil;
	renderer = nil;
	imagesOnScreen = nil;
	tileLoader = nil;
    
    screenScale = (theScreenScale == 0.0 ? 1.0 : theScreenScale);

	boundingMask = RMMapMinWidthBound;

	mercatorToScreenProjection = [[RMMercatorToScreenProjection alloc] initFromProjection:[newTilesource projection] ToScreenBounds:[newView bounds]];
	
	layer = [[newView layer] retain];

        [self setMinZoom:minZoomLevel];
        [self setMaxZoom:maxZoomLevel];

	[self setTileSource:newTilesource];
	[self setRenderer: [[[RMCoreAnimationRenderer alloc] initWithContent:self] autorelease]];
	
    
    
	imagesOnScreen = [[RMTileImageSet alloc] initWithDelegate:renderer];
	[imagesOnScreen setTileSource:tileSource];

	tileLoader = [[RMTileLoader alloc] initWithContent:self];
	[tileLoader setSuppressLoading:YES];

	[self setZoom:initialZoomLevel];

	[self moveToLatLong:initialCenter];
	
	[tileLoader setSuppressLoading:NO];
	
	/// \bug TODO: Make a nice background class
	RMMapLayer *theBackground = [[RMMapLayer alloc] init];
	[self setBackground:theBackground];
	[theBackground release];
	
	RMLayerCollection *theOverlay = [[RMLayerCollection alloc] initForContents:self];
	[self setOverlay:theOverlay];
	[theOverlay release];
	
	markerManager = [[RMMarkerManager alloc] initWithContents:self];
	
	[newView setNeedsDisplay];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMemoryWarningNotification:) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];

	
    
	RMLog(@"Map contents initialised. view: %@ tileSource %@ renderer %@", newView, tileSource, renderer);
	return self;
}


/// deprecated at any moment after release 0.5
/// 发布了版本0.5后，此方法会被弃用
- (id) initForView: (UIView*) view
{
	WarnDeprecated();
	return [self initWithView:view];
}

/// 发布了版本0.5后，此方法会被弃用。
- (id) initForView: (UIView*) view WithLocation:(CLLocationCoordinate2D)latlong
{
	WarnDeprecated();
	LogMethod();
	id<RMTileSource> _tileSource = [[RMOpenStreetMapSource alloc] init];
	RMMapRenderer *_renderer = [[RMCoreAnimationRenderer alloc] initWithContent:self];
	
	id mapContents = [self initForView:view WithTileSource:_tileSource WithRenderer:_renderer LookingAt:latlong];
	[_tileSource release];
	[_renderer release];
	
	return mapContents;
}


/// 发布了版本0.5后，此方法会被弃用。
- (id) initForView: (UIView*) view WithTileSource: (id<RMTileSource>)_tileSource WithRenderer: (RMMapRenderer*)_renderer LookingAt:(CLLocationCoordinate2D)latlong
{
	WarnDeprecated();
	LogMethod();
	if (![super init])
		return nil;
	
	NSAssert1([view isKindOfClass:[RMMapView class]], @"view %@ must be a subclass of RMMapView", view);
	
	self.boundingMask = RMMapMinWidthBound;
//	targetView = view;
	mercatorToScreenProjection = [[RMMercatorToScreenProjection alloc] initFromProjection:[_tileSource projection] ToScreenBounds:[view bounds]];

	tileSource = nil;
	projection = nil;
	mercatorToTileProjection = nil;
	
	renderer = nil;
	imagesOnScreen = nil;
	tileLoader = nil;
	
	layer = [[view layer] retain];
	
	[self setTileSource:_tileSource];
	[self setRenderer:_renderer];
	
	imagesOnScreen = [[RMTileImageSet alloc] initWithDelegate:renderer];
	[imagesOnScreen setTileSource:tileSource];

	tileLoader = [[RMTileLoader alloc] initWithContent:self];
	[tileLoader setSuppressLoading:YES];
	
	[self setMinZoom:kDefaultMinimumZoomLevel];
	[self setMaxZoom:kDefaultMaximumZoomLevel];
	[self setZoom:kDefaultInitialZoomLevel];

	[self moveToLatLong:latlong];
	
	[tileLoader setSuppressLoading:NO];
	
	/// \bug TODO: Make a nice background class
	RMMapLayer *theBackground = [[RMMapLayer alloc] init];
	[self setBackground:theBackground];
	[theBackground release];
	
	RMLayerCollection *theOverlay = [[RMLayerCollection alloc] initForContents:self];
	[self setOverlay:theOverlay];
	[theOverlay release];
	
	markerManager = [[RMMarkerManager alloc] initWithContents:self];
	
	[view setNeedsDisplay];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMemoryWarningNotification:) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
	
	RMLog(@"Map contents initialised. view: %@ tileSource %@ renderer %@", view, tileSource, renderer);
	
	return self;
}

- (void)setFrame:(CGRect)frame
{
  CGRect bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
  [mercatorToScreenProjection setScreenBounds:bounds];
  background.frame = bounds;
  layer.frame = frame;
  overlay.frame = bounds;
  [tileLoader clearLoadedBounds];
  [tileLoader updateLoadedImages];
  [renderer setFrame:frame];
  [overlay correctPositionOfAllSublayers];
}

-(void) dealloc
{
	LogMethod();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[imagesOnScreen cancelLoading];
	[self setRenderer:nil];
	[imagesOnScreen release];
	[tileLoader release];
	[projection release];
	[mercatorToTileProjection release];
	[mercatorToScreenProjection release];
	[tileSource release];
	[self setOverlay:nil];
	[self setBackground:nil];
	[layer release];
	[markerManager release];
	[super dealloc];
}

- (void)handleMemoryWarningNotification:(NSNotification *)notification
{
	[self didReceiveMemoryWarning];
}

- (void) didReceiveMemoryWarning
{
	LogMethod();
	[tileSource didReceiveMemoryWarning];
}


#pragma mark Forwarded Events

- (void)moveToLatLong: (CLLocationCoordinate2D)latlong
{
	//RMProjectedPoint aPoint;
    //aPoint.easting = latlong.longitude;
    //aPoint.northing = latlong.latitude;
    RMProjectedPoint aPoint = [[self projection] latLongToPoint:latlong];
    
    
    
	[self moveToProjectedPoint: aPoint];
}
- (void)moveToProjectedPoint: (RMProjectedPoint)aPoint
{
	self.centerProjectedPoint = aPoint;
}

- (void)moveBy: (CGSize) delta
{
	[mercatorToScreenProjection moveScreenBy:delta];
	[imagesOnScreen moveBy:delta];
	[tileLoader moveBy:delta];
	[overlay moveBy:delta];
	[overlay correctPositionOfAllSublayers];
	[renderer setNeedsDisplay];
}

/// \bug doesn't really adjust anything, just makes a computation. CLANG flags some dead assignments (write-only variables)
- (float)adjustZoomForBoundingMask:(float)zoomFactor
{
	if ( boundingMask ==  RMMapNoMinBound )
		return zoomFactor;
	
	double newMPP = self.metersPerPixel / zoomFactor;
	
	RMProjectedRect mercatorBounds = [[tileSource projection] planetBounds];
	
	// Check for MinWidthBound
	if ( boundingMask & RMMapMinWidthBound )
	{
		double newMapContentsWidth = mercatorBounds.size.width / newMPP;
		double screenBoundsWidth = [self screenBounds].size.width;
		double mapContentWidth;
		
		if ( newMapContentsWidth < screenBoundsWidth )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentWidth = mercatorBounds.size.width / self.metersPerPixel;
			zoomFactor = screenBoundsWidth / mapContentWidth;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsWidth = mercatorBounds.size.width / newMPP;
		}
		
	}
	
	// Check for MinHeightBound	
	if ( boundingMask & RMMapMinHeightBound )
	{
		double newMapContentsHeight = mercatorBounds.size.height / newMPP;
		double screenBoundsHeight = [self screenBounds].size.height;
		double mapContentHeight;
		
		if ( newMapContentsHeight < screenBoundsHeight )
		{
			// Calculate new zoom facter so that it does not shrink the map any further. 
			mapContentHeight = mercatorBounds.size.height / self.metersPerPixel;
			zoomFactor = screenBoundsHeight / mapContentHeight;
			
			//newMPP = self.metersPerPixel / zoomFactor;
			//newMapContentsHeight = mercatorBounds.size.height / newMPP;
		}
		
	}
	
	//[self adjustMapPlacementWithScale:newMPP];
	
	return zoomFactor;
}

/// This currently is not called because it does not handle the case when the map is continous or not continous.  At a certain scale
/// you can continuously move to the west or east until you get to a certain scale level that simply shows the entire world.
/// 此方法目前未真正实现
- (void)adjustMapPlacementWithScale:(float)aScale
{
	CGSize		adjustmentDelta = {0.0, 0.0};
	RMLatLong	rightEdgeLatLong = {0, kMaxLong};
	RMLatLong	leftEdgeLatLong = {0,- kMaxLong};
	
	CGPoint		rightEdge = [self latLongToPixel:rightEdgeLatLong withMetersPerPixel:aScale];
	CGPoint		leftEdge = [self latLongToPixel:leftEdgeLatLong withMetersPerPixel:aScale];
	//CGPoint		topEdge = [self latLongToPixel:myLatLong withMetersPerPixel:aScale];
	//CGPoint		bottomEdge = [self latLongToPixel:myLatLong withMetersPerPixel:aScale];
	
	CGRect		containerBounds = [self screenBounds];

	if ( rightEdge.x < containerBounds.size.width ) 
	{
		adjustmentDelta.width = containerBounds.size.width - rightEdge.x;
		[self moveBy:adjustmentDelta];
	}
	
	if ( leftEdge.x > containerBounds.origin.x ) 
	{
		adjustmentDelta.width = containerBounds.origin.x - leftEdge.x;
		[self moveBy:adjustmentDelta];
	}
	
	
}

/// \bug this is a no-op, not a clamp, if new zoom would be outside of minzoom/maxzoom range
- (void)zoomByFactor: (float) zoomFactor near:(CGPoint) pivot
{
	//[self zoomByFactor:zoomFactor near:pivot animated:NO];
	
	zoomFactor = [self adjustZoomForBoundingMask:zoomFactor];
	//RMLog(@"Zoom Factor: %lf for Zoom:%f", zoomFactor, [self zoom]);
	
	// pre-calculate zoom so we can tell if we want to perform it
	float newZoom = [mercatorToTileProjection  
					 calculateZoomFromScale:self.metersPerPixel/zoomFactor];
	
	if ((newZoom > minZoom) && (newZoom < maxZoom))
	{
		[mercatorToScreenProjection zoomScreenByFactor:zoomFactor near:pivot];
		[imagesOnScreen zoomByFactor:zoomFactor near:pivot];
		[tileLoader zoomByFactor:zoomFactor near:pivot];
		[overlay zoomByFactor:zoomFactor near:pivot];
        [overlay correctPositionOfAllSublayers];
		[renderer setNeedsDisplay];
	} 
}


- (void)zoomByFactor: (float) zoomFactor near:(CGPoint) pivot animated:(BOOL) animated
{
	[self zoomByFactor:zoomFactor near:pivot animated:animated withCallback:nil];
}

- (BOOL)shouldZoomToTargetZoom:(float)targetZoom withZoomFactor:(float)zoomFactor {
	//bools for syntactical sugar to understand the logic in the if statement below
	BOOL zoomAtMax = ([self zoom] == [self maxZoom]);
	BOOL zoomAtMin = ([self zoom] == [self minZoom]);
	BOOL zoomGreaterMin = ([self zoom] > [self minZoom]);
	BOOL zoomLessMax = ([self zoom] < [self maxZoom]);
	
	//zooming in zoomFactor > 1
	//zooming out zoomFactor < 1
	
	if ((zoomGreaterMin && zoomLessMax) || (zoomAtMax && zoomFactor<1) || (zoomAtMin && zoomFactor>1))
	{
		return YES;
	}
	else
	{
		return NO;
	} 
}

- (void)zoomByFactor: (float) zoomFactor near:(CGPoint) pivot animated:(BOOL) animated withCallback:(id<RMMapContentsAnimationCallback>)callback
{
	zoomFactor = [self adjustZoomForBoundingMask:zoomFactor];
	float zoomDelta = log2f(zoomFactor);
	float targetZoom = zoomDelta + [self zoom];
	
    //NSLog(@"zoomdelta:%f,zoom:%f,target:%f",zoomDelta,[self zoom],targetZoom);
	if (targetZoom == [self zoom]){
		return;
	}
	// clamp zoom to remain below or equal to maxZoom after zoomAfter will be applied
	// Set targetZoom to maxZoom so the map zooms to its maximum
	if(targetZoom > [self maxZoom]){
		zoomFactor = exp2f([self maxZoom] - [self zoom]);
		targetZoom = [self maxZoom];
	}
    
    //NSLog(@"zoomdelta:%f,zoom:%f,target:%f",zoomDelta,[self zoom],targetZoom);
	
	// clamp zoom to remain above or equal to minZoom after zoomAfter will be applied
	// Set targetZoom to minZoom so the map zooms to its maximum
	if(targetZoom < [self minZoom]){
		zoomFactor = 1/exp2f([self zoom] - [self minZoom]);
		targetZoom = [self minZoom];
	}

    //NSLog(@"zoomdelta:%f,zoom:%f,target:%f",zoomDelta,[self zoom],targetZoom);
    
    if ([self shouldZoomToTargetZoom:targetZoom withZoomFactor:zoomFactor])
    {
        if (animated)
        {
            // goal is to complete the animation in animTime seconds
            double nSteps = round(kZoomAnimationAnimationTime / kZoomAnimationStepTime);
            double zoomIncr = zoomDelta / nSteps;
            
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithDouble:zoomIncr], @"zoomIncr",
                                      [NSNumber numberWithDouble:targetZoom], @"targetZoom",
                                      [NSValue valueWithCGPoint:pivot], @"pivot",
                                      [NSNumber numberWithFloat:zoomFactor], @"factor",
                                      callback, @"callback", nil];
            [NSTimer scheduledTimerWithTimeInterval:kZoomAnimationStepTime
                                             target:self
                                           selector:@selector(animatedZoomStep:)
                                           userInfo:userInfo
                                            repeats:YES];
        }
        else
        {
            [mercatorToScreenProjection zoomScreenByFactor:zoomFactor near:pivot];
            [imagesOnScreen zoomByFactor:zoomFactor near:pivot];
            [tileLoader zoomByFactor:zoomFactor near:pivot];
            [overlay zoomByFactor:zoomFactor near:pivot];
            [overlay correctPositionOfAllSublayers];
            [renderer setNeedsDisplay];
        }
    }
    else
    {
        if([self zoom] > [self maxZoom])
            [self setZoom:[self maxZoom]];
        if([self zoom] < [self minZoom])
            [self setZoom:[self minZoom]];
    }
}

/// \bug magic strings embedded in code
- (void)animatedZoomStep:(NSTimer *)timer
{
	double zoomIncr = [[[timer userInfo] objectForKey:@"zoomIncr"] doubleValue];
	double targetZoom = [[[timer userInfo] objectForKey:@"targetZoom"] doubleValue];
    
	NSDictionary *userInfo = [[[timer userInfo] retain] autorelease];
	id<RMMapContentsAnimationCallback> callback = [userInfo objectForKey:@"callback"];

    //NSLog(@"zoomIncr:%f,zoom:%f,targetzoom:%f\n",zoomIncr,[self zoom],targetZoom);
    
	if ((zoomIncr > 0 && [self zoom] >= targetZoom-1.0e-6) || (zoomIncr < 0 && [self zoom] <= targetZoom+1.0e-6))
	{
        if ( [self zoom] != targetZoom ) [self setZoom:targetZoom];
		[timer invalidate];	// ASAP
		if ([callback respondsToSelector:@selector(animationFinishedWithZoomFactor:near:)])
		{
			[callback animationFinishedWithZoomFactor:[[userInfo objectForKey:@"factor"] floatValue] near:[[userInfo objectForKey:@"pivot"] CGPointValue]];
		}
	}
	else
	{
		float zoomFactorStep = exp2f(zoomIncr);
		[self zoomByFactor:zoomFactorStep near:[[[timer userInfo] objectForKey:@"pivot"] CGPointValue] animated:NO];
		if ([callback respondsToSelector:@selector(animationStepped)])
		{
			[callback animationStepped];
		}
	}
}


- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot
{
	[self zoomInToNextNativeZoomAt:pivot animated:NO];
}

- (float)nextNativeZoomFactor
{
	float newZoom = fmin(floorf([self zoom] + 1.0), [self maxZoom]);
	return exp2f(newZoom - [self zoom]);
}

- (float)prevNativeZoomFactor
{
	float newZoom = fmax(floorf([self zoom] - 1.0), [self minZoom]);
	return exp2f(newZoom - [self zoom]);
}

/// \deprecated appears to be unused
- (void)zoomInToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated
{
	// Calculate rounded zoom
	float newZoom = fmin(floorf([self zoom] + 1.0), [self maxZoom]);
	RMLog(@"[self minZoom] %f [self zoom] %f [self maxZoom] %f newzoom %f", [self minZoom], [self zoom], [self maxZoom], newZoom);
	
	float factor = exp2f(newZoom - [self zoom]);
	[self zoomByFactor:factor near:pivot animated:animated];
}

/// \deprecated appears to be unused except by zoomOutToNextNativeZoomAt:
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot animated:(BOOL) animated {
	// Calculate rounded zoom
	float newZoom = fmax(ceilf([self zoom] - 1.0), [self minZoom]);
	RMLog(@"[self minZoom] %f [self zoom] %f [self maxZoom] %f newzoom %f", [self minZoom], [self zoom], [self maxZoom], newZoom);
	
	float factor = exp2f(newZoom - [self zoom]);
	[self zoomByFactor:factor near:pivot animated:animated];
}

/// \deprecated appears to be unused
- (void)zoomOutToNextNativeZoomAt:(CGPoint) pivot {
	[self zoomOutToNextNativeZoomAt: pivot animated: FALSE];
}
 

- (void) drawRect: (CGRect) aRect
{
	[renderer drawRect:aRect];
}

-(void)removeAllCachedImages
{
	[tileSource removeAllCachedImages];
}


#pragma mark Properties

- (void) setTileSource: (id<RMTileSource>)newTileSource
{
	if (tileSource == newTileSource)
		return;
	
	RMCachedTileSource *newCachedTileSource = [RMCachedTileSource cachedTileSourceWithSource:newTileSource];

	newCachedTileSource = [newCachedTileSource retain];
	[tileSource release];
	tileSource = newCachedTileSource;

        NSAssert(([tileSource minZoom] - minZoom) <= 1.0, @"Graphics & memory are overly taxed if [contents minZoom] is more than 1.5 smaller than [tileSource minZoom]");
	
    
	[projection release];
	projection = [[tileSource projection] retain];
	
	[mercatorToTileProjection release];
	mercatorToTileProjection = [[tileSource mercatorToTileProjection] retain];

	[imagesOnScreen setTileSource:tileSource];

        [tileLoader reset];
	[tileLoader reload];
}

- (id<RMTileSource>) tileSource
{
	return [[tileSource retain] autorelease];
}

- (void) setRenderer: (RMMapRenderer*) newRenderer
{
	if (renderer == newRenderer)
		return;
	
	[imagesOnScreen setDelegate:newRenderer];
	
	[[renderer layer] removeFromSuperlayer];
	[renderer release];
	
	renderer = [newRenderer retain];
	
	if (renderer == nil)
		return;
	
	//	CGRect rect = [self screenBounds];
	//	RMLog(@"%f %f %f %f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
	[[renderer layer] setFrame:[self screenBounds]];
	
	if (background != nil)
		[layer insertSublayer:[renderer layer] above:background];
	else if (overlay != nil)
		[layer insertSublayer:[renderer layer] below:overlay];
	else
		[layer insertSublayer:[renderer layer] atIndex: 0];
}

- (RMMapRenderer *)renderer
{
	return [[renderer retain] autorelease];
}

- (void) setBackground: (RMMapLayer*) aLayer
{
	if (background == aLayer) return;
	
	if (background != nil)
	{
		[background release];
		[background removeFromSuperlayer];		
	}
	
	background = [aLayer retain];
	
	if (background == nil)
		return;
	
	background.frame = [self screenBounds];
	
	if ([renderer layer] != nil)
		[layer insertSublayer:background below:[renderer layer]];
	else if (overlay != nil)
		[layer insertSublayer:background below:overlay];
	else
		[layer insertSublayer:[renderer layer] atIndex: 0];
}

- (RMMapLayer *)background
{
	return [[background retain] autorelease];
}

- (void) setOverlay: (RMLayerCollection*) aLayer
{
	if (overlay == aLayer) return;
	
	if (overlay != nil)
	{
		[overlay release];
		[overlay removeFromSuperlayer];		
	}
	
	overlay = [aLayer retain];
	
	if (overlay == nil)
		return;
	
	overlay.frame = [self screenBounds];
	
	if ([renderer layer] != nil)
		[layer insertSublayer:overlay above:[renderer layer]];
	else if (background != nil)
		[layer insertSublayer:overlay above:background];
	else
		[layer insertSublayer:[renderer layer] atIndex: 0];
	
	/* Test to make sure the overlay is working.
	CALayer *testLayer = [[CALayer alloc] init];
	
	[testLayer setFrame:CGRectMake(100, 100, 200, 200)];
	[testLayer setBackgroundColor:[[UIColor brownColor] CGColor]];
	
	RMLog(@"added test layer");
	[overlay addSublayer:testLayer];*/
}

- (RMLayerCollection *)overlay
{
	return [[overlay retain] autorelease];
}

- (CLLocationCoordinate2D) mapCenter
{
	RMProjectedPoint aPoint = [mercatorToScreenProjection projectedCenter];
	return [projection pointToLatLong:aPoint];
}

-(void) setMapCenter: (CLLocationCoordinate2D) center
{
	[self moveToLatLong:center];
}

- (RMProjectedPoint)centerProjectedPoint
{
	return [mercatorToScreenProjection projectedCenter];
}

- (void)setCenterProjectedPoint:(RMProjectedPoint)projectedPoint
{
	[mercatorToScreenProjection setProjectedCenter:projectedPoint];
	[overlay correctPositionOfAllSublayers];
	[tileLoader reload];
	[renderer setNeedsDisplay];
	[overlay setNeedsDisplay];
}

-(RMProjectedRect) projectedBounds
{
	return [mercatorToScreenProjection projectedBounds];
}
-(void) setProjectedBounds: (RMProjectedRect) boundsRect
{
	[mercatorToScreenProjection setProjectedBounds:boundsRect];
}

-(RMTileRect) tileBounds
{
    return [mercatorToTileProjection projectRect:[mercatorToScreenProjection projectedBounds] 
                                         atScale:[self scaledMetersPerPixel]];
}

-(CGRect) screenBounds
{
	if (mercatorToScreenProjection != nil)
		return [mercatorToScreenProjection screenBounds];
	else
		return CGRectZero;
}

-(float) metersPerPixel
{
	return [mercatorToScreenProjection metersPerPixel];
}

-(void) setMetersPerPixel: (float) newMPP
{
        float zoomFactor = self.metersPerPixel / newMPP;
        CGPoint pivot = CGPointZero;

        [mercatorToScreenProjection setMetersPerPixel:newMPP];
        [imagesOnScreen zoomByFactor:zoomFactor near:pivot];
        [tileLoader zoomByFactor:zoomFactor near:pivot];
        [overlay zoomByFactor:zoomFactor near:pivot];
        [overlay correctPositionOfAllSublayers];
        [renderer setNeedsDisplay];
}

-(float) scaledMetersPerPixel
{
    return [mercatorToScreenProjection metersPerPixel] / screenScale;
}

- (void)setScaledMetersPerPixel:(float)newMPP {
    [self setMetersPerPixel:newMPP * screenScale];
}

-(void)setMaxZoom:(float)newMaxZoom
{
	maxZoom = newMaxZoom;
}

-(void)setMinZoom:(float)newMinZoom
{
	minZoom = newMinZoom;

        NSAssert(!tileSource || (([tileSource minZoom] - minZoom) <= 1.0), @"Graphics & memory are overly taxed if [contents minZoom] is more than 1.5 smaller than [tileSource minZoom]");
}

-(float) zoom
{
        return [mercatorToTileProjection calculateZoomFromScale:[self scaledMetersPerPixel]];
}
/*
-(float) numberZoomLevel
{
   // NSLog(@"OK");
    return [tileSource numberZoomLevel];
}

 */
/// if #zoom is outside of range #minZoom to #maxZoom, zoom level is clamped to that range.
-(void) setZoom: (float) zoom
{
        zoom = (zoom > maxZoom) ? maxZoom : zoom;
        zoom = (zoom < minZoom) ? minZoom : zoom;

        float scale = [mercatorToTileProjection calculateScaleFromZoom:zoom];

        [self setScaledMetersPerPixel:scale];
}

-(RMTileImageSet*) imagesOnScreen
{
	return [[imagesOnScreen retain] autorelease];
}

-(RMTileLoader*) tileLoader
{
	return [[tileLoader retain] autorelease];
}

-(RMProjection*) projection
{
	return [[projection retain] autorelease];
}
-(id<RMMercatorToTileProjection>) mercatorToTileProjection
{
	return [[mercatorToTileProjection retain] autorelease];
}
-(RMMercatorToScreenProjection*) mercatorToScreenProjection
{
	return [[mercatorToScreenProjection retain] autorelease];
}

- (CALayer *)layer
{
	return [[layer retain] autorelease];
}

static BOOL _performExpensiveOperations = YES;
+ (BOOL) performExpensiveOperations
{
	return _performExpensiveOperations;
}
+ (void) setPerformExpensiveOperations: (BOOL)p
{
	if (p == _performExpensiveOperations)
		return;
	
	_performExpensiveOperations = p;

	if (p)
		[[NSNotificationCenter defaultCenter] postNotificationName:RMResumeExpensiveOperations object:self];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:RMSuspendExpensiveOperations object:self];
}

#pragma mark LatLng/Pixel translation functions

- (CGPoint)latLongToPixel:(CLLocationCoordinate2D)latlong
{	
	return [mercatorToScreenProjection projectXYPoint:[projection latLongToPoint:latlong]];
}


- (RMProjectedPoint)latLongToProjectedPoint:(CLLocationCoordinate2D)latlong
{
	return [projection latLongToPoint:latlong];
}

- (CLLocationCoordinate2D)projectedPointToLatLong:(RMProjectedPoint)projectedPoint
{
	return [projection pointToLatLong:projectedPoint];
}

- (CGPoint)latLongToPixel:(CLLocationCoordinate2D)latlong withMetersPerPixel:(float)aScale
{	
	return [mercatorToScreenProjection projectXYPoint:[projection latLongToPoint:latlong] withMetersPerPixel:aScale];
}

- (RMTilePoint)latLongToTilePoint:(CLLocationCoordinate2D)latlong withMetersPerPixel:(float)aScale
{
        return [mercatorToTileProjection project:[projection latLongToPoint:latlong] atZoom:aScale];
}

- (CLLocationCoordinate2D)pixelToLatLong:(CGPoint)aPixel
{
	return [projection pointToLatLong:[mercatorToScreenProjection projectScreenPointToXY:aPixel]];
}

- (RMProjectedPoint)pixelToProjectedPoint:(CGPoint)aPixel
{
	return [mercatorToScreenProjection projectScreenPointToXY:aPixel];
}

- (CLLocationCoordinate2D)pixelToLatLong:(CGPoint)aPixel withMetersPerPixel:(float)aScale
{
	return [projection pointToLatLong:[mercatorToScreenProjection projectScreenPointToXY:aPixel withMetersPerPixel:aScale]];
}

- (double)scaleDenominator {
	double routemeMetersPerPixel = [self metersPerPixel];
	double iphoneMillimetersPerPixel = kiPhoneMilimeteresPerPixel;
	double truescaleDenominator =  routemeMetersPerPixel / (0.001 * iphoneMillimetersPerPixel) ;
	return truescaleDenominator;
}

#pragma mark Zoom With Bounds
- (void)zoomWithLatLngBoundsNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)sw
{
	if(ne.latitude == sw.latitude && ne.longitude == sw.longitude)//There are no bounds, probably only one marker.
	{
		RMProjectedRect zoomRect;
		RMProjectedPoint myOrigin = [projection latLongToPoint:sw];
		//Default is with scale = 2.0 mercators/pixel
		zoomRect.size.width = [self screenBounds].size.width * 2.0;
		zoomRect.size.height = [self screenBounds].size.height * 2.0;
		myOrigin.easting = myOrigin.easting - (zoomRect.size.width / 2);
		myOrigin.northing = myOrigin.northing - (zoomRect.size.height / 2);
		zoomRect.origin = myOrigin;
		[self zoomWithRMMercatorRectBounds:zoomRect];
	}
	else
	{
		//convert ne/sw into RMMercatorRect and call zoomWithBounds
		float pixelBuffer = kZoomRectPixelBuffer;
		CLLocationCoordinate2D midpoint = {
			.latitude = (ne.latitude + sw.latitude) / 2,
			.longitude = (ne.longitude + sw.longitude) / 2
		};
		RMProjectedPoint myOrigin = [projection latLongToPoint:midpoint];
		RMProjectedPoint nePoint = [projection latLongToPoint:ne];
		RMProjectedPoint swPoint = [projection latLongToPoint:sw];
		RMProjectedPoint myPoint = {.easting = nePoint.easting - swPoint.easting, .northing = nePoint.northing - swPoint.northing};
		//Create the new zoom layout
		RMProjectedRect zoomRect;
		//Default is with scale = 2.0 mercators/pixel
		zoomRect.size.width = [self screenBounds].size.width * 2.0;
		zoomRect.size.height = [self screenBounds].size.height * 2.0;
		if((myPoint.easting / ([self screenBounds].size.width)) < (myPoint.northing / ([self screenBounds].size.height)))
		{
			if((myPoint.northing / ([self screenBounds].size.height - pixelBuffer)) > 1)
			{
				zoomRect.size.width = [self screenBounds].size.width * (myPoint.northing / ([self screenBounds].size.height - pixelBuffer));
				zoomRect.size.height = [self screenBounds].size.height * (myPoint.northing / ([self screenBounds].size.height - pixelBuffer));
			}
		}
		else
		{
			if((myPoint.easting / ([self screenBounds].size.width - pixelBuffer)) > 1)
			{
				zoomRect.size.width = [self screenBounds].size.width * (myPoint.easting / ([self screenBounds].size.width - pixelBuffer));
				zoomRect.size.height = [self screenBounds].size.height * (myPoint.easting / ([self screenBounds].size.width - pixelBuffer));
			}
		}
		myOrigin.easting = myOrigin.easting - (zoomRect.size.width / 2);
		myOrigin.northing = myOrigin.northing - (zoomRect.size.height / 2);
		RMLog(@"Origin is calculated at: %f, %f", [projection pointToLatLong:myOrigin].latitude, [projection pointToLatLong:myOrigin].longitude);
		/*It gets all messed up if our origin is lower than the lowest place on the map, so we check.
		 if(myOrigin.northing < -19971868.880409)
		 {
		 myOrigin.northing = -19971868.880409;
		 }*/
		zoomRect.origin = myOrigin;
		[self zoomWithRMMercatorRectBounds:zoomRect];
	}
}

- (void)zoomWithRMMercatorRectBounds:(RMProjectedRect)bounds
{
	[self setProjectedBounds:bounds];
	[overlay correctPositionOfAllSublayers];
	[tileLoader clearLoadedBounds];
	[tileLoader updateLoadedImages];
	[renderer setNeedsDisplay];
}


#pragma mark Markers and overlays

// Move overlays stuff here - at the moment overlay stuff is above...

- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxForScreen
{
	CGRect rect = [mercatorToScreenProjection screenBounds];
	
	return [self latitudeLongitudeBoundingBoxFor:rect];
}

- (RMSphericalTrapezium) latitudeLongitudeBoundingBoxFor:(CGRect) rect
{	
	RMSphericalTrapezium boundingBox;
	CGPoint northwestScreen = rect.origin;
	
	CGPoint southeastScreen;
	southeastScreen.x = rect.origin.x + rect.size.width;
	southeastScreen.y = rect.origin.y + rect.size.height;
	
	CGPoint northeastScreen, southwestScreen;
	northeastScreen.x = southeastScreen.x;
	northeastScreen.y = northwestScreen.y;
	southwestScreen.x = northwestScreen.x;
	southwestScreen.y = southeastScreen.y;
	
	CLLocationCoordinate2D northeastLL, northwestLL, southeastLL, southwestLL;
	northeastLL = [self pixelToLatLong:northeastScreen];
	northwestLL = [self pixelToLatLong:northwestScreen];
	southeastLL = [self pixelToLatLong:southeastScreen];
	southwestLL = [self pixelToLatLong:southwestScreen];
	
	boundingBox.northeast.latitude = fmax(northeastLL.latitude, northwestLL.latitude);
	boundingBox.southwest.latitude = fmin(southeastLL.latitude, southwestLL.latitude);
	
	// westerly computations:
	// -179, -178 -> -179 (min)
	// -179, 179  -> 179 (max)
	if (fabs(northwestLL.longitude - southwestLL.longitude) <= kMaxLong)
		boundingBox.southwest.longitude = fmin(northwestLL.longitude, southwestLL.longitude);
	else
		boundingBox.southwest.longitude = fmax(northwestLL.longitude, southwestLL.longitude);
	
	if (fabs(northeastLL.longitude - southeastLL.longitude) <= kMaxLong)
		boundingBox.northeast.longitude = fmax(northeastLL.longitude, southeastLL.longitude);
	else
		boundingBox.northeast.longitude = fmin(northeastLL.longitude, southeastLL.longitude);

	return boundingBox;
}

- (void) tilesUpdatedRegion:(CGRect)region
{
	if(delegateHasRegionUpdate)
	{
		RMSphericalTrapezium locationBounds  = [self latitudeLongitudeBoundingBoxFor:region];
		[tilesUpdateDelegate regionUpdate:locationBounds];
	}
}
- (void) printDebuggingInformation
{
	[imagesOnScreen printDebuggingInformation];
}

@dynamic tilesUpdateDelegate;

- (void) setTilesUpdateDelegate: (id<RMTilesUpdateDelegate>) _tilesUpdateDelegate
{
	if (tilesUpdateDelegate == _tilesUpdateDelegate) return;
	tilesUpdateDelegate= _tilesUpdateDelegate;
	//RMLog(@"Delegate type:%@",[(NSObject *) tilesUpdateDelegate description]);
	delegateHasRegionUpdate  = [(NSObject*) tilesUpdateDelegate respondsToSelector: @selector(regionUpdate:)];
}

- (id<RMTilesUpdateDelegate>) tilesUpdateDelegate
{
	return tilesUpdateDelegate;
}

- (void)setRotation:(float)angle
{ 
	[overlay setRotationOfAllSublayers:(-angle)]; // rotate back markers and paths if theirs allowRotate=NO
}

- (short)tileDepth {
	return imagesOnScreen.tileDepth;
}

- (void)setTileDepth:(short)value {
	imagesOnScreen.tileDepth = value;
}

- (BOOL)fullyLoaded {
	return imagesOnScreen.fullyLoaded;
}

@end
