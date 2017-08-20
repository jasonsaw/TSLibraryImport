//
//The MIT License
//
//Copyright (c) 2010 tapsquare, llc., (http://www.tapsquare.com, art@tapsquare.com)
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.
//

#import "iPodLibraryAccessViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "TSLibraryImport.h"

@implementation iPodLibraryAccessViewController

- (void)viewDidLoad {
	
    [super viewDidLoad];
	[progressView setProgress:0.f];

	AVAudioSession* session = [AVAudioSession sharedInstance];
	NSError* error = nil;
	if(![session setCategory:AVAudioSessionCategoryPlayback error:&error]) {
		NSLog(@"Couldn't set audio session category: %@", error);
	}	
	if(![session setActive:YES error:&error]) {
		NSLog(@"Couldn't make audio session active: %@", error);
	}
}

- (void)progressTimer:(NSTimer*)timer {
	TSLibraryImport* export = (TSLibraryImport*)timer.userInfo;
	switch (export.status) {
		case AVAssetExportSessionStatusExporting:
		{
			NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - startTime;
			float minutes = rintf(delta/60.f);
			float seconds = rintf(fmodf(delta, 60.f));
			[elapsedLabel setText:[NSString stringWithFormat:@"%2.0f:%02.0f", minutes, seconds]];
			[progressView setProgress:export.progress];
			break;
		}
		case AVAssetExportSessionStatusCancelled:
		case AVAssetExportSessionStatusCompleted:
		case AVAssetExportSessionStatusFailed:
			[timer invalidate];
			break;
		default:
			break;
	}		
}

- (void)exportAssetAtURL:(NSURL*)assetURL withTitle:(NSString*)title {
	
	// create destination URL
	NSString* ext = [TSLibraryImport extensionForAssetURL:assetURL];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSURL* outURL = [[NSURL fileURLWithPath:[documentsDirectory stringByAppendingPathComponent:title]] URLByAppendingPathExtension:ext];	
	// we're responsible for making sure the destination url doesn't already exist
	[[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
	
	// create the import object
	TSLibraryImport* import = [[TSLibraryImport alloc] init];
	startTime = [NSDate timeIntervalSinceReferenceDate];
	NSTimer* timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(progressTimer:) userInfo:import repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	[import importAsset:assetURL toURL:outURL completionBlock:^(TSLibraryImport* import) {
		/*
		 * If the export was successful (check the status and error properties of 
		 * the TSLibraryImport instance) you know have a local copy of the file
		 * at `outURL` You can get PCM samples for processing by opening it with 
		 * ExtAudioFile. Yay!
		 *
		 * Here we're just playing it with AVPlayer
		 */
		if (import.status != AVAssetExportSessionStatusCompleted) {
			// something went wrong with the import
			NSLog(@"Error importing: %@", import.error);
			[import release];
			import = nil;
			return;
		}
		
		// import completed
		[import release];
		import = nil;
		if (!player) {
			player = [[AVPlayer alloc] initWithURL:outURL];			
		} else {
			[player pause];
			[player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:outURL]];
		}
		[player play];
	}];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker 
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	[self dismissModalViewControllerAnimated:YES];
	for (MPMediaItem* item in mediaItemCollection.items) {
		NSString* title = [item valueForProperty:MPMediaItemPropertyTitle];
		NSURL* assetURL = [item valueForProperty:MPMediaItemPropertyAssetURL];
		if (nil == assetURL) {
			/**
			 * !!!: When MPMediaItemPropertyAssetURL is nil, it typically means the file
			 * in question is protected by DRM. (old m4p files)
			 */
			return;
		}
		[self exportAssetAtURL:assetURL withTitle:title];
	}
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)showMediaPicker {
	/*
	 * ???: Can we filter the media picker so we don't see m4p files?
	 */
	MPMediaPickerController* mediaPicker = [[[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic] autorelease];
	mediaPicker.delegate = self;
	[self presentModalViewController:mediaPicker animated:YES];
}

- (IBAction)pickSong:(id)sender {
	[self showMediaPicker];
}

- (void)dealloc {
	[player release];
	[progressView release];
	[elapsedLabel release];
    [super dealloc];
}

@end
