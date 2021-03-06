/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 Author: Przemyslaw Zygmunt p.zygmunt@acsoftware.pl [AC SOFTWARE]
 */

#import <CoreData/CoreData.h>

#import "Database.h"
#import "SuplaApp.h"
#import "SAAccessID.h"
#import "SALocation.h"
#import "SAChannel.h"

@implementation SADatabase {
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    NSManagedObjectContext *_managedObjectContext;
}

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"SUPLA" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[SAApp applicationDocumentsDirectory] URLByAppendingPathComponent:@"SUPLA.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    [_managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
    return _managedObjectContext;
}


- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)initSaveObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)releaseSaveObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
}

- (void)managedObjectContextDidSaveNotification:(NSNotification *)n {
    
    if ( _managedObjectContext
        && _managedObjectContext != n.object ) {
        [_managedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:) withObject:n waitUntilDone:NO];
    };
    
}

-(NSArray *) fetchByPredicate:(NSPredicate *)predicate entityName:(NSString*)en limit:(int)l {
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = predicate;
    
    if ( l > 0 ) {
        [fetchRequest setFetchLimit:l];
    }
    
    [fetchRequest setEntity:[NSEntityDescription entityForName:en inManagedObjectContext: self.managedObjectContext]];
    NSError *error = nil;
    NSArray *r = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    if ( error == nil && r.count > 0 ) {
        return r;
    }
    
    return nil;
};

-(id) fetchItemByPredicate:(NSPredicate *)predicate entityName:(NSString*)en {
    
    NSArray *r = [self fetchByPredicate:predicate entityName:en limit:1];
    if ( r != nil && r.count > 0 ) {
        return [r objectAtIndex:0];
    }
    
    return nil;
};

#pragma mark AccessIDs

-(SAAccessID*) fetchAccessID:(int)access_id serverName:(NSString*)server {
    
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"access_id = %i AND server_name = %@", access_id, server] entityName:@"SAAccessID"];
}

-(SAAccessID*)getCurrentAccessID {
   
    int aid = [SAApp getAccessID];
    NSString *server_name = [SAApp getServerHostName];
    
    SAAccessID *AccessID = [self fetchAccessID:aid serverName:server_name];
    
    if ( AccessID == nil ) {
        
        AccessID = [[SAAccessID alloc] initWithEntity:[NSEntityDescription entityForName:@"SAAccessID" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
        
        AccessID.access_id = [NSNumber numberWithInt:aid];
        AccessID.server_name = server_name;
        [self.managedObjectContext insertObject:AccessID];
        [self saveContext];
    }
    
    return AccessID;
}

#pragma mark Locations

-(SALocation*) fetchLocationById:(int)location_id {
    
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"location_id = %i", location_id] entityName:@"SALocation"];
};

