/**
 * Test class for EmailToNotificationHandler
 */
@isTest
private class EmailToNotificationHandlerTest {
    
    @isTest
    static void testHandleInboundEmail() {
        // Create a mock email
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'test@example.com';
        email.subject = 'Test Email Subject';
        email.plainTextBody = 'This is a test email body.';
        
        // Create a binary attachment
        Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
        attachment.fileName = 'test.txt';
        attachment.body = Blob.valueOf('Test attachment content');
        email.binaryAttachments = new Messaging.InboundEmail.BinaryAttachment[] { attachment };
        
        // Create envelope
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@example.com';
        
        // Insert a mock notification type
        // Note: Since we can't insert CustomNotificationType in tests,
        // we'll need to mock or skip this part of the functionality
        
        Test.startTest();
        
        // Process the email
        EmailToNotificationHandler handler = new EmailToNotificationHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        
        Test.stopTest();
        
        // Since we can't create a CustomNotificationType in test context, our handler
        // should handle this gracefully and still return success = true
        System.assertEquals(true, result.success, 'Email should be processed successfully');
    }
    
    @isTest
    static void testHandleInboundEmailWithNullValues() {
        // Create a mock email with null values
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'test@example.com';
        email.subject = null;
        email.plainTextBody = null;
        email.binaryAttachments = null;
        
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@example.com';
        
        Test.startTest();
        
        // Process the email
        EmailToNotificationHandler handler = new EmailToNotificationHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        
        Test.stopTest();
        
        // Handler should handle null values gracefully
        System.assertEquals(true, result.success, 'Email with null values should be processed successfully');
    }
    
    @isTest
    static void testHandleInboundEmailWithLongBody() {
        // Create a mock email with a very long body
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'test@example.com';
        email.subject = 'Test Email Subject';
        
        // Create a body longer than 255 chars
        String longBody = '';
        for(Integer i = 0; i < 30; i++) {
            longBody += 'This is a very long email body that should be truncated. ';
        }
        email.plainTextBody = longBody;
        
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@example.com';
        
        Test.startTest();
        
        // Process the email
        EmailToNotificationHandler handler = new EmailToNotificationHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail(email, envelope);
        
        Test.stopTest();
        
        // Handler should truncate long body and still process successfully
        System.assertEquals(true, result.success, 'Email with long body should be processed successfully');
    }
}