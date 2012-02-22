/* @(#)NSDictionary+KVC.m
 * Released under the MIT license.
 * See LICENSE.txt for details.
 */

#import <JRSwizzle.h>
/*
#import "NSDictionary+KVC.h"
/*/
#import <Foundation/Foundation.h>

@interface NSDictionary(KVC)
-(id)other_valueForKeyPath:(NSString*)path;
@end
/**/

#if OBJC_API_VERSION >= 2
#  define FOREACH(ITEM,ITEMS)		  \
	for (id key in ITEMS) {			  \
        id ITEM=[self objectForKey:key];
#  define FORBLOCK(block)			  \
		block;						  \
    }
#else
#  define FOREACH(ITEM,ITEMS)							\
	NSEnumerator objects = [ITEMS objectEnumerator];	\
	id ITEM; \
	while ((ITEM = [objects nextObject]))
#  define FORBLOCK(block) { \
		block; \
    }
#endif

@implementation NSDictionary (KVC)
#if defined(__GNUC__)
__attribute__((constructor))
static void init_NSDictionary_KVC() {
	[NSDictionary jr_swizzleMethod:@selector(valueForKeyPath:) withMethod:@selector(other_valueForKeyPath:) error:NULL];
}
#else // !defined(__GNUC__)
/*
#  if __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ < 1040
#    warning "+[NSDictionary(KVC) load] may not be called before NSObject(JRSwizzle) is loaded."
#  else
*/
#    warning "+[NSDictionary(KVC) load] may not be called before NSObject(JRSwizzle) is loaded."
+(void)load {
	[self jr_swizzleMethod:@selector(valueForKeyPath:) withMethod:@selector(other_valueForKeyPath:) error:NULL];
}
//#  endif
#endif // !defined(__GNUC__)

-(id)other_valueForKeyPath:(NSString*)path {
	NSRange division = [path rangeOfString:@"."];
	if ([path hasPrefix:@"@"]) {
		NSRange start = {1, division.location-1};
		NSString *rest, *kvc_op_str;
		SEL kvc_op;

		if (division.location == NSNotFound) {
			start.length=[path length]-1;
			// first, try for a nullary kvc operator
			kvc_op_str = [[NSString alloc] initWithFormat:@"_kvc_operator_%@",[path substringFromIndex:1]];
			kvc_op = NSSelectorFromString(kvc_op_str);
			[kvc_op_str release];
			if ([self respondsToSelector:kvc_op]) {
				return [self performSelector:kvc_op];
			}
			// nope, so go on to a unary kvc operator 
			rest=nil;
		} else {
			rest=[path substringFromIndex:division.location+1];
		}
		kvc_op_str = [[NSString alloc] initWithFormat:@"_kvc_operator_%@:",[path substringWithRange:start]];
		kvc_op = NSSelectorFromString(kvc_op_str);
		[kvc_op_str release];
		if ([self respondsToSelector:kvc_op]) {
			return [self performSelector:kvc_op withObject:rest];
		}
		/* if this object doesn't support the operator, rely on default behavior of valueForKey:
		   (which is to strip the '@' and call super's `valueForKey`).
		 */
	}
	/*
	id value;
	if (division.location == NSNotFound) {
		if (nil == path || [path length] == 0) {
			value = self;
		} else {
			value = [self valueForKey:path];
		}
	} else {
		value = [[self valueForKey:[path substringToIndex:division.location]] 
					   valueForKeyPath:[path substringFromIndex:division.location+1]];
	}
	return value;
	*/
	return [self other_valueForKeyPath:path];
}

-(id)anyObject {
#if OBJC_API_VERSION >= 2
	// the docs say "It is more efficient to use the fast enumeration protocol".
	// Is it in this case?
	for (id key in self) {
		return [self objectForKey:key];
	}
#else
	NSEnumerator *pobj = [self objectEnumerator];
	return [pobj nextObject];
#endif
}

-(id)_someUnionOfObjects:(id)items {
	FOREACH(item,self)
		FORBLOCK([items addObject:item]);
/*
#if OBJC_API_VERSION >= 2
	for (id key in self) {
		[items addObject:[self objectForKey:key]];
	}
#else
	FOREACH(item,self) {
		[items addObject:item];
	}
#endif
*/
	return items;
}

-(id)_someUnionOfArrays:(id)items {
#if OBJC_API_VERSION >= 2
	for (id key in self) {
		[items addObjectsFromArray:[self objectForKey:key]];
	}
#else
	FOREACH(item,self) {
		[items addObjectsFromArray:item];
	}
#endif
	return items;
}

-(id)_someUnionOfObjects:(id)items withPath:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _someUnionOfObjects:items];
	} else {
#if OBJC_API_VERSION >= 2
		for (id key in self) {
			[items addObject:[[self objectForKey:key] valueForKeyPath:path]];
		}
#else
		FOREACH(item,items) {
			[items addObject:[item valueForKeyPath:path]];
		}
#endif
		return items;
	}
}

-(id)_someUnionOfArrays:(id)items withPath:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _someUnionOfArrays:items];
	} else {
#if OBJC_API_VERSION >= 2
		for (id key in self) {
			// could be an NSMutableSet, but both support -addObjectsFromArrays:
			[(NSMutableArray*)items addObjectsFromArray:[[self objectForKey:key] valueForKeyPath:path]];
		}
#else
		FOREACH(item,self) {
			// could be an NSMutableSet, but both support -addObjectsFromArrays:
			[(NSMutableArray*)items addObjectsFromArray:[item valueForKeyPath:path]]
		}
#endif
		return items;
	}
}

