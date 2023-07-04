/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UAInAppMessageManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleAudience.h"
#import "UATagSelector+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppRemoteDataClient+Internal.h"
#import "UAComponent.h"
#import "UAInAppAutomation+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UADeferredSchedule+Internal.h"
#import "UAFrequencyLimitManager+Internal.h"
#import "AirshipTests-Swift.h"
#import "UARetriable+Internal.h"

@import AirshipCore;

@interface UAInAppAutomationTest : UAAirshipBaseTest
@property(nonatomic, strong) UAInAppAutomation *inAppAutomation;
@property(nonatomic, strong) id mockAutomationEngine;
@property(nonatomic, strong) id mockAudienceOverridesProvider;
@property(nonatomic, strong) id mockRemoteDataClient;
@property(nonatomic, strong) id mockInAppMessageManager;
@property(nonatomic, strong) id mockDeferredClient;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockAudienceChecker;

@property(nonatomic, strong) UATestAirshipInstance *airship;
@property(nonatomic, strong) id mockFrequencyLimitManager;
@property(nonatomic, strong) UAPrivacyManager *privacyManager;

@property(nonatomic, strong) id<UAAutomationEngineDelegate> engineDelegate;
@end

@interface UAInAppAutomation()
- (void)prepareDeferredSchedule:(UASchedule *)schedule
                 triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
               retriableHandler:(UARetriableCompletionHandler) retriableHandler
              completionHandler:(void (^)(UAAutomationSchedulePrepareResult))completionHandler;
@end

@implementation UAInAppAutomationTest

- (void)setUp {
    [super setUp];


    self.privacyManager = [UAPrivacyManager privacyManagerWithDataStore:self.dataStore defaultEnabledFeatures:UAFeaturesAll];

    self.mockAutomationEngine = [self mockForClass:[UAAutomationEngine class]];
    self.mockAudienceOverridesProvider = [self mockForClass:[UAAutomationAudienceOverridesProvider class]];
    self.mockRemoteDataClient = [self mockForClass:[UAInAppRemoteDataClient class]];
    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];
    self.mockDeferredClient = [self mockForClass:[UADeferredScheduleAPIClient class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockFrequencyLimitManager = [self mockForClass:[UAFrequencyLimitManager class]];
    self.mockAudienceChecker = [self mockForProtocol:@protocol(UAAutomationAudienceCheckerProtocol)];

    [[[self.mockAutomationEngine stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.engineDelegate =  (__bridge id<UAAutomationEngineDelegate>)arg;
    }] setDelegate:OCMOCK_ANY];

    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.mockChannel];
    self.airship.privacyManager = self.privacyManager;
    [self.airship makeShared];


    self.inAppAutomation = [UAInAppAutomation automationWithConfig:self.config
                                                  automationEngine:self.mockAutomationEngine
                                         audienceOverridesProvider:self.mockAudienceOverridesProvider
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                         deferredScheduleAPIClient:self.mockDeferredClient
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager
                                                   audienceChecker:self.mockAudienceChecker];
    XCTAssertNotNil(self.engineDelegate);
}

- (void)testAutoPauseEnabled {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.site = UACloudSiteUS;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";
    config.autoPauseInAppAutomationOnLaunch = YES;

    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];
    self.inAppAutomation = [UAInAppAutomation automationWithConfig:runtimeConfig
                                                  automationEngine:self.mockAutomationEngine
                                         audienceOverridesProvider:self.mockAudienceOverridesProvider
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                         deferredScheduleAPIClient:self.mockDeferredClient
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager
                                                   audienceChecker:self.mockAudienceChecker];

    XCTAssertTrue(self.inAppAutomation.isPaused);
}

- (void)testAutoPauseDisabled {
    UAConfig *config = [[UAConfig alloc] init];
    config.inProduction = NO;
    config.site = UACloudSiteUS;
    config.developmentAppKey = @"test-app-key";
    config.developmentAppSecret = @"test-app-secret";
    config.autoPauseInAppAutomationOnLaunch = NO;
    UARuntimeConfig *runtimeConfig = [[UARuntimeConfig alloc] initWithConfig:config dataStore:self.dataStore];

    self.inAppAutomation = [UAInAppAutomation automationWithConfig:runtimeConfig
                                                  automationEngine:self.mockAutomationEngine
                                         audienceOverridesProvider:self.mockAudienceOverridesProvider
                                                  remoteDataClient:self.mockRemoteDataClient
                                                         dataStore:self.dataStore
                                               inAppMessageManager:self.mockInAppMessageManager
                                                           channel:self.mockChannel
                                         deferredScheduleAPIClient:self.mockDeferredClient
                                             frequencyLimitManager:self.mockFrequencyLimitManager
                                                    privacyManager:self.privacyManager
                                                   audienceChecker:self.mockAudienceChecker];

    XCTAssertFalse(self.inAppAutomation.isPaused);
}


