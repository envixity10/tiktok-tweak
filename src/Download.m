#import "Download.h"
#import "UIUtil.h"
#import "Owned.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

static AVPlayer *TSFindPlaying(UIView *view, NSInteger depth, AVPlayer **fallback) {
    if (!view || depth > 32) return nil;
    if (TSIsOwnedView(view)) return nil;
    AVPlayerLayer *layer = [view.layer isKindOfClass:[AVPlayerLayer class]] ? (AVPlayerLayer *)view.layer : nil;
    if (!layer) {
        for (CALayer *sublayer in view.layer.sublayers) {
            if ([sublayer isKindOfClass:[AVPlayerLayer class]]) {
                layer = (AVPlayerLayer *)sublayer;
                break;
            }
        }
    }
    if (layer.player.currentItem) {
        if (layer.player.rate > 0.01f) return layer.player;
        if (fallback && !*fallback) *fallback = layer.player;
    }
    for (UIView *subview in view.subviews) {
        AVPlayer *found = TSFindPlaying(subview, depth + 1, fallback);
        if (found) return found;
    }
    return nil;
}

static AVPlayer *TSCurrentPlayer(void) {
    AVPlayer *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            AVPlayer *playing = TSFindPlaying(window, 0, &fallback);
            if (playing) return playing;
        }
    }
    return fallback;
}

static NSURL *TSAssetURL(AVAsset *asset) {
    if ([asset isKindOfClass:[AVURLAsset class]]) return ((AVURLAsset *)asset).URL;
    return nil;
}

static BOOL TSURLLooksLikeFile(NSURL *url) {
    NSString *ext = url.pathExtension.lowercaseString;
    return [@[@"mp4", @"mov", @"m4v"] containsObject:ext];
}

@implementation TSDownload

+ (void)copyPlaybackURL {
    NSURL *url = TSAssetURL(TSCurrentPlayer().currentItem.asset);
    if (!url) {
        TSPresentAlert(nil, @"No playback URL", @"Open a video and try again. Some streams do not expose a URL.");
        return;
    }
    [UIPasteboard generalPasteboard].URL = url;
    TSHapticSuccess();
    TSPresentAlert(nil, @"Copied", @"The playback URL is on the clipboard.");
}

+ (void)saveCurrentVideo {
    AVPlayer *player = TSCurrentPlayer();
    AVPlayerItem *item = player.currentItem;
    if (!item) {
        TSPresentAlert(nil, @"Nothing is playing", @"Open a video, then save it from the TikSpice button.");
        return;
    }
    UIViewController *presenter = TSTopViewController();
    if (!presenter) return;
    UIAlertController *busy = [UIAlertController alertControllerWithTitle:@"Saving video"
                                                                  message:@"Exporting whatever the player is using. That file is often the copy without a download watermark."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:busy animated:YES completion:^{
        [self exportItem:item presenter:presenter busy:busy];
    }];
}

+ (void)exportItem:(AVPlayerItem *)item presenter:(UIViewController *)presenter busy:(UIAlertController *)busy {
    AVAsset *asset = item.asset;
    NSURL *remote = TSAssetURL(asset);
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"]];
    NSURL *output = [NSURL fileURLWithPath:path];
    [[NSFileManager defaultManager] removeItemAtURL:output error:nil];

    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    if (!session) {
        [self downloadURL:remote output:output presenter:presenter busy:busy reason:@"This stream cannot be exported."];
        return;
    }
    session.outputURL = output;
    session.outputFileType = AVFileTypeMPEG4;
    session.shouldOptimizeForNetworkUse = YES;
    [session exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (session.status == AVAssetExportSessionStatusCompleted) {
                [self writeVideoAtURL:output presenter:presenter busy:busy];
                return;
            }
            NSString *reason = session.error.localizedDescription ?: @"Export failed.";
            [self downloadURL:remote output:output presenter:presenter busy:busy reason:reason];
        });
    }];
}

+ (void)downloadURL:(NSURL *)url output:(NSURL *)output presenter:(UIViewController *)presenter busy:(UIAlertController *)busy reason:(NSString *)reason {
    if (!TSURLLooksLikeFile(url)) {
        [self finishBusy:busy presenter:presenter title:@"Could not save" message:reason];
        return;
    }
    [[[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!location || error) {
                [self finishBusy:busy presenter:presenter title:@"Could not save" message:error.localizedDescription ?: reason];
                return;
            }
            [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
            NSError *copyError = nil;
            [[NSFileManager defaultManager] copyItemAtURL:location toURL:output error:&copyError];
            if (copyError) {
                [self finishBusy:busy presenter:presenter title:@"Could not save" message:copyError.localizedDescription];
                return;
            }
            [self writeVideoAtURL:output presenter:presenter busy:busy];
        });
    }] resume];
}

+ (void)writeVideoAtURL:(NSURL *)fileURL presenter:(UIViewController *)presenter busy:(UIAlertController *)busy {
    void (^write)(void) = ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                if (success) {
                    TSHapticSuccess();
                    [self finishBusy:busy presenter:presenter title:@"Saved" message:@"The video is in Photos."];
                } else {
                    [self finishBusy:busy presenter:presenter title:@"Could not save" message:error.localizedDescription ?: @"Photos refused the file."];
                }
            });
        }];
    };
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
                write();
            } else {
                [self finishBusy:busy presenter:presenter title:@"Photos access" message:@"Allow photo library access to save videos, then try again."];
            }
        });
    }];
}

+ (void)finishBusy:(UIAlertController *)busy presenter:(UIViewController *)presenter title:(NSString *)title message:(NSString *)message {
    void (^show)(void) = ^{
        TSPresentAlert(presenter, title, message);
    };
    if (busy.presentingViewController) {
        [busy dismissViewControllerAnimated:YES completion:show];
    } else {
        show();
    }
}

@end
