//
//  RKConfigTest.m
//  RestKit
//
//  Created by Samuel E. Giddins on 8/7/13.
//  Copyright (c) 2013 RestKit. All rights reserved.
//

#import "RKTestEnvironment.h"
#import "RKConfig.h"

@interface RKConfigTest : RKTestCase

@end

@implementation RKConfigTest

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testBasicDictionaryConfig
{
    NSDictionary *dictionary =
  @{
    @"base_url" : @"http://restkit.org/api/",
    @"mappings" : @{
            @"child" : @{
                    @"@entity" : @"Child",
                    @"id" : @"railsID",
                    @"name" : @"name",
                    @"favorite_colors" : @"favoriteColors",
                    @"@relationships" :
                        @{@"parents": @{@"key_path" : @"parents", @"mapping" : @"child"}},
                    @"identification_attributes" : @[@"railsID"],
                    },
            },
    @"response_descriptors" : @[
                @{
                    @"path" : @"people/:railsID",
                    @"mapping" : @"child",
                    @"method" : @"any",
                },
            ],
    @"request_descriptors" : @[
                @{
                    @"mapping" : @"child.@inverse",
                    @"method" : @"POST",
                }
            ]
    };
    RKConfig *config = [RKConfig configurationWithDictionary:dictionary];
    expect(config).toNot.beNil();
    
    RKObjectManager *objectManager = [RKTestFactory objectManager];
    objectManager.managedObjectStore = [RKTestFactory managedObjectStore];
    
    [config configureManager:objectManager error:nil];
    expect(objectManager.requestDescriptors).to.haveCountOf(1);
    expect(objectManager.responseDescriptors).to.haveCountOf(1);
    
    RKEntityMapping *childMapping = [RKEntityMapping mappingForEntityForName:@"Child" inManagedObjectStore:objectManager.managedObjectStore];
    [childMapping addAttributeMappingsFromDictionary:
  @{
    @"id" : @"railsID",
    @"name" : @"name",
    @"favorite_colors" : @"favoriteColors",
    }];
    [childMapping addRelationshipMappingWithSourceKeyPath:@"parents" mapping:childMapping];
    childMapping.identificationAttributes = @[@"railsID"];
    
    RKResponseDescriptor *childResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:childMapping method:RKRequestMethodAny pathPattern:@"people/:railsID" keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    RKResponseDescriptor *parsedResponseDescriptor = objectManager.responseDescriptors[0];
    expect(parsedResponseDescriptor).to.equal(childResponseDescriptor);
    
    RKRequestDescriptor *childRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:[childMapping inverseMapping] objectClass:[NSMutableDictionary class] rootKeyPath:nil method:RKRequestMethodPOST];

    RKRequestDescriptor *parsedRequestDescriptor = objectManager.requestDescriptors[0];
    expect(parsedRequestDescriptor).to.equal(childRequestDescriptor);
}

@end
