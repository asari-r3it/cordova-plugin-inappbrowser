/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVWKInAppBrowserUIDelegate.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kIABMediaPermissionDefaultsPrefix = @"CDVWKInAppBrowserMediaPermission.";

@implementation CDVWKInAppBrowserUIDelegate

- (instancetype)initWithTitle:(NSString*)title
{
    self = [super init];
    if (self) {
        self.title = title;
    }

    return self;
}

- (void)     webView:(WKWebView*)webView runJavaScriptAlertPanelWithMessage:(NSString*)message
    initiatedByFrame:(WKFrameInfo*)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction* action)
        {
            completionHandler();
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];

    [alert addAction:ok];

    [[self getViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)     webView:(WKWebView*)webView runJavaScriptConfirmPanelWithMessage:(NSString*)message
    initiatedByFrame:(WKFrameInfo*)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction* action)
        {
            completionHandler(YES);
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];

    [alert addAction:ok];

    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action)
        {
            completionHandler(NO);
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
    [alert addAction:cancel];

    [[self getViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)      webView:(WKWebView*)webView runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
          defaultText:(NSString*)defaultText initiatedByFrame:(WKFrameInfo*)frame
    completionHandler:(void (^)(NSString* result))completionHandler
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:prompt
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction* action)
        {
            completionHandler(((UITextField*)alert.textFields[0]).text);
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];

    [alert addAction:ok];

    UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action)
        {
            completionHandler(nil);
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.text = defaultText;
    }];

    [[self getViewController] presentViewController:alert animated:YES completion:nil];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 150000
- (void)webView:(WKWebView*)webView
    requestMediaCapturePermissionForOrigin:(WKSecurityOrigin*)origin
    initiatedByFrame:(WKFrameInfo*)frame
    type:(WKMediaCaptureType)type
    decisionHandler:(void (^)(WKPermissionDecision decision))decisionHandler API_AVAILABLE(ios(15.0))
{
    NSString* permissionKey = [self mediaPermissionKeyForOrigin:origin type:type];
    NSNumber* savedDecision = [[NSUserDefaults standardUserDefaults] objectForKey:permissionKey];
    if (savedDecision != nil) {
        decisionHandler([savedDecision boolValue] ? WKPermissionDecisionGrant : WKPermissionDecisionDeny);
        return;
    }

    [self requestNativePermissionForMediaCaptureType:type completion:^(BOOL nativeGranted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!nativeGranted) {
                decisionHandler(WKPermissionDecisionDeny);
                return;
            }

            [self promptForOrigin:origin type:type completion:^(BOOL originGranted) {
                [[NSUserDefaults standardUserDefaults] setBool:originGranted forKey:permissionKey];
                decisionHandler(originGranted ? WKPermissionDecisionGrant : WKPermissionDecisionDeny);
            }];
        });
    }];
}

- (NSString*)mediaPermissionKeyForOrigin:(WKSecurityOrigin*)origin type:(WKMediaCaptureType)type API_AVAILABLE(ios(15.0))
{
    return [NSString stringWithFormat:@"%@%@://%@:%ld.%ld",
            kIABMediaPermissionDefaultsPrefix,
            origin.protocol,
            origin.host,
            (long)origin.port,
            (long)type];
}

- (void)promptForOrigin:(WKSecurityOrigin*)origin type:(WKMediaCaptureType)type completion:(void (^)(BOOL granted))completion API_AVAILABLE(ios(15.0))
{
    NSString* message = [NSString stringWithFormat:NSLocalizedString(@"Allow %@ to access %@?", nil),
                         origin.host,
                         [self mediaCaptureNameForType:type]];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* allow = [UIAlertAction actionWithTitle:NSLocalizedString(@"Allow", nil)
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction* action) {
        completion(YES);
    }];
    UIAlertAction* deny = [UIAlertAction actionWithTitle:NSLocalizedString(@"Deny", nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction* action) {
        completion(NO);
    }];

    [alert addAction:deny];
    [alert addAction:allow];
    [[self getViewController] presentViewController:alert animated:YES completion:nil];
}

- (NSString*)mediaCaptureNameForType:(WKMediaCaptureType)type API_AVAILABLE(ios(15.0))
{
    switch (type) {
        case WKMediaCaptureTypeCamera:
            return NSLocalizedString(@"the camera", nil);
        case WKMediaCaptureTypeMicrophone:
            return NSLocalizedString(@"the microphone", nil);
        case WKMediaCaptureTypeCameraAndMicrophone:
            return NSLocalizedString(@"the camera and microphone", nil);
        default:
            return NSLocalizedString(@"media devices", nil);
    }
}

- (void)requestNativePermissionForMediaCaptureType:(WKMediaCaptureType)type completion:(void (^)(BOOL granted))completion API_AVAILABLE(ios(15.0))
{
    BOOL needsCamera = type == WKMediaCaptureTypeCamera || type == WKMediaCaptureTypeCameraAndMicrophone;
    BOOL needsMicrophone = type == WKMediaCaptureTypeMicrophone || type == WKMediaCaptureTypeCameraAndMicrophone;

    if (!needsCamera && !needsMicrophone) {
        completion(NO);
        return;
    }

    __block BOOL cameraGrantedResult = YES;
    __block BOOL microphoneGrantedResult = YES;
    dispatch_group_t group = dispatch_group_create();

    if (needsCamera) {
        dispatch_group_enter(group);
        [self requestCameraPermissionWithCompletion:^(BOOL cameraGranted) {
            cameraGrantedResult = cameraGranted;
            dispatch_group_leave(group);
        }];
    }

    if (needsMicrophone) {
        dispatch_group_enter(group);
        [self requestMicrophonePermissionWithCompletion:^(BOOL microphoneGranted) {
            microphoneGrantedResult = microphoneGranted;
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion(cameraGrantedResult && microphoneGrantedResult);
    });
}

- (void)requestCameraPermissionWithCompletion:(void (^)(BOOL granted))completion
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            completion(YES);
            break;
        case AVAuthorizationStatusNotDetermined:
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:completion];
            break;
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            completion(NO);
            break;
    }
}

- (void)requestMicrophonePermissionWithCompletion:(void (^)(BOOL granted))completion
{
    AVAudioSessionRecordPermission permission = [[AVAudioSession sharedInstance] recordPermission];
    switch (permission) {
        case AVAudioSessionRecordPermissionGranted:
            completion(YES);
            break;
        case AVAudioSessionRecordPermissionUndetermined:
            [[AVAudioSession sharedInstance] requestRecordPermission:completion];
            break;
        case AVAudioSessionRecordPermissionDenied:
        default:
            completion(NO);
            break;
    }
}
#endif

-(UIViewController*) getViewController
{
    return _viewController;
}

-(void) setViewController:(UIViewController*) viewController
{
    _viewController = viewController;
}

@end
