//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//


#ifdef __OBJC__
    #import <Foundation/Foundation.h>

    // #define MY_DEBUG 1
    #ifdef MY_DEBUG
    #    define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
    #else
    #    define DLog(...)
    #endif

    // ALog always displays output regardless of the DEBUG setting
    #define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);


//#import "AssimpImageCache.h"
//#import "PostProcessingFlags.h"
//#import "SCNAssimpAnimation.h"
//#import "SCNNode+AssimpImport.h"
////#import "SCNTextureInfo.h"
//#import "AssimpImporter.h"
//#import "SCNAssimpAnimSettings.h"
//#import "SCNAssimpScene.h"
//#import "SCNScene+AssimpImport.h"


#endif