- (void)testCheckEmptyAudience {
    UAScheduleAudience *emptyAudience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
    }];

    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(YES, nil);
    }] evaluateWithAudience:OCMOCK_ANY isNewUserEvaluationDate:OCMOCK_ANY contactID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *checkFinished = [self expectationWithDescription:@"check audience finished"];
    [self.inAppAutomation checkAudience:emptyAudience completionHandler:^(BOOL inAudience, NSError * _Nullable error) {
        XCTAssertTrue(inAudience);
        XCTAssertNil(error);
        [checkFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareMessage {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.reportingContext = @{@"some": @"reporting context"};

        builder.frequencyConstraintIDs = @[@"barConstraint", @"fooConstraint"];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:@[@"barConstraint", @"fooConstraint"] completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{@"some": @"reporting context"}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareMessageUnderLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareMessageOverLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return YES;
        } checkAndIncrement:^BOOL{
            return NO;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager reject] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:nil
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareActions {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testPrepareActionsUnderLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareActionsOverLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return YES;
        } checkAndIncrement:^BOOL{
            return NO;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:message audienceMatch:YES];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAInAppMessagePrepareResult);
        [invocation getArgument:&block atIndex:6];
        block(UAInAppMessagePrepareResultSuccess);
    }] prepareMessage:message scheduleID:@"schedule ID"
     campaigns:@{@"some": @"campaigns object"}
     reportingContext:@{}
     completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL
     channelID:@"channel ID" triggerContext:triggerContext
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
    [self.mockInAppMessageManager verify];
    [self.mockAudienceOverridesProvider verify];
}

- (void)testPrepareDeferredUnderLimit {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:message audienceMatch:YES];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];


    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAInAppMessagePrepareResult);
        [invocation getArgument:&block atIndex:6];
        block(UAInAppMessagePrepareResultSuccess);
    }] prepareMessage:message scheduleID:@"schedule ID" campaigns:@{@"some": @"campaigns object"} reportingContext:@{} completionHandler:OCMOCK_ANY];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL
     channelID:@"channel ID" triggerContext:triggerContext
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
    [self.mockInAppMessageManager verify];
    [self.mockAudienceOverridesProvider verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testPrepareDeferredOverLimit {
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];

    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];
    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[trigger];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager reject] prepareMessage:OCMOCK_ANY scheduleID:OCMOCK_ANY campaigns:OCMOCK_ANY reportingContext:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return YES;
        } checkAndIncrement:^BOOL{
            return NO;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockDeferredClient reject] resolveURL:OCMOCK_ANY channelID:OCMOCK_ANY triggerContext:OCMOCK_ANY audienceOverrides:OCMOCK_ANY
                              completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:triggerContext
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
    [self.mockInAppMessageManager verify];
}

- (void)testPrepareDeferredTimedOut {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:401 result:nil rules:nil];

    NSError *deferredError = [NSError errorWithDomain:@"deferred error"
                                                  code:100
                                              userInfo:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    
    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, deferredError);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredCode409 {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:409 result:nil rules:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(void) =  (__bridge void (^)(void))arg;
        callback();
    }] invalidateAndRefreshSchedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultInvalidate, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredCode429WithRetry {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredScheduleRetryRules *rules = [UADeferredScheduleRetryRules rulesWithLocation:nil retryTime:5];
    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:429 result:nil rules:rules];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule triggerContext:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetryAfter);
        XCTAssertEqual(time, 5);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredCode429NoRetry {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:429 result:nil rules:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule triggerContext:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetry);
        XCTAssertEqual(time, 0);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredCode307WithRetry {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredScheduleRetryRules *rules = [UADeferredScheduleRetryRules rulesWithLocation:nil retryTime:5];
    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:307 result:nil rules:rules];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule triggerContext:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetryAfter);
        XCTAssertEqual(time, 5);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredCode307NoRetry {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:307 result:nil rules:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.inAppAutomation prepareDeferredSchedule:schedule triggerContext:nil retriableHandler:^(UARetriableResult result, NSTimeInterval time) {
        XCTAssertEqual(result, UARetriableResultRetryWithBackoffReset);
        XCTAssertEqual(time, 0);
        [prepareFinished fulfill];
    } completionHandler:^(UAAutomationSchedulePrepareResult result) {}];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredAudienceMiss {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:nil audienceMatch:NO];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(YES, nil);
    }] evaluateWithAudience:OCMOCK_ANY isNewUserEvaluationDate:OCMOCK_ANY contactID:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareDeferredNoMessage {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:nil audienceMatch:YES];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"https://airship.com"]
                                                                retriableOnTimeout:NO];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:deferred builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder * _Nonnull builder) {
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
    }];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:nil
     audienceOverrides:overrides completionHandler:OCMOCK_ANY];

    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(YES, nil);
    }] evaluateWithAudience:OCMOCK_ANY isNewUserEvaluationDate:OCMOCK_ANY contactID:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule
                          triggerContext:nil
                       completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockDeferredClient verify];
}

