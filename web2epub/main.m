//
//  main.m
//  web2epub
//

#import <Foundation/Foundation.h>
#import "GDataXMLNode.h"

NSString *navTemplate =
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

NSString *pageTemplate =
@"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">"
@"<html xmlns=\"http://www.w3.org/1999/xhtml\">"
@"<head>"
@"<title>The title</title>"
@"<link rel=\"stylesheet\" href=\"../Styles/stylesheet.css\" type=\"text/css\" />"
@"</head>"
@"<body></body>"
@"</html>";

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

/*
GDataXMLNode *content(NSString *filePath, NSString *xpath) {
	GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:filePath] error:NULL];
	if (!document) {
		exit(1);
	}
	stripDocument(document);
	GDataXMLNode *result = [document.rootElement firstNodeForXPath:xpath namespaces:nil error:nil];
	return result;
}
 */

BOOL saveContent(GDataXMLElement *element, NSString *filePath) {
	GDataXMLDocument *contentDocument = [[GDataXMLDocument alloc] initWithRootElement:element];
	NSData *xmlData = contentDocument.XMLData;

	NSLog(@"Saving xml data to %@", filePath);

	if ([xmlData writeToFile:filePath atomically:YES]) {
		NSLog(@"...OK");
		return YES;
	}

	NSLog(@"...Failed");
	return NO;
}

void parsePage(NSString *filePath, GDataXMLElement *listElement, NSString *xpath, NSString *outputDir) {
	NSArray *pathParts = [filePath componentsSeparatedByString:@"#"];
	NSString *hashTag = nil;
	if (pathParts.count > 1) {
		hashTag = [pathParts lastObject];
	}
	filePath = [pathParts firstObject];

	GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:[NSData dataWithContentsOfFile:filePath] error:NULL];
	if (!document) {
		return;
	}
	stripDocument(document);

	BOOL isFirstElement = YES;
	static int pageCount = 1;
	static int imagesCount = 1;
	int headerLevel = 0;

	NSString *pageLink = [NSString stringWithFormat:@"%d.xhtml", pageCount++];
	NSString *path = [filePath stringByDeletingLastPathComponent];

	GDataXMLNode *contentNode = [document.rootElement firstNodeForXPath:xpath namespaces:nil error:nil];
	NSArray *nodes = [contentNode nodesForXPath:@".//*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6 or self::li or self::img]" namespaces:nil error:nil];
	//NSArray *nodes = [parentNode nodesForXPath:@".//a[not(starts-with(@href, 'http'))]" namespaces:nil error:nil];

	for (GDataXMLElement *node in nodes) {

		GDataXMLElement *lastListElement = nil;

		NSString *nodeName = node.name;

		lastListElement = listElement;

		int listLevel = 0;

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
			listLevel = 1;

		} else if ([nodeName isEqualToString:@"img"]) {
			GDataXMLNode *attribute = [node attributeForName:@"src"];

			NSString *src = [attribute stringValue];
			NSString *srcPath = [[path stringByAppendingPathComponent:src] stringByStandardizingPath];
			NSString *extension = [src pathExtension];

			NSString *srcConverted = [NSString stringWithFormat:@"../Images/%d.%@", imagesCount++, extension];
			NSString *srcConvertedPath = [[outputDir stringByAppendingPathComponent:[NSString stringWithFormat:@"Text/%@", srcConverted]] stringByStandardizingPath];

			[attribute setStringValue:srcConverted];

			NSLog(@"Copying image to %@", srcConvertedPath);
			NSError *error = nil;

			[[NSFileManager defaultManager] copyItemAtPath:srcPath toPath:srcConvertedPath error:&error];
			if (!error) {
				NSLog(@"..OK");
			} else {
				NSLog(@"...Error: %@", error.localizedDescription);
			}
			continue;
		}

		for (int i = 1; i < headerLevel + listLevel; i++) {
			lastListElement = last(lastListElement);
		}

		NSString *text = [[node stringValue] stringByTrimmingLeadingWhitespace];

		GDataXMLElement *aElement = (GDataXMLElement *)[node firstNodeForXPath:@".//a[not(starts-with(@href, 'http'))]" namespaces:nil error:nil];

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
				GDataXMLElement *hrefAttribute = [GDataXMLElement attributeWithName:@"href" stringValue:pageLink];
				[aElement addAttribute:hrefAttribute];
				[aElement setStringValue:text];
				[itemElement addChild:aElement];
    			isFirstElement = NO;
			} else {
				parsePage(linkPath, lastListElement, xpath, outputDir);
				continue;
			}
		} else {
			itemElement = [GDataXMLNode elementWithName:@"li" stringValue:text];
		}

		[lastListElement addChild:itemElement];
	}

	NSString *convertedLink = [NSString stringWithFormat:@"Text/%@", pageLink];
	NSString *resultFilePath = [outputDir stringByAppendingPathComponent:convertedLink];

	GDataXMLElement *templateElement = [[GDataXMLElement alloc] initWithXMLString:pageTemplate error:nil];
	GDataXMLElement *bodyNode = (GDataXMLElement *)[templateElement firstNodeForXPath:@"*[2]" namespaces:nil error:nil];
	[bodyNode addChild:contentNode];

	saveContent(templateElement, resultFilePath);
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSString *filePath = nil;
		NSString *xpath = @"/html/body";
		NSString *outputDir = @".";

		for (int i = 0; i < argc; i++) {
			NSString *argument = [NSString stringWithUTF8String:argv[i]];
			NSString *extension = [argument pathExtension];

			if ([extension isEqualToString:@"html"]) {
				filePath = argument;

			} else if ([argument hasPrefix:@"-x"]) {
				xpath = [NSString stringWithUTF8String:argv[++i]];

			} else if ([argument hasPrefix:@"-o"]) {
				outputDir = [NSString stringWithUTF8String:argv[++i]];
			}
		}

		if (!filePath) {
			exit(1);
		}

		NSString *OEBPSDir = [outputDir stringByAppendingPathComponent:@"OEBPS"];

		GDataXMLElement *contentsElement = [GDataXMLNode elementWithName:@"ol"];

		parsePage(filePath, contentsElement, xpath, OEBPSDir);

		GDataXMLElement *templateElement = [[GDataXMLElement alloc] initWithXMLString:navTemplate error:nil];
		GDataXMLElement *tableOfContents = (GDataXMLElement *)[templateElement firstNodeForXPath:@"//*[@id='toc']" namespaces:nil error:nil];
		[tableOfContents addChild:contentsElement];

		/*
		NSString *title = [[contentNode firstNodeForXPath:@"//title" namespaces:nil error:nil] stringValue];
		GDataXMLElement *titleElement = (GDataXMLElement *)[[templateElement childAtIndex:0] childAtIndex:0];
		[titleElement setStringValue:title];
		 */

		NSString *resultFilePath = [OEBPSDir stringByAppendingPathComponent:@"Text/content.xhtml"];

		saveContent(templateElement, resultFilePath);
	}
    return 0;
}
