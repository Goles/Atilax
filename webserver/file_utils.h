//
//  helper.h
//  lalo
//
//  Created by Nicolas Goles on 6/20/11.
//  Copyright 2011 GandoGames. All rights reserved.
//

#ifndef __FILE_UTILS_H__
#define __FILE_UTILS_H__

static const NSString * fullPathFromRelativePath(NSString *relPath)
{
    @autoreleasepool 
    {
        // do not convert a path starting with '/'
        if(([relPath length] > 0) && ([relPath characterAtIndex:0] == '/'))
            return relPath;
        
        NSMutableArray *imagePathComponents = [NSMutableArray arrayWithArray:[relPath pathComponents]];

        NSString *file = [imagePathComponents lastObject];    
        [imagePathComponents removeLastObject];
        
        NSString *imageDirectory = [NSString pathWithComponents:imagePathComponents];
            
        NSString *fullpath = [[NSBundle mainBundle] pathForResource:file
                                                             ofType:NULL
                                                        inDirectory:imageDirectory];
        if (!fullpath)
            fullpath = relPath;

        
        return fullpath;
    }
}

static const char * relativeCPathForFile(const char *fileName)
{
    @autoreleasepool 
    {
        NSString *relPath = [NSString stringWithCString:fileName encoding:NSUTF8StringEncoding];        
        const NSString *path = fullPathFromRelativePath(relPath);
        const char *c_path = [[path stringByDeletingLastPathComponent] UTF8String];    
        return c_path;
    }
}

static const char * fullCPathFromRelativePath(const char *cPath)
{
    NSString *relPath = [NSString stringWithCString:cPath encoding:NSUTF8StringEncoding];
    const  NSString *path = fullPathFromRelativePath(relPath);
    const char *c_path = [path UTF8String];
    return c_path;
}

#endif
