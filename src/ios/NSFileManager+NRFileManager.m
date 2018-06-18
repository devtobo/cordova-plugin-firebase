//
//  NRFileManager.m
//  NRFoundation
//
//  Created by Nikolai Ruhe on 2015-02-22.
//  Copyright (c) 2015 Nikolai Ruhe. All rights reserved.
//

#import "NSFileManager+NRFileManager.h"


@implementation NSFileManager (NRFileManager)

- (unsigned long long)calculateCacheSize
{
    unsigned long long totalSize = 0;
    
    NSArray<NSString*> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    for (NSString *path in paths) {
        NSError *error;
        NSURL *url = [NSURL fileURLWithPath:path];
        unsigned long long partialSize = 0;
        if ([self nr_getAllocatedSize:&partialSize ofDirectoryAtURL:url error:&error]) {
            NSLog(@"Cache directory: %@ --> size=%lld error=%@", path, partialSize, error);
            totalSize += partialSize;
        }
    }
    
    NSLog(@"Caches total size: %lld", totalSize);
    return totalSize;
}

- (unsigned long long)calculateDocsSize
{
    unsigned long long totalSize = 0;
    
    NSArray<NSString*> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    for (NSString *path in paths) {
        NSError *error;
        NSURL *url = [NSURL fileURLWithPath:path];
        unsigned long long partialSize = 0;
        if ([self nr_getAllocatedSize:&partialSize ofDirectoryAtURL:url error:&error]) {
            NSLog(@"Document directory: %@ --> size=%lld error=%@", path, partialSize, error);
            totalSize += partialSize;
        }
    }
    
    NSLog(@"Document total size: %lld", totalSize);
    return totalSize;
}
- (unsigned long long)calculateLibrarySize
{
    unsigned long long totalSize = 0;
    
    NSArray<NSString*> *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    for (NSString *path in paths) {
        NSError *error;
        NSURL *url = [NSURL fileURLWithPath:path];
        unsigned long long partialSize = 0;
        if ([self nr_getAllocatedSize:&partialSize ofDirectoryAtURL:url error:&error]) {
            NSLog(@"Library directory: %@ --> size=%lld error=%@", path, partialSize, error);
            totalSize += partialSize;
        }
    }
    
    NSLog(@"Library total size: %lld", totalSize);
    return totalSize;
}

// This method calculates the accumulated size of a directory on the volume in bytes.
//
// As there's no simple way to get this information from the file system it has to crawl the entire hierarchy,
// accumulating the overall sum on the way. The resulting value is roughly equivalent with the amount of bytes
// that would become available on the volume if the directory would be deleted.
//
// Caveat: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
// directories, hard links, ...).

- (BOOL)nr_getAllocatedSize:(unsigned long long *)size ofDirectoryAtURL:(NSURL *)directoryURL error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(size != NULL);
    NSParameterAssert(directoryURL != nil);
    
    // We'll sum up content size here:
    unsigned long long accumulatedSize = 0;
    
    // prefetching some properties during traversal will speed up things a bit.
    NSArray *prefetchedProperties = @[
                                      NSURLIsRegularFileKey,
                                      NSURLFileAllocatedSizeKey,
                                      NSURLTotalFileAllocatedSizeKey,
                                      ];
    
    // The error handler simply signals errors to outside code.
    __block BOOL errorDidOccur = NO;
    __block BOOL errorIsIgnorable = NO;
//    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *url, NSError *localError) {
//        if (error != NULL) {
//            *error = localError;
//        }
//        errorDidOccur = YES;
//        return NO;
//    };
    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *url, NSError *localError) {
        if ([localError.domain isEqualToString:NSCocoaErrorDomain] && localError.code == NSFileReadNoPermissionError) {
            errorIsIgnorable = YES;
            errorDidOccur = YES;
            return YES;
        }
            
        if (error != NULL) {
            *error = localError;
        }
        errorDidOccur = YES;
        return NO;
    };
    
    // We have to enumerate all directory contents, including subdirectories.
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL
                                                             includingPropertiesForKeys:prefetchedProperties
                                                                                options:(NSDirectoryEnumerationOptions)0
                                                                           errorHandler:errorHandler];
    
    // Start the traversal:
    for (NSURL *contentItemURL in enumerator) {
        
        // Bail out on errors from the errorHandler.
        if (errorDidOccur) {
            if (errorIsIgnorable) {
                errorDidOccur = NO;
                errorIsIgnorable = NO;
                continue;
            }
            else {
                return NO;
            }
        }
        
        // Get the type of this item, making sure we only sum up sizes of regular files.
        NSNumber *isRegularFile;
        if (! [contentItemURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:error])
            return NO;
        if (! [isRegularFile boolValue])
            continue; // Ignore anything except regular files.
        
        // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
        // This includes metadata, compression (on file system level) and block size.
        NSNumber *fileSize;
        if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLTotalFileAllocatedSizeKey error:error])
            return NO;
        
        // In case the value is unavailable we use the fallback value (excluding meta data and compression)
        // This value should always be available.
        if (fileSize == nil) {
            if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:error])
                return NO;
            
            NSAssert(fileSize != nil, @"huh? NSURLFileAllocatedSizeKey should always return a value");
        }
        
        // We're good, add up the value.
        accumulatedSize += [fileSize unsignedLongLongValue];
    }
    
    // Bail out on errors from the errorHandler.
    if (errorDidOccur)
        return NO;
    
    // We finally got it.
    *size = accumulatedSize;
    return YES;
}

@end
