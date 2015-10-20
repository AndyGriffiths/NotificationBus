//
//  NotifcationBus.h
//
//  Created by Andrew Griffiths on 15/10/15.
//  Copyright © 2015 Andrew Griffiths. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Subscription : NSObject

-(id _Nullable) initWithMethodName:(NSString * _Nonnull) methodName;
-(BOOL) canAddReference:(id _Nonnull) theObject;
-(void) addReference:(_Nullable id) reference;
-(BOOL) hasAnySubscriptions;
-(void) callMethodOnReferencesWithObject:(id _Nonnull) object;
@end

@interface NotificationBus : NSObject

+ (_Nullable id) sharedNotificationBus;
-(void) addMappingForNotificationType:(NSString * _Nonnull) messageType toMethodName:(NSString * _Nonnull) methodName;
-(void) subscribe:(id _Nonnull) theObject toNotificationTypes:(NSArray * _Nonnull) NotificationTypes;
@end
