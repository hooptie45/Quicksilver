

#import "QSDockingWindow.h"
#import <Carbon/Carbon.h>
#import "QSRegistry.h"

#import "QSTypes.h"

#import <QSFoundation/QSFoundation.h>

@implementation QSDockingWindow
- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag{
    NSWindow *result = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    //[self setBackgroundColor: [NSColor clearColor]];
    [self setOpaque:NO];
    [self center];
    [self setMovableByWindowBackground:YES];
    [self setShowsResizeIndicator:YES];
    // [self setHasShadow:NO];
    hideTimer=nil;
    [self setCanHide:NO];
    [self setLevel:NSFloatingWindowLevel];
    NSMutableArray *types=[[standardPasteboardTypes mutableCopy]autorelease];
    [types addObjectsFromArray:[[QSReg objectHandlers]allKeys]];
	
    
    [self registerForDraggedTypes:types];
    [self updateTrackingRect:self];
    return result;
}
- (void)sendEvent:(NSEvent *)theEvent{
    
    //NSLog(@"Event: %@",theEvent);
    [super sendEvent:theEvent];
}
-(void)awakeFromNib{
    [self center];
    //  [self setFrameUsingName:autosaveName];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hide:) name:@"QSActiveApplicationChanged" object:nil];
	[[NSDistributedNotificationCenter defaultCenter]
addObserver:self selector:@selector(lock) name:@"com.apple.HIToolbox.beginMenuTrackingNotification" object:nil];
	[[NSDistributedNotificationCenter defaultCenter]
addObserver:self selector:@selector(unlock) name:@"com.apple.HIToolbox.endMenuTrackingNotification" object:nil];
}
- (void)lock{locked=YES;}
- (void)unlock{locked=NO;}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)theEvent{
    
    [self show:self];
    return [super draggingEntered:theEvent];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)theEvent{
    //     NSLog(@"draggingUpdated");
    return [super draggingUpdated:theEvent];
}


- (void)draggingExited:(id <NSDraggingInfo>)theEvent{
	
	lastTime=[NSDate timeIntervalSinceReferenceDate];
	
    if ([hideTimer isValid]){
        [hideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.75]];
    }else{
        [hideTimer release];
        hideTimer = [[NSTimer scheduledTimerWithTimeInterval:0.333 target:self selector:@selector(timerHide:) userInfo:nil repeats:YES]retain];
        [hideTimer fire];
    }
    [super draggingExited:theEvent];
}

- (void)mouseEntered:(NSEvent *)theEvent{
    //  NSLog(@"entered %p",self);
    
    [hideTimer invalidate];
    NSEvent *earlyExit=[NSApp nextEventMatchingMask:NSMouseExitedMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.25] inMode:NSDefaultRunLoopMode dequeue:YES];
    
	// NSLog(@"reentered %@ %d",earlyExit,[self windowNumber]);
    if (!earlyExit && !locked){
        [self show:self];
		//earlyExit=[NSApp nextEventMatchingMask:NSMouseExitedMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1] inMode:NSDefaultRunLoopMode dequeue:YES];
//		if (earlyExit){
//			NSLog(@"aaaa")	;
//		}
//		
	}
	if(!NSMouseInRect([NSEvent mouseLocation],NSInsetRect([self frame],-10,-10),NO)){ 
		[self hide:self];	
	}
	
	else{
		//NSLog(@"Leaving Early");
	}
}

- (void)timerHide:(NSTimer *)timer{
	// bool stayOpen=StillDown();
    //if (!stayOpen){
	// if (![self mouseLocationOutsideOfEventStream])
	
	if(NSMouseInRect([NSEvent mouseLocation],NSInsetRect([self frame],-10,-10),NO)){ //Mouse is outside window
																					 // [hideTimer invalidate];
	}else{
		BOOL shouldHide=[NSDate timeIntervalSinceReferenceDate]-lastTime>0.5;
		if (shouldHide){
			[self hide:self];
			[hideTimer invalidate];
		}
	}
	
	
	//     NSEvent *reentry=[NSApp nextEventMatchingMask:NSMouseEnteredMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.75] inMode:NSEventTrackingRunLoopMode dequeue:NO];
	
	//     NSLog(@"reentered %@ %d",reentry,[self windowNumber]);
	//     if (!reentry )
	//         [self hide:self];
	//�[self hide:self];
	//     [hideTimer invalidate];
    //}
    //else{
    //        NSLog(@"Window Staying Open");
	// }
}

- (void)mouseExited:(NSEvent *)theEvent{
	//    NSLog(@"exit %p", self);
    NSEvent *reentry=[NSApp nextEventMatchingMask:NSMouseEnteredMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.333] inMode:NSDefaultRunLoopMode dequeue:NO];
	
	
    if ([reentry windowNumber]!=[self windowNumber])reentry=nil;
    
    
    if (!reentry && !StillDown()){
        [self hide:self];
    }
	//    NSLog(@"reentered %@ %d",reentry,[self windowNumber]);
	
}