-(id)_kvc_operator_distinctUnionOfObjects {
	return [[self _someUnionOfObjects:[NSMutableSet setWithCapacity:[self count]]] 
			   allObjects];
}

-(id)_kvc_operator_distinctUnionOfObjects:(NSString*)path {
	return [[self _someUnionOfObjects:[NSMutableSet setWithCapacity:[self count]] withPath:path] 
			   allObjects];
}

-(id)_kvc_operator_unionOfObjects {
	return [self allValues];
}

-(id)_kvc_operator_unionOfObjects:(NSString*)path {
	return [self _someUnionOfObjects:[NSMutableArray arrayWithCapacity:[self count]] withPath:path];
}


-(id)_kvc_operator_distinctUnionOfArrays {
	return [[self _someUnionOfArrays:[NSMutableSet setWithCapacity:[self count]]] 
			   allObjects];
}

-(id)_kvc_operator_distinctUnionOfArrays:(NSString*)path {
	return [[self _someUnionOfArrays:[NSMutableSet setWithCapacity:[self count]] withPath:path] 
			   allObjects];
}

-(id)_kvc_operator_unionOfArrays {
	return [self _someUnionOfArrays:[NSMutableArray arrayWithCapacity:[self count]]];
}

-(id)_kvc_operator_unionOfArrays:(NSString*)path {
	return [self _someUnionOfArrays:[NSMutableArray arrayWithCapacity:[self count]] withPath:path];
}


-(id)_kvc_operator_avg {
	long double avg=0;
	long double count = [self count];
#if OBJC_API_VERSION >= 2
	for (id key in self) {
		avg += [[self objectForKey:key] doubleValue] / count;
	}
#else
	FOREACH(item,self) {
		avg += [item doubleValue] / count;
	}
#endif
	return [NSNumber numberWithDouble:avg];
}

-(id)_kvc_operator_avg:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _kvc_operator_avg];
	} else {
		long double count = [self count];
		long double avg=0;
#if OBJC_API_VERSION >= 2
		for (id key in self) {
			avg += [[[self objectForKey:key] valueForKeyPath:path] doubleValue] / count;
		}
#else
		FOREACH(item,self) {
			avg += [[item valueForKeyPath:path] doubleValue] / count;
		}
#endif
		return [NSNumber numberWithDouble:avg];
	}
}


-(id)_kvc_operator_count:(NSString*)path {
	return [NSNumber numberWithUnsignedInt: [self count]];
}

-(id)_kvc_operator_min {
	id smallest=[self anyObject],
		item;
#if OBJC_API_VERSION >= 2
	for (id key in self) 
#else
	FOREACH(item,self)
#endif
	{
#if OBJC_API_VERSION >= 2
		item = [self objectForKey:key];
#endif
		if ([smallest compare:item] > 0) {
			smallest = item;
		}
	}
	return smallest;
}

-(id)_kvc_operator_min:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _kvc_operator_min];
	} else {
		id smallest=[[self anyObject] valueForKeyPath:path],
			item;
#if OBJC_API_VERSION >= 2
		for (id key in self) 
#else
		FOREACH(item,self)
#endif
		{
#if OBJC_API_VERSION >= 2
			item=[[self objectForKey:key] valueForKeyPath:path];
#endif
			if ([smallest compare:item] > 0) {
				smallest = item;
			}
		}
		return smallest;
	}
}

-(id)_kvc_operator_max {
	id biggest=[self anyObject],
		item;
#if OBJC_API_VERSION >= 2
	for (id key in self) 
#else
	FOREACH(item,self)
#endif
	{
#if OBJC_API_VERSION >= 2
		item = [self objectForKey:key];
#endif
		if ([biggest compare:item] < 0) {
			biggest = item;
		}
	}
	return biggest;
}

-(id)_kvc_operator_max:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _kvc_operator_max];
	} else {
		id biggest=[[self anyObject] valueForKeyPath:path],
			item;
#if OBJC_API_VERSION >= 2
		for (id key in self) 
#else
		FOREACH(item,self)
#endif
		{
#if OBJC_API_VERSION >= 2
			item=[[self objectForKey:key] valueForKeyPath:path];
#endif
			if ([biggest compare:item] < 0) {
				biggest = item;
			}
		}
		return biggest;
	}
}

-(id)_kvc_operator_sum {
	double sum=0;
#if OBJC_API_VERSION >= 2
	for (id key in self) {
		sum += [[self objectForKey:key] doubleValue];
	}
#else
	FOREACH(item,self) {
		sum += [item doubleValue];
	}
#endif
	return [NSNumber numberWithDouble:sum];
}

-(id)_kvc_operator_sum:(NSString*)path {
	if (path == nil || [path length]==0) {
		return [self _kvc_operator_sum];
	} else {
		double sum=0;
#if OBJC_API_VERSION >= 2
		for (id key in self) {
			sum += [[[self objectForKey:key] valueForKeyPath:path] doubleValue];
		}
#else
		FOREACH(item,self) {
			sum += [[item valueForKeyPath:path] doubleValue];
		}
#endif
		return [NSNumber numberWithDouble:sum];
	}
}

@end
