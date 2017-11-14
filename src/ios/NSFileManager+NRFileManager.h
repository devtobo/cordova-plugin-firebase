//
//  NSFileManager+NSFileManager_NRFileManager_m.h
//  La croix
//
//  Created by Thomas Brian on 2017-11-13.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (NRFileManager)

- (unsigned long long)calculateCacheSize;
- (unsigned long long)calculateDocsSize;
- (unsigned long long)calculateLibrarySize;

- (BOOL)nr_getAllocatedSize:(unsigned long long *)size ofDirectoryAtURL:(NSURL *)directoryURL error:(NSError * __autoreleasing *)error;


@end
