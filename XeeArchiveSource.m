#import "XeeArchiveSource.h"
#import "XeeImage.h"

#import <unistd.h>

@implementation XeeArchiveSource

+(NSArray *)fileTypes
{
	return [NSArray arrayWithObjects:
		@"zip",@"rar",@"cbz",@"cbr",@"lha",@"lzh",@"7z",
	nil];
}

-(id)initWithArchive:(NSString *)archivename
{
	if(self=[super init])
	{
		tmpdir=[[NSTemporaryDirectory() stringByAppendingPathComponent:
		[NSString stringWithFormat:@"Xee-archive-%04x%04x%04x",random()&0xffff,random()&0xffff,random()&0xffff]]
		retain];

		[self setIcon:[[NSWorkspace sharedWorkspace] iconForFile:archivename]];
		[icon setSize:NSMakeSize(16,16)];

		archive=[[self archiveForFile:archivename] retain];
		if(!archive)
		{
			[self release];
			return nil;
		}
	}
	return self;
}

-(void)dealloc
{
	if(tmpdir) [[NSFileManager defaultManager] removeFileAtPath:tmpdir handler:nil];

	[archive release];
	[tmpdir release];

	[super dealloc];
}



-(void)start
{
	[self startListUpdates];

	NSArray *filetypes=[XeeImage allFileTypes];
	int count=[archive numberOfEntries];
	for(int i=0;i<count;i++)
	{
		if([archive entryIsDirectory:i]) continue;
		if([archive entryIsLink:i]) continue;

		NSString *name=[archive nameOfEntry:i];
		NSDictionary *attrs=[archive attributesOfEntry:i];
		NSString *type=NSFileTypeForHFSTypeCode([attrs fileHFSTypeCode]);
		NSString *ext=[[name pathExtension] lowercaseString];

		if([filetypes indexOfObject:ext]!=NSNotFound||[filetypes indexOfObject:type]!=NSNotFound)
		{
			NSString *realpath=[tmpdir stringByAppendingPathComponent:name];
			[self addEntry:[[[XeeArchiveEntry alloc]
			initWithArchive:archive entry:i realPath:realpath] autorelease]];
		}
	}

	[self sortFiles];
	[self endListUpdates];

	[self pickImageAtIndex:0];
}



-(NSString *)representedFilename { return [archive filename]; }



-(BOOL)canBrowse { return YES; }
-(BOOL)canSort { return YES; }
-(BOOL)canCopyCurrentImage { return YES; }



-(XADArchive *)archiveForFile:(NSString *)archivename
{
	Class archiveclass=NSClassFromString(@"XADArchive");

	if(!archiveclass)
	{
		NSString *unarchiver=[[NSWorkspace sharedWorkspace] fullPathForApplication:@"The Unarchiver"];
		if(!unarchiver)
		{
			NSString *ext=[[archivename pathExtension] lowercaseString];
			if([[XeeArchiveSource fileTypes] indexOfObject:ext]!=NSNotFound)
			{
				NSAlert *alert=[[[NSAlert alloc] init] autorelease];
				[alert setMessageText:NSLocalizedString(@"Problem Opening Archive",@"Error title when The Unarchiver is not installed")];
				[alert setInformativeText:NSLocalizedString(@"Xee can only open images inside archive files if The Unarchiver is also installed. You can download The Unarchiver for free by clicking the button below.",@"Error text when The Unarchiver is not installed")];
				[alert setAlertStyle:NSInformationalAlertStyle];
				[alert addButtonWithTitle:NSLocalizedString(@"Visit the The Unarchiver Download Page","Button to download The Unarchiver when it is not installed")];
				NSButton *cancel=[alert addButtonWithTitle:NSLocalizedString(@"Don't Bother","Button to not download The Unarchiver")];
				[cancel setKeyEquivalent:@"\033"];

				int res=[alert runModal];

				if(res==NSAlertFirstButtonReturn)
				[[NSWorkspace sharedWorkspace] openURL:
				[NSURL URLWithString:@"http://wakaba.c3.cx/s/apps/unarchiver.html"]];
			}

			return nil;
		}

		NSString *xadpath=[unarchiver stringByAppendingPathComponent:@"Contents/Frameworks/XADMaster.framework"];
		NSBundle *xadmaster=[NSBundle bundleWithPath:xadpath];
		if(!xadmaster) return nil;
		if(![xadmaster load]) return nil;

		NSString *unipath=[unarchiver stringByAppendingPathComponent:@"Contents/Frameworks/UniversalDetector.framework"];
		NSBundle *universal=[NSBundle bundleWithPath:unipath];
		if(!universal) return nil;
		if(![universal load]) return nil;

		archiveclass=NSClassFromString(@"XADArchive");
	}

	return [archiveclass archiveForFile:archivename];
}

@end



@implementation XeeArchiveEntry

-(id)initWithArchive:(XADArchive *)parentarchive entry:(int)num realPath:(NSString *)realpath
{
	if(self=[super init])
	{
		archive=[parentarchive retain];
		path=[realpath retain];
		n=num;
		ref=nil;

		size=[archive uncompressedSizeOfEntry:n];

		NSDate *date=[[archive dataForkParserDictionaryForEntry:n] objectForKey:@"XADLastModificationDate"];
		if(date) time=[date timeIntervalSinceReferenceDate];
		else date=0;
	}
	return self;
}

-(id)initAsCopyOf:(XeeArchiveEntry *)other
{
	if(self=[super initAsCopyOf:other])
	{
		archive=[other->archive retain];
		n=other->n;
		ref=[other->ref retain];
		path=[other->path retain];
		size=other->size;
		time=other->time;
	}
	return self;
}

-(void)dealloc
{
	[archive release];
	[path release];
	[ref release];
	[super dealloc];
}

-(NSString *)descriptiveName { return [archive nameOfEntry:n]; }

-(XeeFSRef *)ref
{
	if(!ref)
	{
		[archive _extractEntry:n as:path];
		ref=[[XeeFSRef refForPath:path] retain];
	}
	return ref;
}

-(NSString *)path { return path; }

-(NSString *)filename { return [[archive nameOfEntry:n] lastPathComponent]; }

-(uint64_t)size { return size; }

-(double)time { return time; }



-(BOOL)isEqual:(XeeArchiveEntry *)other { return archive==other->archive&&n==other->n; }

-(unsigned)hash { return (unsigned)archive^n; }

@end