-(SALocation*) newLocation {
    
    SAAccessID *aid = [self getCurrentAccessID];
    
    SALocation *Location = [[SALocation alloc] initWithEntity:[NSEntityDescription entityForName:@"SALocation" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
    Location.accessid = aid;
    Location.location_id = [NSNumber numberWithInt:0];
    Location.caption = @"";
    [Location setLocationVisible:0];
    [self.managedObjectContext insertObject:Location];
    
    return Location;
}

-(BOOL) updateLocation:(TSC_SuplaLocation *)location {
    
    BOOL save = NO;
    
    SALocation *Location = [self fetchLocationById:location->Id];
    if ( Location == nil ) {
        Location = [self newLocation];
        Location.location_id = [NSNumber numberWithInt:location->Id];
        save = YES;
    }
    
    if ( [Location setLocationCaption:location->Caption] ) {
        save = YES;
    }
    
    if ( [Location setLocationVisible:1] ) {
        save = YES;
    }
    
    if ( save == YES ) {
        [self saveContext];
    }
    
    return save;
}

#pragma mark Channels

-(SAChannel*) fetchChannelById:(int)channel_id {
    
    return [self fetchItemByPredicate:[NSPredicate predicateWithFormat:@"channel_id = %i", channel_id] entityName:@"SAChannel"];
};

-(SAChannel*) newChannel {
    
    SAChannel *Channel = [[SAChannel alloc] initWithEntity:[NSEntityDescription entityForName:@"SAChannel" inManagedObjectContext:self.managedObjectContext] insertIntoManagedObjectContext:self.managedObjectContext];
    
    Channel.caption = @"";
    Channel.channel_id = [NSNumber numberWithInt:0];
    Channel.func = [NSNumber numberWithInt:0];
    Channel.online = [NSNumber numberWithBool:NO];
    Channel.visible = [NSNumber numberWithInt:1];

    [self.managedObjectContext insertObject:Channel];
    
    return Channel;
}


-(BOOL) updateChannel:(TSC_SuplaChannel *)channel {
    
    BOOL save = NO;
    
    SALocation *Location = [self fetchLocationById:channel->LocationID];
    
    if ( Location == nil )
        return NO;
    
    SAChannel *Channel = [self fetchChannelById:channel->Id];
    
    if ( Channel == nil ) {
        
        Channel = [self newChannel];
        Channel.channel_id = [NSNumber numberWithInt:channel->Id];
        save = YES;
    }
    

    if ( [Channel setChannelLocation:Location] ) {
        save = YES;
    }

    if ( [Channel setChannelFunction:channel->Func] ) {
        save = YES;
    }

    if ( [Channel setChannelOnline:channel->online] ) {
        save = YES;
    }
    
    if ( [Channel setChannelValue:&channel->value] ) {
        save = YES;
    }

    
    if ( [Channel setChannelCaption:channel->Caption] ) {
        save = YES;
    }
    
    if ( [Channel setChannelVisible:1] ) {
        save = YES;
    }
    
    if ( save == YES ) {
        [self saveContext];
    }
    
    return save;
}

-(BOOL) updateChannelValue:(TSC_SuplaChannelValue *)channel_value {
 
    BOOL save = NO;
    SAChannel *Channel = [self fetchChannelById:channel_value->Id];
    
    if ( Channel != nil ) {
        
        if ( [Channel setChannelOnline:channel_value->online] ) {
            save = YES;
        }
        
        if ( [Channel setChannelValue:&channel_value->value] ) {
            save = YES;
        }
        
    }
    
    if ( save == YES ) {
        [self saveContext];
    }
    
    return save;
    
}

-(NSFetchedResultsController*) getChannelFrc {
    
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"func > 0 AND visible > 0"];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"SAChannel" inManagedObjectContext: self.managedObjectContext]];
    
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:[[NSSortDescriptor alloc] initWithKey:@"location.caption" ascending:YES],
                                    [[NSSortDescriptor alloc] initWithKey:@"func" ascending:NO],
                                    [[NSSortDescriptor alloc] initWithKey:@"caption" ascending:NO],
                                    nil];
    
       [fetchRequest setSortDescriptors:sortDescriptors];

       NSFetchedResultsController *frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"location.caption" cacheName:nil];

    NSError *error;
    [frc performFetch:&error];
    
    if ( error ) {
        NSLog(@"%@", error);
    }
   
    return frc;
}

-(BOOL) setChannelsOffline {
    
    NSArray *r = [self fetchByPredicate:[NSPredicate predicateWithFormat:@"online = YES"] entityName:@"SAChannel" limit:0];
    BOOL save = NO;
    
    if ( r != nil ) {
        for(int a=0;a<r.count;a++) {
            if ( [[r objectAtIndex:a] setChannelOnline:0] ) {
                save = YES;
            }
        }
    }
    
    if ( save ) {
        [self saveContext];
    }
    
    return save;
}

-(BOOL) setChannelsVisible:(int)visible WhereVisibilityIs:(int)wvi {
 
    NSArray *r = [self fetchByPredicate:[NSPredicate predicateWithFormat:@"visible = %i", wvi] entityName:@"SAChannel" limit:0];
    BOOL save = NO;
    
    if ( r != nil ) {
        for(int a=0;a<r.count;a++) {
            if ( [[r objectAtIndex:a] setChannelVisible:visible] ) {
                save = YES;
            }
        }
    }
    
    if ( save ) {
        [self saveContext];
    }
    
    return save;
    
}

@end
