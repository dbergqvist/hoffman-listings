/**
 * Email Service Handler to convert incoming emails to custom notifications
 */
global class EmailToNotificationHandler implements Messaging.InboundEmailHandler {
    
    /**
     * Process incoming email and create custom notification
     */
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            System.debug('Processing email from: ' + email.fromAddress);
            System.debug('Subject: ' + email.subject);
            
            // Create a custom notification
            CustomNotificationType notificationType = getCustomNotificationType();
            
            if (notificationType != null) {
                // Create notification
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                
                // Set notification type
                notification.setNotificationTypeId(notificationType.Id);
                
                // Set notification title (from email subject)
                String title = email.subject;
                if (String.isBlank(title)) {
                    title = 'New notification from ' + email.fromAddress;
                }
                notification.setTitle(title);
                
                // Set notification body (from email plain text body)
                String body = email.plainTextBody;
                if (String.isBlank(body)) {
                    body = 'Email received with no body text';
                }
                // Trim body if too long (max 255 chars)
                if (body.length() > 255) {
                    body = body.substring(0, 252) + '...';
                }
                notification.setBody(body);
                
                // Target the notification to the running user
                // Note: In a real implementation, you might want to determine the target user/group differently
                notification.setTargetId(UserInfo.getUserId());
                
                // Send notification
                notification.send(new Set<String>{UserInfo.getUserId()});
                
                System.debug('Custom notification sent successfully');
            } else {
                System.debug('Error: Could not find Custom Notification Type');
            }
            
            // Process attachments if needed
            if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                    System.debug('Attachment: ' + attachment.fileName);
                    // You could save attachments as ContentVersion records or process them in other ways
                }
            }
            
            result.success = true;
        } catch (Exception e) {
            System.debug('Error processing email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.success = false;
        }
        
        return result;
    }
    
    /**
     * Get the Custom Notification Type to use for sending notifications
     * You'll need to create this Custom Notification Type in Setup
     */
    private CustomNotificationType getCustomNotificationType() {
        List<CustomNotificationType> notificationTypes = [
            SELECT Id, DeveloperName 
            FROM CustomNotificationType 
            WHERE DeveloperName = 'Email_Notification' 
            LIMIT 1
        ];
        
        if (!notificationTypes.isEmpty()) {
            return notificationTypes[0];
        }
        
        return null;
    }
}