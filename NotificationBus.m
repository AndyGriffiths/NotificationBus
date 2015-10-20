//
//  NotifcationBus.m
//
//  Created by Andrew Griffiths on 15/10/15.
//  Copyright © 2015 Andrew Griffiths. All rights reserved.
//

#import "NotificationBus.h"

@interface Subscription ()
@property(nonatomic, strong) NSHashTable * _Nonnull objectReferences;
@property(nonatomic, strong) NSString * _Nonnull methodName;
@end

@implementation Subscription

-(id) initWithMethodName:(NSString *) methodName
{
    self = [super init];
    if (self)
    {
        _objectReferences = [NSHashTable weakObjectsHashTable];
        _methodName = [methodName copy];
    }
    return self;
}
-(BOOL) canAddReference:(id _Nonnull) theObject
{
    SEL theSelector = NSSelectorFromString(self.methodName);
    
    if ( [theObject respondsToSelector:theSelector])
        return YES;
    
    return NO;
}
-(void) addReference:(_Nullable id) reference
{
    @synchronized(self.objectReferences)   {
        [self.objectReferences addObject:reference];
    }
}
-(void) cleanUp
{
    // think this will happen automatically, sweet
    return;
    
    //delete any NULL references
    @synchronized(self.objectReferences) {
        NSHashTable * newObjectReferences = [NSHashTable weakObjectsHashTable];
        for (id reference in self.objectReferences)
        {
            if (reference != NULL)
                [newObjectReferences addObject:reference];
        }
        
        self.objectReferences = newObjectReferences;
        
    }
}
-(void) callMethodOnReferencesWithObject:(id) object
{
    SEL selector = NSSelectorFromString(self.methodName);
    for (id reference in self.objectReferences)
    {
        if (reference != NULL && [reference respondsToSelector:selector])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                IMP imp = [reference methodForSelector:selector];
                void (*func)(id, SEL, id) = (void *)imp;
                func(reference, selector, object);
            });

        }
    }
}
-(BOOL) hasAnySubscriptions
{
    // make sure we are cleaned up here
    [self cleanUp];
    
    BOOL hasSubscriptions = NO;
    for (id reference in self.objectReferences)
    {
        if (reference != NULL)
            hasSubscriptions = YES;
    }
    
    // appropriate place to clean up here
    [self cleanUp];
    return hasSubscriptions;
}
@end
@interface NotificationBus ()
@property(nonatomic, strong) NSMutableDictionary * _Nonnull methodMappings;
@property(nonatomic, strong) NSMutableDictionary * _Nonnull notificationSubscriptions;
@end

@implementation NotificationBus


//Singleton method
+ (_Nullable id) sharedNotificationBus
{
    static NotificationBus * sharedNotificationBus = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // create and configure the service
        sharedNotificationBus = [[self alloc] init];
    });
    return sharedNotificationBus;
}

-(id) init
{
    self = [super init];
    if (self)
    {
        _methodMappings = [NSMutableDictionary dictionary];
        _notificationSubscriptions = [NSMutableDictionary dictionary];
    }
    
    return self;
}
-(void) addMappingForNotificationType:(NSString * _Nonnull) notificationType toMethodName:(NSString * _Nonnull) methodName
{
    // we only support one method name per mapping at the moment
    Subscription * newSubscription = [[Subscription alloc] initWithMethodName:methodName];
    [self.methodMappings setObject:newSubscription forKey:notificationType];
}
-(void) subscribe:(id _Nonnull) theObject toNotificationTypes:(NSArray *) notificationTypes
{
    for (NSString * notificationType in notificationTypes)
    {
        // get the subscription details
        Subscription * subscription = self.methodMappings[notificationType];
        
        // check we have this mapping
        if (subscription == nil)
            continue;
        
        //does this object define the selector used
        if ([subscription canAddReference:theObject] == NO)
            return;
        
        // okay, all looks okay, add the object to the subscription
        [subscription addReference:theObject];
        
        // and subscribe ourselves, if needed
        NSNumber * present = self.notificationSubscriptions[notificationType];
        
        if (!present)
        {
            // subscribe
            [self addSelfAsObserverOfNotificationType:notificationType];
        }

    }
    
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) addSelfAsObserverOfNotificationType:(NSString *) notificationType
{
    // subscribe
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notify:)
                                                 name:notificationType
                                               object:nil];
    
    //add to our list
    @synchronized(self.notificationSubscriptions) {
        self.notificationSubscriptions[notificationType] = [NSNumber numberWithBool:YES];
    }
    
}
-(void) removeSelfAsObserverOfNotificationType:(NSString *) notificationType
{
    // subscribe
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationType object:nil];
    
    //add to our list
    @synchronized(self.notificationSubscriptions) {
        [self.notificationSubscriptions removeObjectForKey:notificationType];
    }
    
}
-(void)notify:(NSNotification *) notif
{
    // okay, we have a notification, let's pass this on to our clients
    NSString * notificationType = notif.name;
    
    // do we have any subscriptions for this
    Subscription * subscription = self.methodMappings[notificationType];
    
    if (! subscription || subscription.hasAnySubscriptions != YES)
    {
        // we have no subscriptions for this, remove ourselves as observers.
        [self removeSelfAsObserverOfNotificationType:notificationType];
    }
    else
    {
        // call the references
        [subscription callMethodOnReferencesWithObject:notif];
    }
    

    
}
@end
