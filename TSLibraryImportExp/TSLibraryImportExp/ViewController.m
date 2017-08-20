//
//  ViewController.m
//  TSLibraryImportExp
//
//  Created by BqLin on 2017/8/20.
//  Copyright © 2017年 BqLin. All rights reserved.
//

#import "ViewController.h"
#import "TSLibraryImport.h"
#import <MediaPlayer/MediaPlayer.h>

@interface ViewController () <MPMediaPickerControllerDelegate>

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *elapsedLabel;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, strong) AVPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	self.progressView.progress = 0.f;
	[self setupAudioSessionCategory];
}

- (void)setupAudioSessionCategory {
	AVAudioSession *session = [AVAudioSession sharedInstance];
	NSError *error = nil;
	if(![session setCategory:AVAudioSessionCategoryPlayback error:&error]) {
		NSLog(@"Couldn't set audio session category: %@", error);
	}
	if(![session setActive:YES error:&error]) {
		NSLog(@"Couldn't make audio session active: %@", error);
	}
}

- (void)progressTimer:(NSTimer *)timer {
	TSLibraryImport *export = (TSLibraryImport *)timer.userInfo;
	switch (export.status) {
		case AVAssetExportSessionStatusCompleted:
		case AVAssetExportSessionStatusExporting:{
			NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - self.startTime;
			CGFloat minutes = rint(delta / 60.f);
			CGFloat seconds = fmod(delta, 60.f);
			self.elapsedLabel.text = [NSString stringWithFormat:@"%2.0f:%f", minutes, seconds];
			self.progressView.progress = export.progress;
			NSLog(@"%@ - %f", self.elapsedLabel.text, self.progressView.progress);
			if (export.status == AVAssetExportSessionStatusCompleted) [timer invalidate];
		}break;
		case AVAssetExportSessionStatusCancelled:
		case AVAssetExportSessionStatusFailed:{
			[timer invalidate];
		}break;
		default:{}break;
	}
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - control action

- (IBAction)pickSong:(id)sender {
	[self showMediaPicker];
}

- (void)showMediaPicker {
	MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAny];
	mediaPicker.delegate = self;
	[self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)exportAssetAtURL:(NSURL *)assetURL withTitle:(NSString *)title {
	// create destination URL
	NSString *extension = [TSLibraryImport extensionForAssetURL:assetURL];
	NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
	NSURL *outputURL = [NSURL fileURLWithPath:[[documentsDirectory stringByAppendingPathComponent:title] stringByAppendingPathExtension:extension]];
	// we're responsible for making sure the destination url doesn't already exist
	[[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
	
	// create the import object
	TSLibraryImport *import = [[TSLibraryImport alloc] init];
	self.startTime = [NSDate timeIntervalSinceReferenceDate];
	NSTimer *timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(progressTimer:) userInfo:import repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	__weak typeof(self) weakSelf = self;
	[import importAsset:assetURL toURL:outputURL completionBlock:^(TSLibraryImport *import) {
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
			import = nil;
			return;
		}
		
		// import completed
		import = nil;
		NSLog(@"output: %@", outputURL.absoluteString);
		if (!weakSelf.player) {
			weakSelf.player = [AVPlayer playerWithURL:outputURL];
		} else {
			[weakSelf.player pause];
			[weakSelf.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:outputURL]];
		}
		[weakSelf.player play];
	}];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	if (self.player.rate) {
		[self.player pause];
	} else {
		[self.player play];
	}
}

#pragma mark - MPMediaPickerControllerDelegate

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	[mediaPicker dismissViewControllerAnimated:YES completion:nil];
	for (MPMediaItem *item in mediaItemCollection.items) {
		NSString *title = item.title;
		NSURL *assetURL = item.assetURL;
		if (!assetURL) {
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
	[mediaPicker dismissViewControllerAnimated:YES completion:nil];
}

@end
