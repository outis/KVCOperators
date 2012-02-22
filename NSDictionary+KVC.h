/* @(#)NSDictionary+KVC.h
 * Released under the MIT license.
 * See LICENSE.txt for details.
 */

#ifndef _NSDICTIONARY_KVC_H
#define _NSDICTIONARY_KVC_H 1

#import <Foundation/Foundation.h>

@interface NSDictionary (KVC)
-(id)valueForKeyPath:(NSString*)path;
-(id)anyObject;
@end

#endif /* _NSDICTIONARY_KVC_H */