- (void)testPrepareScheduleInvalid {
    UASchedule *schedule = [[UASchedule alloc] init];

    [[[self.mockRemoteDataClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] refreshAndCheckScheduleUpToDate:schedule completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultInvalidate, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
}


- (void)testPrepareAudienceCheckFailureDefaultMissBehavior {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
        }];
        builder.isNewUserEvaluationDate = [NSDate date];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Mock the checks to reject the audience
    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(NO, nil);
    }] evaluateWithAudience:OCMOCK_ANY isNewUserEvaluationDate:OCMOCK_ANY contactID:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAudienceChecker verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorCancel {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorCancel;
        }];
        builder.isNewUserEvaluationDate = [NSDate now];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Mock the checks to reject the audience
    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(NO, nil);
    }] evaluateWithAudience:schedule.audienceJSON
     isNewUserEvaluationDate:schedule.isNewUserEvaluationDate
                  contactID:nil
          completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultCancel, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAudienceChecker verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorSkip {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        }];
        builder.isNewUserEvaluationDate = [NSDate now];
    }];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Mock the checks to reject the audience
    // Mock the checks to reject the audience
    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(NO, nil);
    }] evaluateWithAudience:schedule.audienceJSON
     isNewUserEvaluationDate:schedule.isNewUserEvaluationDate
                  contactID:nil
          completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultSkip, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAudienceChecker verify];
}

- (void)testPrepareAudienceCheckFailureMissBehaviorPenalize {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.audience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
            builder.notificationsOptIn = @(YES);
            builder.missBehavior = UAScheduleAudienceMissBehaviorPenalize;
        }];
        builder.isNewUserEvaluationDate = [NSDate now];
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback(nil);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Mock the checks to reject the audience
    // Mock the checks to reject the audience
    [[[self.mockAudienceChecker expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void(^callback)(BOOL, NSError *) =  (__bridge void (^)(BOOL, NSError *))arg;
        callback(NO, nil);
    }] evaluateWithAudience:schedule.audienceJSON
     isNewUserEvaluationDate:schedule.isNewUserEvaluationDate
                  contactID:nil
          completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultPenalize, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAudienceChecker verify];
}

- (void)testIsActionsReady {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsActionsReadyUnderLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsActionsReadyOverLimit {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return overLimit;
        } checkAndIncrement:^BOOL{
            return checkAndIncrement;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReady {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsMessageReadyDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);
}

- (void)testIsMessageNotReady {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultNotReady)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageNotReadyDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultNotReady)] isReadyToDisplay:@"schedule ID"];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageReadyInvalid {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(NO);
    }] isScheduleUpToDate:schedule completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] scheduleExecutionAborted:schedule.identifier];

    XCTestExpectation *precheckFinished = [self expectationWithDescription:@"prepare finished"];
    [self.engineDelegate isScheduleReadyPrecheck:schedule completionHandler:^(UAAutomationScheduleReadyResult result) {
        XCTAssertEqual(UAAutomationScheduleReadyResultInvalidate, result);
        [precheckFinished fulfill];
    }];

    [self waitForTestExpectations];

    [self.engineDelegate isScheduleReadyToExecute:schedule];
    [self.mockInAppMessageManager verify];
}

