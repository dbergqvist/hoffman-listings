public with sharing class SanaDashboardDataSync {
    
    @AuraEnabled
    public static String syncUserCompletionData() {
        try {
            // Get the analytics data using the existing controller
            String jobId = SanaInsightsController.startUserCompletionsAnalyticsJob();
            
            // Poll for completion (simplified for sync operation)
            Map<String, Object> statusResult;
            Integer pollCount = 0;
            Boolean finished = false;
            String downloadLink;
            
            while (pollCount < 10 && !finished) { // Wait up to 50 seconds
                System.debug('Polling attempt: ' + pollCount);
                
                // Wait 5 seconds between polls
                if (pollCount > 0) {
                    // Use a simple delay
                    Datetime startTime = Datetime.now();
                    while (Datetime.now().getTime() - startTime.getTime() < 5000) {
                        // Simple wait
                    }
                }
                
                statusResult = SanaInsightsController.checkAnalyticsJobStatus(jobId);
                
                if (statusResult.get('status') == 'successful' && statusResult.containsKey('link')) {
                    finished = true;
                    Map<String, Object> linkObject = (Map<String, Object>) statusResult.get('link');
                    downloadLink = (String) linkObject.get('url');
                    break;
                } else if (statusResult.get('status') == 'failed') {
                    throw new AuraHandledException('Analytics job failed');
                }
                
                pollCount++;
            }
            
            if (!finished) {
                throw new AuraHandledException('Analytics job timed out');
            }
            
            // Fetch the analytics results
            List<Map<String, Object>> analyticsData = SanaInsightsController.fetchAnalyticsResult(downloadLink, 'user_completions_analytics');
            
            // Filter out test users (same logic as component)
            List<Map<String, Object>> filteredData = new List<Map<String, Object>>();
            for (Map<String, Object> item : analyticsData) {
                String title = (String) item.get('title');
                String userEmail = (String) item.get('user_email');
                String userDisplayName = (String) item.get('user_display_name');
                
                Boolean isTestUser = 
                    title == 'LMSGetValue return' ||
                    (userEmail != null && userEmail.contains('sana-scorm-')) ||
                    (userEmail != null && userEmail.contains('sana-live-')) ||
                    title == '1234' ||
                    userDisplayName == 'LMSGetValue return';
                
                if (!isTestUser) {
                    filteredData.add(item);
                }
            }
            
            // Sync to custom objects
            return syncToCustomObjects(filteredData);
            
        } catch (Exception e) {
            System.debug('Error in syncUserCompletionData: ' + e.getMessage());
            throw new AuraHandledException('Sync failed: ' + e.getMessage());
        }
    }
    
    private static String syncToCustomObjects(List<Map<String, Object>> analyticsData) {
        List<Sana_User_Completion__c> recordsToUpsert = new List<Sana_User_Completion__c>();
        
        for (Map<String, Object> userData : analyticsData) {
            Sana_User_Completion__c record = new Sana_User_Completion__c();
            
            // Extract user ID from the id field (format: "user-{uuid}")
            String fullId = (String) userData.get('id');
            String sanaUserId = fullId != null ? fullId.replace('user-', '') : '';
            
            record.Sana_User_ID__c = sanaUserId;
            record.User_Display_Name__c = (String) userData.get('user_display_name');
            record.User_Email__c = (String) userData.get('user_email');
            record.Courses_Completed__c = (Integer) userData.get('courses_completed');
            record.Last_Sync_Date__c = System.now();
            
            // Parse first and last name from display name
            String displayName = (String) userData.get('user_display_name');
            if (displayName != null && displayName.trim().length() > 0) {
                List<String> nameParts = displayName.trim().split(' ');
                if (nameParts.size() >= 1) {
                    record.First_Name__c = nameParts[0];
                }
                if (nameParts.size() >= 2) {
                    // Join all remaining parts as last name (handles middle names)
                    List<String> lastNameParts = new List<String>();
                    for (Integer i = 1; i < nameParts.size(); i++) {
                        lastNameParts.add(nameParts[i]);
                    }
                    record.Last_Name__c = String.join(lastNameParts, ' ');
                } else if (nameParts.size() == 1) {
                    // If only one name part, leave last name empty
                    record.Last_Name__c = '';
                }
            }
            
            recordsToUpsert.add(record);
        }
        
        try {
            // Upsert using external ID
            Database.UpsertResult[] upsertResults = Database.upsert(recordsToUpsert, Sana_User_Completion__c.Sana_User_ID__c);
            
            Integer successCount = 0;
            Integer errorCount = 0;
            
            for (Database.UpsertResult result : upsertResults) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    errorCount++;
                    for (Database.Error error : result.getErrors()) {
                        System.debug('Upsert error: ' + error.getMessage());
                    }
                }
            }
            
            return 'Sync completed: ' + successCount + ' records processed successfully, ' + errorCount + ' errors.';
            
        } catch (Exception e) {
            System.debug('Error upserting records: ' + e.getMessage());
            throw new AuraHandledException('Database error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getLastSyncInfo() {
        try {
            List<Sana_User_Completion__c> records = [
                SELECT Last_Sync_Date__c 
                FROM Sana_User_Completion__c 
                ORDER BY Last_Sync_Date__c DESC 
                LIMIT 1
            ];
            
            if (records.isEmpty()) {
                return 'No sync has been performed yet.';
            }
            
            Datetime lastSync = records[0].Last_Sync_Date__c;
            return 'Last sync: ' + lastSync.format() + ' (' + getRelativeTime(lastSync) + ')';
            
        } catch (Exception e) {
            return 'Error retrieving sync info: ' + e.getMessage();
        }
    }
    
    private static String getRelativeTime(Datetime syncTime) {
        Long diffInSeconds = (System.now().getTime() - syncTime.getTime()) / 1000;
        
        if (diffInSeconds < 60) {
            return diffInSeconds + ' seconds ago';
        } else if (diffInSeconds < 3600) {
            return (diffInSeconds / 60) + ' minutes ago';
        } else if (diffInSeconds < 86400) {
            return (diffInSeconds / 3600) + ' hours ago';
        } else {
            return (diffInSeconds / 86400) + ' days ago';
        }
    }
} 