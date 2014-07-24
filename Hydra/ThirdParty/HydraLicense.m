#import "HydraLicense.h"
#include <CommonCrypto/CommonDigest.h>

static NSString* pubkey = @"-----BEGIN DSA PUBLIC KEY-----\n"
"MIHwMIGoBgcqhkjOOAQBMIGcAkEAhUA4RrIEKnAT0J2ZW/fWT9zT4GBVFVQxq+NV\n"
"yk8eqiNdJXF4Y6VMnuohvMA6niQGdgKgwDmg7NTD26kZpyhB4wIVAOQjzXwOopx7\n"
"fol961QqxK/PJSDlAkBILOfA5fupc/jg6SdgUmwWmlAurRoCmZHEn8JZ62zxUy3I\n"
"7TNOSacpXeqw8ypeTFuJH63zCziQdUhTQEGRHDeCA0MAAkBdlN7MK6Rq90GN7yj6\n"
"Us6JTKJm+x/GANMJVvhX9JL49RhXpx46HMs4tWG83XtC6+wjGFssIRuvnv2vbkWp\n"
"y0k5\n"
"-----END DSA PUBLIC KEY-----\n";

static void getpublickey(SecKeyRef* keyptr, CFErrorRef* errorptr) {
    static SecKeyRef key = NULL;
    static CFErrorRef error = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFDataRef privkeyData = (__bridge CFDataRef)[pubkey dataUsingEncoding:NSUTF8StringEncoding];
        SecExternalItemType itemType = kSecItemTypePublicKey;
        SecExternalFormat externalFormat = kSecFormatPEMSequence;
        int flags = 0;
        
        SecItemImportExportKeyParameters params = {0};
        params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
        params.flags = 0;
        
        CFArrayRef items = NULL;
        OSStatus oserr = SecItemImport(privkeyData, NULL, &externalFormat, &itemType, flags, &params, NULL, &items);
        if (oserr)
            error = CFErrorCreate(NULL, kCFErrorDomainOSStatus, oserr, NULL);
        else if (items)
            key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
        
        if (items)
            CFRelease(items);
    });
    *keyptr = key;
    *errorptr = error;
}

static BOOL verifylicense(NSString* sig, NSString* email) {
    BOOL result = NO;
    
    NSMutableString *transformedEmail = [NSMutableString string];
    for (NSInteger i = [email length] - 1; i >= 0; i--)
        [transformedEmail appendFormat:@"%c", [email characterAtIndex:i]];
    
    NSData* sigData = [[NSData alloc] initWithBase64EncodedString:sig options:0];
    CFErrorRef error = NULL;
    
    SecKeyRef publibkey;
    getpublickey(&publibkey, &error);
    if (error) goto cleanup;
    
    SecTransformRef verifier = SecVerifyTransformCreate(publibkey, (__bridge CFDataRef)sigData, &error);
    if (error) goto cleanup;
    
    CFDataRef emailDataToVerify = (__bridge CFDataRef)[transformedEmail dataUsingEncoding:NSUTF8StringEncoding];
    SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, emailDataToVerify, &error);
    if (error) goto cleanup;
    
    result = [(__bridge NSNumber*)SecTransformExecute(verifier, &error) boolValue];
    
cleanup:
    
    if (error) {
        CFShow(error);
        CFRelease(error);
    }
    
    return result;
}

#define HydraEmailKey @"_HydraEmail"
#define HydraLicenseKey @"_HydraLicense"

@implementation HydraLicense

- (NSString*) email {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraEmailKey];
}

- (NSString*) license {
    return [[NSUserDefaults standardUserDefaults] stringForKey:HydraLicenseKey];
}

- (BOOL) verify {
    return verifylicense([self license], [self email]);
}

- (BOOL) isValid {
    return [self email] && [self license] && [self verify];
}

- (void) check {
    NSLog(@"%d", verifylicense(@"MC0CFQCcGckU7tNoN8H4IbyraKpEDedf4AIUV/7au5+vvtuorcvHJCY436BVPeY=", @"vagif.samadoghlu@example.com"));
}

@end