- (void)testIsReadyPaused {
    self.inAppAutomation.paused = YES;

    UASchedule *schedule = [[UASchedule alloc] init];


    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];
    XCTAssertEqual(UAAutomationScheduleReadyResultNotReady, result);
}

- (void)testIsMessageReadyUnderLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.reportingContext = @{@"something": @"something"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{@"something": @"something"}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);

    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyOverLimit {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return overLimit;
        } checkAndIncrement:^BOOL{
            return checkAndIncrement;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:nil completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);

    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyUnderLimitDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:message audienceMatch:YES];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:triggerContext audienceOverrides:overrides completionHandler:OCMOCK_ANY];


    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return NO;
        } checkAndIncrement:^BOOL{
            return YES;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:triggerContext completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultContinue, result);

    [self.mockAudienceOverridesProvider verify];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testIsMessageReadyOverLimitDeferred {
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UAScheduleDeferredData *deferred = [UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                retriableOnTimeout:YES];

    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
        builder.campaigns = @{@"some": @"campaigns object"};
    }];

    UADeferredScheduleResult *deferredResult = [UADeferredScheduleResult resultWithMessage:message audienceMatch:YES];

    UADeferredAPIClientResponse *deferredResponse = [UADeferredAPIClientResponse responseWithStatus:200 result:deferredResult rules:nil];

    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger
                                                                                             event:@"some event"];

    UAAutomationAudienceOverrides *overrides = [[UAAutomationAudienceOverrides alloc] initWithTagsPayload:nil attributesPayload:nil];
    [[[self.mockAudienceOverridesProvider expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UAAutomationAudienceOverrides *);
        [invocation getArgument:&block atIndex:3];
        block(overrides);
    }] audienceOverridesWithChannelID:@"channel ID" completionHandler:OCMOCK_ANY];

    [[[self.mockDeferredClient expect] andDo:^(NSInvocation *invocation) {
        void (^block)(UADeferredAPIClientResponse *, NSError *);
        [invocation getArgument:&block atIndex:6];
        block(deferredResponse, nil);
    }] resolveURL:deferred.URL channelID:@"channel ID" triggerContext:triggerContext audienceOverrides:overrides completionHandler:OCMOCK_ANY];


    [[[self.mockRemoteDataClient stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(BOOL) =  (__bridge void (^)(BOOL))arg;
        callback(YES);
    }] refreshAndCheckScheduleUpToDate:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[[self.mockInAppMessageManager expect] andReturnValue:@(UAAutomationScheduleReadyResultContinue)] isReadyToDisplay:@"schedule ID"];

    __block BOOL overLimit = NO;
    __block BOOL checkAndIncrement = YES;

    [[[self.mockFrequencyLimitManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void(^callback)(UAFrequencyChecker *) =  (__bridge void (^)(UAFrequencyChecker *))arg;
        callback([UAFrequencyChecker frequencyCheckerWithIsOverLimit:^BOOL{
            return overLimit;
        } checkAndIncrement:^BOOL{
            return checkAndIncrement;
        }]);
    }] getFrequencyChecker:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockInAppMessageManager expect] prepareMessage:message
                                               scheduleID:@"schedule ID"
                                                campaigns:@{@"some": @"campaigns object"}
                                         reportingContext:@{}
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(UAInAppMessagePrepareResult) = obj;
        completionBlock(UAInAppMessagePrepareResultSuccess);
        return YES;
    }]];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];

    [self.engineDelegate prepareSchedule:schedule triggerContext:triggerContext completionHandler:^(UAAutomationSchedulePrepareResult result) {
        XCTAssertEqual(UAAutomationSchedulePrepareResultContinue, result);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];

    // Put checker over the limit
    overLimit = YES;
    checkAndIncrement = NO;

    UAAutomationScheduleReadyResult result = [self.engineDelegate isScheduleReadyToExecute:schedule];

    XCTAssertEqual(UAAutomationScheduleReadyResultSkip, result);

    [self.mockAudienceOverridesProvider verify];
    [self.mockInAppMessageManager verify];
    [self.mockFrequencyLimitManager verify];
}

- (void)testExecuteMessage {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];

    UASchedule *schedule = [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];


    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
}