//- (NSTimeInterval)animationResizeTime:(NSRect)newFrame{
//  return [super animationResizeTime:newFrame]*0.75;
//  return 1.0;  
//}

- (BOOL) canFade{
    int edge=touchingEdgeForRectInRect([self frame],[[self screen]frame]);
	
    return (edge>=0);
}

-(BOOL)canBecomeKeyWindow{
    return !hidden;
}

-(BOOL)hidden{return hidden;};


- (IBAction) hideOrOrderOut:(id)sender{
	if (![self canFade]){
		[self orderOut:self];
	} else{
		[self hide:self];
	}	
}

- (IBAction) toggle:(id)sender{
	if(hidden)
		[self show:sender];
	else if ([self isVisible])
		[self hideOrOrderOut:sender];
	else
		[self makeKeyAndOrderFront:sender];
}



- (IBAction) hide:(id)sender{
    if (hidden) return;
	
	[self saveFrame];
	
	if ([self isKeyWindow])[self fakeResignKey];
    int edge=touchingEdgeForRectInRect([self frame],[[self screen]frame]);
    if (edge<0){
	//		[self setAlphaValue:0.75 fadeTime:0.25];
		return;
		
	}
    NSRect hideRect=expelRectFromRectOnEdge([self frame],[[self screen]frame],edge,1.0);
    NSArray *screens=[NSScreen screens];
    if ([screens count]){
        int i;
        for (i=0;i<[screens count];i++){
            if (NSIntersectsRect(NSInsetRect(hideRect,1,1),[[screens objectAtIndex:i]frame])) return;
            
        }
    }
//	NSLog(@"sethidden");
    hidden=YES;
	
	if([self isVisible]){
		[[self helper] _resizeWindow:self toFrame:hideRect alpha:0.1 display:YES];
	}else{
		[self setFrame:hideRect display:YES];
		[self setAlphaValue:0.1];
	}
	
	
	//[self reallyOrderOut:self];
	
	//[[self trackingWindow] orderFront:sender];
	///  [[self trackingWindow] setFrame:NSIntersectionRect(hideRect,[[self screen]frame]) display:YES];
    [self setHasShadow:NO];
    
}
- (IBAction)orderFrontHidden:(id)sender{
	if([self canFade]){
		[self hide:sender];
		[self reallyOrderFront:self];
	}else{
		[self orderFront:sender];
	}
}

- (void)keyDown:(NSEvent *)theEvent{
	if ([theEvent keyCode]==53){
		if([self canFade]){
			[self hide:nil];
			return;
		}
	}
	[super keyDown:theEvent];	
}


- (void)performClose:(id)sender{
	//NSLog(@"close!");
	[self close];
}

- (IBAction) show:(id)sender{
	//  NSLog(@"show %p",self);
	
	//if (hidden)
	//	[self reallyOrderFront:sender];
	//    else
	[self orderFront:sender];
    
    [self setHasShadow:YES];
	
	//[[self trackingWindow] orderOut:sender];
	[[self helper] _resizeWindow:self toFrame:constrainRectToRect([self frame],[[self screen]frame]) alpha:1.0 display:YES];
	
    hidden=NO;
    
    [self makeKeyAndOrderFront:self];
}

- (IBAction) showKeyless:(id)sender{
	//NSLog(@"showkeyless");
	[self orderFront:sender];
    [self setHasShadow:YES];
	[[self helper] _resizeWindow:self toFrame:constrainRectToRect([self frame],[[self screen]frame]) alpha:1.0 display:YES];
    hidden=NO;
}



- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)aScreen{
    return frameRect;
}
- (void)resignKeyWindowNow{
	[self fakeResignKey];
    //    [self hide:self];
}



- (QSTrackingWindow *)trackingWindow {
	if (!trackingWindow)trackingWindow=[[QSTrackingWindow trackingWindow]retain];
	[trackingWindow setDelegate:self];
	return [[trackingWindow retain] autorelease]; 
}



- (void)updateTrackingRect:(id)sender{
    //    NSLog(@"update");
	NSView *frameView=[[self contentView]superview];
    if (trackingRect)[frameView removeTrackingRect:trackingRect];
    trackingRect=[frameView addTrackingRect:[frameView bounds] owner:self userData:nil assumeInside:NO];
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag{
    // NSLog(@"updatea",frameRect.size.width,[self frame].size);
    BOOL sizeChanged=(NSEqualSizes(frameRect.size,[self frame].size));
    [super setFrame:frameRect display:flag];
    if (sizeChanged) [self updateTrackingRect:self];
}


- (void)saveFrame{
	//NSLog(@"Save");
	if ([self autosaveName])
	[self saveFrameUsingName:[self autosaveName]];
}

- (void)orderOut:(id)sender{
	if (!hidden){
		[self saveFrame];
		[super orderOut:sender];
	}else{
		[super reallyOrderOut:sender];	
	}
}
- (NSString *)autosaveName { return autosaveName; }

- (void)setAutosaveName:(NSString *)newAutosaveName {
    [autosaveName release];
    autosaveName = [newAutosaveName retain];
    
    [self setFrameUsingName:autosaveName force:YES];
}
@end