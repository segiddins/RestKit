//
//  RKConfig.m
//  RestKit
//
//  Created by Samuel E. Giddins on 8/5/13.
//  Copyright (c) 2013 RestKit. All rights reserved.
//

#import "RKConfig.h"
#import "RestKit.h"

@interface AFHTTPClient ()

@property (readwrite) NSURL *baseURL;

@end

@interface RKConfig ()

@property (nonatomic, strong) NSMutableDictionary *mappings;

@property (nonatomic, strong) NSMutableArray *responseDescriptors;

@property (nonatomic, strong) NSMutableArray *requestDescriptors;

@property (nonatomic, strong) RKObjectManager *manager;

@property (nonatomic, strong) NSDictionary *dictionary;

@end

static RKRequestMethod RKConfigRequestMethodFromString(NSString *methodString)
{
    NSString *uppercaseString = [methodString uppercaseString];
    if (!uppercaseString || [uppercaseString isEqualToString:@"ANY"]) return RKRequestMethodAny;
    else return RKRequestMethodFromString(uppercaseString);
}

@implementation RKConfig

+ (instancetype)configurationWithContentsOfURL:(NSURL *)configurationURL error:(NSError *__autoreleasing *)error
{
    RKConfig *config = [[self alloc] initWithContentsOfURL:configurationURL error:error];
    return config;
}

+ (instancetype)configurationWithDictionary:(NSDictionary *)dictionary
{
    RKConfig *config = [[self alloc] init];
    config.dictionary = dictionary;
    return config;
}

- (instancetype)initWithContentsOfURL:(NSURL *)configurationURL error:(NSError **)error
{
    if (self = [self init]) {
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:configurationURL];
        AFJSONRequestOperation *op = [[AFJSONRequestOperation alloc] initWithRequest:request];
        [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            self.dictionary = responseObject;
        } failure:^(AFHTTPRequestOperation *operation, NSError *operationError) {
            if (error) *error = operationError;
        }];
        [op start];
    }
    return self;
}

- (id)init
{
    if (self = [super init])
    {
        _mappings = [NSMutableDictionary dictionary];
        _responseDescriptors = [NSMutableArray array];
        _requestDescriptors = [NSMutableArray array];
    }
    return self;
}

- (BOOL)configureManager:(RKObjectManager *)manager error:(NSError *__autoreleasing *)error
{
    self.manager = manager;
    
    [self configureManager];
    [self parseMappings];
    [self parseResponseDescriptors];
    [self parseRequestDescriptors];
    
    if (error && !*error) return NO;
    
    [self.manager addRequestDescriptorsFromArray:self.requestDescriptors];
    [self.manager addResponseDescriptorsFromArray:self.responseDescriptors];
    
    return !(error && !*error);
}

- (void)parseMappings
{
    NSDictionary *mappingsDicts = self.dictionary[@"mappings"];
    [mappingsDicts enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *className = obj[@"@class"];
        Class class = className ? NSClassFromString(className) : Nil;
        NSString *entityName = obj[@"@entity"];
        NSEntityDescription *entity = entityName ? [NSEntityDescription entityForName:entityName inManagedObjectContext:self.manager.managedObjectStore.mainQueueManagedObjectContext] : nil;
        RKObjectMapping *mapping;
        if (class) {
            mapping = [RKObjectMapping mappingForClass:class];
        } else if (entity) {
            mapping = [RKEntityMapping mappingForEntityForName:entity.name inManagedObjectStore:self.manager.managedObjectStore];
        }
        if (mapping) [self.mappings setObject:mapping forKey:key];
    }];
    [mappingsDicts enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self configureMapping:self.mappings[key] fromDictionary:obj];
    }];
}

- (void)parseResponseDescriptors
{
    for (NSDictionary *dictionary in self.dictionary[@"response_descriptors"]) {
        RKResponseDescriptor *descriptor = [self configureResponseDescriptorFromDictionary:dictionary];
        if (descriptor) [self.responseDescriptors addObject:descriptor];
    }
}

- (void)parseRequestDescriptors
{
    for (NSDictionary *dictionary in self.dictionary[@"request_descriptors"]) {
        RKRequestDescriptor *descriptor = [self configureRequestDescriptorFromDictionary:dictionary];
        if (descriptor) [self.requestDescriptors addObject:descriptor];
    }
}

- (void)configureManager
{
    NSString *URLString = self.dictionary[@"base_url"];
    if (!URLString) return;
    NSURL *baseURL = [NSURL URLWithString:URLString];
    self.manager.HTTPClient.baseURL = baseURL;
}

- (void)configureMapping:(RKObjectMapping *)mapping fromDictionary:(NSDictionary *)dictionary
{
    if ([mapping respondsToSelector:@selector(setIdentificationAttributes:)]) {
        [(RKEntityMapping *)mapping setIdentificationAttributes:dictionary[@"@identificationAttributes"]];
    }
    
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (![key hasPrefix:@"@"] && [obj isKindOfClass:[NSString class]]) {
            [mapping addPropertyMapping:[RKAttributeMapping attributeMappingFromKeyPath:key toKeyPath:obj]];
        }
    }];
    
    [dictionary[@"@relationships"] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
        RKRelationshipMapping *relationshipMapping = [RKRelationshipMapping relationshipMappingFromKeyPath:key toKeyPath:obj[@"key_path"] withMapping:self.mappings[obj[@"mapping"]]];
        [mapping addPropertyMapping:relationshipMapping];
    }];
}

- (RKResponseDescriptor *)configureResponseDescriptorFromDictionary:(NSDictionary *)dictionary
{
    RKObjectMapping *mapping = self.mappings[dictionary[@"mapping"]];
    RKRequestMethod method = RKConfigRequestMethodFromString(dictionary[@"method"]);
    NSString *pathPattern = dictionary[@"path"];
    NSString *keyPath = dictionary[@"key_path"];
    NSIndexSet *statusCodes = RKStatusCodeIndexSetForClass([dictionary[@"status"] unsignedIntegerValue] ?: RKStatusCodeClassSuccessful);
    
    RKResponseDescriptor *descriptor = [RKResponseDescriptor responseDescriptorWithMapping:mapping method:method pathPattern:pathPattern keyPath:keyPath statusCodes:statusCodes];
    return descriptor;
}

- (RKRequestDescriptor *)configureRequestDescriptorFromDictionary:(NSDictionary *)dictionary
{
    NSString *mappingString = dictionary[@"mapping"];
    RKObjectMapping *mapping = ({
        RKObjectMapping *mapping;
        NSArray *components = [mappingString componentsSeparatedByString:@"."];
        if ([[components lastObject] isEqual:@"@inverse"]) {
            mapping = [self.mappings[components[0]] inverseMapping];
        } else {
            mapping = self.mappings[components[0]];
        }
        mapping;
    });
    Class class = [NSMutableDictionary class];
    NSString *keyPath = dictionary[@"key_path"];
    RKRequestMethod method = RKConfigRequestMethodFromString(dictionary[@"method"]);
    
    RKRequestDescriptor *descriptor = [RKRequestDescriptor requestDescriptorWithMapping:mapping objectClass:class rootKeyPath:keyPath method:method];
    return descriptor;
}

@end
