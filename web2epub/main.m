//
//  main.m
//  web2epub
//

#import <Foundation/Foundation.h>
#import "GDataXMLNode.h"

NSString *template =
@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
"<!DOCTYPE html><html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2011/epub\" lang=\"en\" xml:lang=\"en\">"
"<head>"
"<title>The title</title>"
"<style type=\"text/css\">"
"nav#landmarks { display:none; }"
"</style>"
"</head>"
"<body>"
"<nav epub:type=\"landmarks\" id=\"landmarks\" hidden=\"\">"
"<h2>Guide</h2>"
"<ol>"
"<li><a epub:type=\"bodymatter\" href=\"part0003.xhtml\">Start Here</a></li>"
"<li><a epub:type=\"toc\" href=\"part0001.xhtml\">Table of Contents</a></li>"
"<li><a epub:type=\"cover\" href=\"cover_page.xhtml\">Cover</a></li>"
"</ol>"
"</nav>"
"<nav epub:type=\"toc\" id=\"toc\">"
"<h1>Table of contents</h1>"
"</nav>"
"</body>"
"</html>";


@implementation NSString (JRAdditions)

+ (BOOL)isStringEmpty:(NSString *)string {
	if([string length] == 0) { //string is empty or nil
		return YES;
	}

	if(![[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		//string is all whitespace
		return YES;
	}

	return NO;
}

- (BOOL)isStringEmpty {
	if([self length] == 0) { //string is empty or nil
		return YES;
	}

	if(![[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		//string is all whitespace
		return YES;
	}

	return NO;
}

@end

@interface NSString (trimLeadingWhitespace)
-(NSString*)stringByTrimmingLeadingWhitespace;
@end

@implementation NSString (trimLeadingWhitespace)
-(NSString*)stringByTrimmingLeadingWhitespace {
	NSInteger i = 0;

	while ((i < [self length])
		   && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
		i++;
	}
	return [self substringFromIndex:i];
}
@end

void removeNodesWithXPath(GDataXMLDocument *document, NSString *XPath) {
	//NSLog(@"%@", nodes);
	id node = nil;
	while ((node = [document.rootElement firstNodeForXPath:XPath namespaces:nil error:nil])) {
		[document.rootElement removeChild:node];
	}
}

void stripDocument(GDataXMLDocument *document) {
	removeNodesWithXPath(document, @"//comment()");
	removeNodesWithXPath(document, @"//*[contains(@class, 'navbar')]");
	removeNodesWithXPath(document, @"//*[contains(@class, 'col-md-3')]");
	removeNodesWithXPath(document, @"//*[contains(local-name(), 'footer')]");
	removeNodesWithXPath(document, @"//script");
	removeNodesWithXPath(document, @"//head/*[starts-with(@href, 'http')]");
	removeNodesWithXPath(document, @"//*[contains(@class, 'modal')]");
}

GDataXMLElement *last(GDataXMLElement *element) {
	GDataXMLElement *listElement = (GDataXMLElement *)[element firstNodeForXPath:@"./li[last()]" namespaces:nil error:nil];
	GDataXMLElement *result = (GDataXMLElement *)[listElement firstNodeForXPath:@"./ol" namespaces:nil error:nil];
	if (!result) {
		[listElement addChild:[GDataXMLNode elementWithName:@"ol"]];
		result = (GDataXMLElement *)[listElement firstNodeForXPath:@"./ol" namespaces:nil error:nil];
	}
	return result;
}

void inlineLinks(GDataXMLNode *parentNode, NSString *filePath, GDataXMLElement *listElement) {
	NSString *path = [filePath stringByDeletingLastPathComponent];
	NSArray *nodes = [parentNode nodesForXPath:@".//*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6 or self::li]" namespaces:nil error:nil];
	//NSArray *nodes = [parentNode nodesForXPath:@".//a[not(starts-with(@href, 'http'))]" namespaces:nil error:nil];

	BOOL isFirstElement = YES;

	for (GDataXMLElement *node in nodes) {

		GDataXMLElement *lastListElement = nil;

		NSString *nodeName = node.name;

		lastListElement = listElement;

		int headerLevel = 0;

		if ([nodeName isEqualToString:@"h1"]) {
			headerLevel = 1;

		} else if ([nodeName isEqualToString:@"h2"]) {
			headerLevel = 2;

		} else if ([nodeName isEqualToString:@"h3"]) {
			headerLevel = 3;

		} else if ([nodeName isEqualToString:@"h4"]) {
			headerLevel = 4;

		} else if ([nodeName isEqualToString:@"h5"]) {
			headerLevel = 5;

		} else if ([nodeName isEqualToString:@"h6"]) {
			headerLevel = 6;

		} else if ([nodeName isEqualToString:@"li"]) {
			//NSLog(@"%@", node);
			continue;
		}

		for (int i = 1; i < headerLevel; i++) {
			lastListElement = last(lastListElement);
		}

		NSString *text = [[node stringValue] stringByTrimmingLeadingWhitespace];

		GDataXMLElement *aElement = (GDataXMLElement *)[node  firstNodeForXPath:@".//a[not(starts-with(@href, 'http'))]" namespaces:nil error:nil];

		NSString *linkPath = nil;

		if (aElement) {
			NSString *href = [[aElement attributeForName:@"href"] stringValue];
			linkPath = [[path stringByAppendingPathComponent:href] stringByStandardizingPath];
			BOOL isDir = NO;
			if ([[NSFileManager defaultManager] fileExistsAtPath:linkPath isDirectory:&isDir] && isDir) {
				linkPath = [linkPath stringByAppendingPathComponent:@"index.html"];
				if (![[NSFileManager defaultManager] fileExistsAtPath:linkPath]) {
					linkPath = nil;
				}
			}
		} else if (isFirstElement) {
			linkPath = filePath;
		}

		GDataXMLElement *itemElement = nil;

		if (linkPath) {
			if (isFirstElement) {
				itemElement = [GDataXMLNode elementWithName:@"li"];
				aElement = [GDataXMLElement elementWithName:@"a"];
				GDataXMLElement *hrefAttribute = [GDataXMLElement attributeWithName:@"href" stringValue:linkPath];
				[aElement addAttribute:hrefAttribute];
				[aElement setStringValue:text];
				[itemElement addChild:aElement];
    			isFirstElement = NO;
			} else {
				GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:linkPath] error:NULL];
				stripDocument(document);
				GDataXMLNode *childContentNode = [document.rootElement firstNodeForXPath:@"//*[contains(@role, 'main')]" namespaces:nil error:nil];

				inlineLinks(childContentNode, linkPath, lastListElement);
				continue;
			}
		} else {
			itemElement = [GDataXMLNode elementWithName:@"li" stringValue:text];
		}

		[lastListElement addChild:itemElement];

		/*
		NSString *href = [[node attributeForName:@"href"] stringValue];
		NSString *linkText = [node stringValue];
		NSString *linkPath = [[path stringByAppendingPathComponent:href] stringByStandardizingPath];

		NSLog(@"%@", filePath);
		if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
		} else {
			NSLog(@"!");
		}

		GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:linkPath] error:NULL];
		if (!document) {
			linkPath = [linkPath stringByAppendingPathComponent:@"index.html"];
			document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:linkPath] error:NULL];
			if (!document) {
				//[node removeFromParentNode];
				continue;
			}
		}

		stripDocument(document);
		id content = [document.rootElement firstNodeForXPath:@"//*[contains(@role, 'main')]" namespaces:nil error:nil];
		NSLog(@"%@", linkPath);
		//NSLog(@"%@", content);

		GDataXMLElement *linkElement = [GDataXMLNode elementWithName:@"a" stringValue:linkText];
		GDataXMLElement *linkAttibute = [GDataXMLNode attributeWithName:@"href" stringValue:linkPath];
		[linkElement addAttribute:linkAttibute];

		GDataXMLElement *listElement = [GDataXMLNode elementWithName:@"li"];
		[listElement addChild:linkElement];
		 */
	}
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSString *filePath = nil;

		for (int i = 0; i < argc; i++) {
			NSString *argument = [NSString stringWithUTF8String:argv[i]];
			NSString *extension = [argument pathExtension];
			if ([extension isEqualToString:@"html"]) {
				filePath = argument;
				break;
			}
		}

		if (!filePath) {
			exit(1);
		}

		GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:filePath] error:NULL];
		if (!document) {
			exit(1);
		}
		stripDocument(document);

		GDataXMLNode *contentNode = [document.rootElement firstNodeForXPath:@"//*[contains(@role, 'main')]" namespaces:nil error:nil];

		GDataXMLElement *contentsElement = [GDataXMLNode elementWithName:@"ol"];

		inlineLinks(contentNode, filePath, contentsElement);

		GDataXMLElement *templateElement = [[GDataXMLElement alloc] initWithXMLString:template error:nil];
		GDataXMLElement *tableOfContents = (GDataXMLElement *)[templateElement firstNodeForXPath:@"//*[@id='toc']" namespaces:nil error:nil];
		[tableOfContents addChild:contentsElement];

		//NSLog(@"title:%@", titleFromElement(contentsElement));
		NSString *title = [[contentNode firstNodeForXPath:@"//title" namespaces:nil error:nil] stringValue];
		GDataXMLElement *titleElement = (GDataXMLElement *)[[templateElement childAtIndex:0] childAtIndex:0];
		[titleElement setStringValue:title];

		GDataXMLDocument *contentDocument = [[GDataXMLDocument alloc] initWithRootElement:templateElement];
		NSData *xmlData = contentDocument.XMLData;

		NSString *resultFilePath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"content.xhtml"];
		NSLog(@"Saving xml data to %@", resultFilePath);

		if ([xmlData writeToFile:resultFilePath atomically:YES]) {
			NSLog(@"OK");
		} else {
			NSLog(@"Failed");
		}
	}
    return 0;
}
