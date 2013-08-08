//
//  RKConfig.h
//  RestKit
//
//  Created by Samuel E. Giddins on 8/5/13.
//  Copyright (c) 2013 RestKit. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectManager;

@interface RKConfig : NSObject

+ (instancetype)configurationWithContentsOfURL:(NSURL *)configurationURL error:(NSError **)error;

+ (instancetype)configurationWithDictionary:(NSDictionary *)dictionary;

- (BOOL)configureManager:(RKObjectManager *)manager error:(NSError **)error;

@end