- (void)testExecuteDeferred {
    UASchedule *schedule = [UADeferredSchedule scheduleWithDeferredData:[UAScheduleDeferredData deferredDataWithURL:[NSURL URLWithString:@"http:/airship.com"]
                                                                                                 retriableOnTimeout:YES]
                                                           builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    [[self.mockInAppMessageManager expect] displayMessageWithScheduleID:@"schedule ID" completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void(^completionBlock)(void) = obj;
        completionBlock();
        return YES;
    }]];

    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockInAppMessageManager verify];
}
/*
- (void)testExecuteActions {
    UASchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"foo": @"bar"} builderBlock:^(UAScheduleBuilder *builder) {
        builder.triggers = @[[UAScheduleTrigger foregroundTriggerWithCount:1]];
        builder.identifier = @"schedule ID";
    }];

    id mockActionRunner = [self mockForClass:[UAActionRunner class]];
    [[mockActionRunner expect] runActionsWithActionValues:schedule.data
                                                situation:UAActionSituationAutomation
                                                 metadata:[OCMArg any]
                                        completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^handler)(UAActionResult *) = obj;
        handler([UAActionResult emptyResult]);
        return YES;
    }]];


    XCTestExpectation *executeFinished = [self expectationWithDescription:@"execute finished"];
    [self.engineDelegate executeSchedule:schedule completionHandler:^{
        [executeFinished fulfill];
    }];

    [self waitForTestExpectations];
    [mockActionRunner verify];
}
*/
- (void)testCancelScheduleWithID {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelScheduleWithID:@"some ID" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelScheduleWithID:@"some ID" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelScheduleWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelMessageSchedulesWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" type:UAScheduleTypeInAppMessage completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelMessageSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testCancelActionSchedulesWithGroup {
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;
        completionHandler(YES);
    }] cancelSchedulesWithGroup:@"some group" type:UAScheduleTypeActions completionHandler:OCMOCK_ANY];

    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation cancelActionSchedulesWithGroup:@"some group" completionHandler:^(BOOL cancelled) {
        XCTAssertTrue(cancelled);
        [blockInvoked fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testSchedule {
    UASchedule *schedule = [[UASchedule alloc] init];

    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        if (completionHandler) {
            completionHandler(YES);
        }
    }] schedule:schedule completionHandler:OCMOCK_ANY];

    // test
    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation schedule:schedule completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [blockInvoked fulfill];
    }];

    // verify
    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testScheduleMultiple {
    UASchedule *scheduleOne = [[UASchedule alloc] init];
    UASchedule *scheduleTwo = [[UASchedule alloc] init];


    // expectations
    [[[self.mockAutomationEngine expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^completionHandler)(BOOL) = (__bridge void (^)(BOOL))arg;

        if (completionHandler) {
            completionHandler(YES);
        }
    }] scheduleMultiple:@[scheduleOne, scheduleTwo] completionHandler:OCMOCK_ANY];

    // test
    XCTestExpectation *blockInvoked = [self expectationWithDescription:@"block invoked"];
    [self.inAppAutomation scheduleMultiple:@[scheduleOne, scheduleTwo] completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [blockInvoked fulfill];
    }];

    // verify
    [self waitForTestExpectations];
    [self.mockAutomationEngine verify];
}

- (void)testComponentEnabled {
    XCTAssertTrue(self.inAppAutomation.componentEnabled);

    // test disable
    [[self.mockAutomationEngine expect] pause];
    self.inAppAutomation.componentEnabled = NO;

    // verify
    XCTAssertFalse(self.inAppAutomation.componentEnabled);
    [self.mockAutomationEngine verify];

    // test enable
    [(UAAutomationEngine *)[self.mockAutomationEngine expect] resume];
    self.inAppAutomation.componentEnabled = YES;

    // verify
    XCTAssertTrue(self.inAppAutomation.componentEnabled);
    [self.mockAutomationEngine verify];
}

- (void)testPrivacyManager {
    [self.inAppAutomation airshipReady];

    // test disable
    [[self.mockAutomationEngine expect] pause];
    [[self.mockRemoteDataClient expect] unsubscribe];

    self.privacyManager.enabledFeatures = UAFeaturesNone;

    [self.mockAutomationEngine verify];
    [self.mockRemoteDataClient verify];

    // test enable
    [(UAAutomationEngine *) [self.mockAutomationEngine expect] resume];
    [[self.mockRemoteDataClient expect] subscribe];

    self.privacyManager.enabledFeatures = UAFeaturesInAppAutomation;

    [self.mockAutomationEngine verify];
    [self.mockRemoteDataClient verify];
}

@end
