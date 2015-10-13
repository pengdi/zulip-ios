#import "MessageCell.h"
#import "ZulipAppDelegate.h"
#import "UIImageView+AFNetworking.h"
#import "ZUser.h"
#import "ZulipAPIController.h"
#import "ZulipAPIClient.h"

#include <QuartzCore/QuartzCore.h>

@interface MessageCell ()

@property (nonatomic, retain) NSDateFormatter *dateFormatter;

@end

@implementation MessageCell

- (void)awakeFromNib
{
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [self.dateFormatter setDateFormat:@"HH:mm"];
    self.attributedTextView.textContainer.lineFragmentPadding = 0;
    self.attributedTextView.textContainerInset = UIEdgeInsetsZero;
    
}

- (void)setMessage:(RawMessage *)message
{
    self.type = message.type;

    if ([self.type isEqualToString:@"stream"]) {
        self.header.text = [NSString stringWithFormat:@"%@ > %@",
                            message.stream_recipient,
                            message.subject];
        self.recipient = message.stream_recipient;
    } else if ([self.type isEqualToString:@"private"]) {
        NSMutableArray *recipient_array = [[NSMutableArray alloc] init];

        for (ZUser *recipient in message.pm_recipients) {
            if (![recipient.email isEqualToString:[[ZulipAPIController sharedInstance] email]]) {
                [recipient_array addObject:recipient.full_name];
            }
        }
        self.recipient = [recipient_array componentsJoinedByString:@", "];
        if ([recipient_array count]) {
            self.header.text = [@"You and " stringByAppendingString:self.recipient];
        } else {
            self.header.text = [NSString stringWithFormat:@"You and %@", [[ZulipAPIController sharedInstance] fullName]];
        }
    }

    self.sender.text = message.sender.full_name;

    // Asynchronously load gravatar if needed
    [self.gravatar setImageWithURL:[NSURL URLWithString:message.avatar_url]];

    // Mask to get rounded corners
    // TODO apparently this can be slow during animations?
    // If it makes scrolling slow, switch over to manually
    // creating the UIImage by applying a mask with Core Graphics
    // instead of using the view's layer.
    CALayer *layer = self.gravatar.layer;
    [layer setMasksToBounds:YES];
    [layer setCornerRadius:21.0f];

    self.timestamp.text = [self.dateFormatter stringFromDate:message.timestamp];

    // When a message is on the screen, mark it as read
    message.read = YES;

    _message = message;
    // this line crashes the app??
    self.attributedTextView.attributedText = message.attributedString;
    self.attributedTextView.delegate = self;

}

- (void)willBeDisplayed
{
    if ([self.type isEqualToString:@"stream"]) {
        self.headerBar.backgroundColor = [[ZulipAPIController sharedInstance] streamColor:self.recipient withDefault:[MessageCell defaultStreamColor]];
        self.backgroundColor = [UIColor clearColor];
        self.header.textColor = [UIColor blackColor];
    } else {
        // For non-stream messages, color cell background pale yellow (#FEFFE0).
        self.backgroundColor = [UIColor colorWithRed:255.0/255 green:254.0/255
                                                   blue:224.0/255 alpha:1];
        self.headerBar.backgroundColor = [UIColor colorWithRed:51.0/255
                                                            green:51.0/255
                                                             blue:51.0/255
                                                            alpha:1];
        self.header.textColor = [UIColor whiteColor];
    }


}

+ (CGFloat)heightForCellWithMessage:(RawMessage *)message
{
    static dispatch_once_t onceToken;
    static UITextView *dummyContentViewPortrait;
    static UITextView *dummyContentViewLandscape;
    static CGFloat portraitContentWidth;
    static CGFloat landscapeContentWidth;
    dispatch_once(&onceToken, ^{
        //53 "pixels" is the number of pixels to the left and right of the message content box.
        portraitContentWidth = [[UIScreen mainScreen] bounds].size.width - 53.0f;
        dummyContentViewPortrait = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, portraitContentWidth, 1)];
        landscapeContentWidth = [[UIScreen mainScreen] bounds].size.height - 53.0f;
        dummyContentViewLandscape = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, landscapeContentWidth, 1)];
    });

    UITextView *currentDummyContentView;
    CGFloat contentWidth;

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation == UIInterfaceOrientationPortrait){
        currentDummyContentView = dummyContentViewPortrait;
        contentWidth = portraitContentWidth;
    } else {
        currentDummyContentView = dummyContentViewLandscape;
        contentWidth = landscapeContentWidth;
    }

    currentDummyContentView.attributedText = message.attributedString;
//(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
    float calcHeight = [message.attributedString boundingRectWithSize:CGSizeMake(contentWidth, CGFLOAT_MAX) options: (NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) context:nil].size.height + 38.0f;
    float retHeight = fmaxf(77.0f, calcHeight);
    
    NSLog(@"calcHeight: %f, retHeight: %f", calcHeight, retHeight);
    
    return ceilf(retHeight);
}

#pragma mark - UITableViewCell


+ (UIColor *)defaultStreamColor {
    return [UIColor colorWithRed:187.0f/255
                           green:187.0f/255
                            blue:187.0f/255
                           alpha:1];
}

+ (NSString *)reuseIdentifier {
    return @"CustomCellIdentifier";
}
//
//#pragma mark - DTAttributedTextContentViewDelegate
//// Derived from example snippet from
//// http://blog.smartlogicsolutions.com/2013/04/02/ios-development-dtattributedtextview-instead-of-uiwebview/
//- (UIView *)attributedTextContentView:(UITextView *)attributedTextContentView
//                          viewForLink:(NSURL *)url
//                           identifier:(NSString *)identifier
//                                frame:(CGRect)frame
//{
//    UIButton *linkButton = [[UIButton alloc] initWithFrame:frame];
//    linkButton.URL = url;
//    [linkButton addTarget:self action:@selector(linkClicked:) forControlEvents:UIControlEventTouchDown];
//
//    return linkButton;
//}
//
//- (IBAction)linkClicked:(DTLinkButton *)sender
//{
//    if ([_delegate respondsToSelector:@selector(openLink:)])
//    {
//        [sender.URL baseURL];
//        if (([[sender.URL host] isEqual:[[[ZulipAPIClient sharedClient] apiURL] host]])
//            && ([[sender.URL path]  isEqual: @"/"]))
//        {
//            NSLog(@"FIXME: this application cannot yet open narrows");
//        } else
//        {
//            [_delegate openLink:sender.URL];
//        }
//    }
//}

@end
