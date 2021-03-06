//
//  RPPrinter.m
//  Pods
//
//  Created by Martín Fernández on 1/8/15.
//
//

#import "RPPrinter.h"

#import <StarIO/SMPort.h>

#import <sys/time.h>
#import "RPDocument.h"
#import "RPImageRasterizer.h"


@interface RPPrinter()

@property (nonatomic, strong) PortInfo *portInfo;
@property (nonatomic, strong) SMPort *port;

@end

@implementation RPPrinter

#pragma mark - Initializers

- (instancetype)initWithPortInfo:(PortInfo *)portInfo {
  if (self = [super init]) {
    self.portInfo = portInfo;
  }

  return self;
}

- (instancetype)initWithPort:(SMPort *)port {
  if (self = [super init]) {
    self.port = port;
  }

  return self;
}

#pragma mark - Public API

- (void)printDocument:(RPDocument *)document {

  NSData *rasterData = [RPImageRasterizer pixelsForDocument:document];

  NSMutableData *data = [self enterRasterModeCommand];

  [data appendData:[self topMarginCommandForDocument:document]];
  [data appendData:[self speedCommandForDocument:document]];
  [data appendData:[self pageLengthCommandForDocument:document]];
  [data appendData:[self leftMarginCommandForDocument:document]];
  [data appendData:[self rightMarginCommandForDocument:document]];
  [data appendData:[self endOfDocumentModeCommandForDocument:document]];
  [data appendData:[self endOfPageModeCommandForDocument:document]];

  [data appendData:rasterData];

  [data appendData:[self quitRasterModeCommand]];

  [self sendData:data];
}

#pragma mark - SMPort communication

- (void)sendData:(NSData *)data {
  int dataSize      = (int)[data length];
  u_int8_t *rawData = (unsigned char *)malloc(dataSize);

  [data getBytes:rawData];

  @try {
    StarPrinterStatus_2 status;
    [self.port beginCheckedBlock:&status :2];

    if (status.offline == SM_TRUE) {
      return;
    }

    int totalBytesWritten = 0;
    while (totalBytesWritten < dataSize) {
      int remainingBytes = dataSize - totalBytesWritten;
      int bytestWritten = [self.port writePort:rawData :totalBytesWritten :remainingBytes];
      totalBytesWritten += bytestWritten;
    }

    if (totalBytesWritten < data.length) return;

    self.port.endCheckedBlockTimeoutMillis = 30000;
    [self.port endCheckedBlock:&status :2];

    if (status.offline == SM_TRUE) {
      return;
    }

  } @catch (PortException *exception) {
    NSLog(@"%@",exception);
  } @finally {
    free(rawData);
    [SMPort releasePort:self.port];
  }
}

#pragma mark - Raster Commands

- (NSMutableData *)topMarginCommandForDocument:(RPDocument *)document {
  u_int8_t flag;

  switch (document.topMargin) {
    case RPDocumentTopMarginDefault:
      flag = '0';
      break;
    case RPDocumentTopMarginSmall:
      flag = '1';
      break;
    case RPDocumentTopMarginStandard:
      flag = '2';
      break;
  }

  u_int8_t lenght   = 6;
  u_int8_t command[] = { 0x1b, '*', 'r', 'T', flag, 0 };

  return [NSMutableData dataWithBytes:command length:lenght];
}

- (NSMutableData *)speedCommandForDocument:(RPDocument *)document {
  u_int8_t flag;

  switch (document.speed) {
    case RPDocumentRasterSpeedFull:
      flag = '0';
      break;
    case RPDocumentRasterSpeedMedium:
      flag = '1';
      break;
    case RPDocumentRasterSpeedLow:
      flag = '2';
      break;
  }

  u_int8_t lenght   = 6;
  u_int8_t command[] = { 0x1b, '*', 'r', 'Q', flag, 0 };

  return [NSMutableData dataWithBytes:command length:lenght];
}

- (NSMutableData *)leftMarginCommandForDocument:(RPDocument *)document {
  u_int8_t lenght = 5;
  u_char endChar = 0;

  uint8_t command[] = { 0x1b, '*', 'r', 'm', 'l' };
  NSMutableData *data = [NSMutableData dataWithBytes:command length:lenght];
  NSData *leftMarginData = [[NSString stringWithFormat:@"%i", document.leftMarging] dataUsingEncoding:NSWindowsCP1252StringEncoding];

  [data appendData:leftMarginData];
  [data appendBytes:&endChar length:1];

  return data;
}

- (NSMutableData *)rightMarginCommandForDocument:(RPDocument *)document {
  u_int8_t lenght = 5;
  u_char endChar = 0;

  uint8_t command[] = { 0x1b, '*', 'r', 'm', 'r' };
  NSMutableData *data = [NSMutableData dataWithBytes:command length:lenght];
  NSData *leftMarginData = [[NSString stringWithFormat:@"%i", document.rightMargin] dataUsingEncoding:NSWindowsCP1252StringEncoding];

  [data appendData:leftMarginData];
  [data appendBytes:&endChar length:1];

  return data;
}

- (NSMutableData *)pageLengthCommandForDocument:(RPDocument *)document {
  u_int8_t lenght = 4;
  unsigned char endChar = 0;

  uint8_t command[] = { 0x1b, '*', 'r', 'P' };

  NSMutableData *data = [NSMutableData dataWithBytes:command length:lenght];
  NSData *leftMarginData = [[NSString stringWithFormat:@"%i", document.pageLength] dataUsingEncoding:NSWindowsCP1252StringEncoding];

  [data appendData:leftMarginData];
  [data appendBytes:&endChar length:1];

  return data;
}

- (NSMutableData *)endOfPageModeCommandForDocument:(RPDocument *)document {
  u_int8_t lenght   = 6;
  uint8_t command[] = { 0x1b, '*', 'r', 'F', document.endOfPageMode, 0 };

  return [NSMutableData dataWithBytes:command length:lenght];
}

- (NSMutableData *)endOfDocumentModeCommandForDocument:(RPDocument *)document {
  u_int8_t lenght   = 6;
  uint8_t command[] = { 0x1b, '*', 'r', 'E', document.endOfDocumentMode, 0 };

  return [NSMutableData dataWithBytes:command length:lenght];
}

- (NSMutableData *)enterRasterModeCommand {
  u_int8_t lenght   = 4;
  uint8_t command[] = { 0x1b, '*', 'r', 'A' };

  return [NSMutableData dataWithBytes:command length:lenght];
}

- (NSMutableData *)quitRasterModeCommand {
  u_int8_t lenght   = 4;
  uint8_t command[] = { 0x1b, '*', 'r', 'B' };

  return [NSMutableData dataWithBytes:command length:lenght];
}

@end
