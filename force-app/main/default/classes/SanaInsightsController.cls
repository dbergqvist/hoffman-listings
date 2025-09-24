public with sharing class SanaInsightsController {
    private static final String BASE_URL = 'https://api.example.com';
    private static final Integer CACHE_DURATION_HOURS = 24;
    private static final Integer MAX_POLLING_ATTEMPTS = 30;
    private static final Integer POLLING_DELAY_SECONDS = 10;
    
    @AuraEnabled
    public static Map<String, Object> getInsightsReport(String reportType) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== STARTING INSIGHTS REPORT GENERATION ===');
            System.debug('Report Type: ' + reportType);
            
            // Check cache first
            SanaAnalyticsCache__c cache = getCachedReport(reportType);
            if (cache != null) {
                System.debug('Using cached report data');
                response.put('data', JSON.deserializeUntyped(cache.ReportData__c));
                response.put('cached', true);
                response.put('lastUpdated', cache.LastUpdated__c);
                return response;
            }
            
            // If no cache or cache expired, fetch new data
            System.debug('No valid cache found, fetching fresh data');
            
            // First, generate a token for API authentication (write scope for job creation)
            System.debug('Generating new token with write scope...');
            String tokenResponse = SanaLearnController.generateNewTokenWithScope('write');
            System.debug('Token Response: ' + tokenResponse);
            
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                System.debug('Token generation failed: ' + tokenResponse);
                response.put('error', 'Failed to generate token: ' + tokenResponse);
                return response;
            }
            
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            System.debug('Token generated successfully');
            
            if (reportType == 'course_type_analytics' || reportType == 'user_count_analytics' || reportType == 'user_course_progress') {
                // Step 1: Generate the report
                String queryEndpoint = BASE_URL + '/v1/reports/query';
                System.debug('Querying reports at endpoint: ' + queryEndpoint);
                
                HttpRequest queryRequest = new HttpRequest();
                queryRequest.setEndpoint(queryEndpoint);
                queryRequest.setMethod('POST');
                queryRequest.setHeader('Content-Type', 'application/json');
                queryRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                
                // Set the SQL query based on report type
                String sqlQuery;
                if (reportType == 'user_count_analytics') {
                    sqlQuery = 'SELECT "user_count" FROM "analytics"."analytics"';
                } else if (reportType == 'user_course_progress') {
                    sqlQuery = 'SELECT "user", "course", "start_date", "completion_date", "last_progress_date", "course_instance" FROM "analytics"."user_course_instance_progress" ORDER BY "user"';
                } else {
                    sqlQuery = 'SELECT "course_type", "course_count" FROM "analytics"."analytics" ORDER BY "course_count" DESC';
                }
                System.debug('=== REQUEST DEBUG ===');
                System.debug('SQL Query: ' + sqlQuery);
                
                Map<String, Object> queryParams = new Map<String, Object>{
                    'query' => sqlQuery,
                    'format' => 'csv'
                };
                String requestBody = JSON.serialize(queryParams);
                queryRequest.setBody(requestBody);
                System.debug('Request Body: ' + requestBody);
                System.debug('Request Headers: Content-Type=' + queryRequest.getHeader('Content-Type') + ', Authorization=Bearer [REDACTED]');
                
                Http http = new Http();
                HttpResponse queryResponse = http.send(queryRequest);
                
                System.debug('=== RESPONSE DEBUG ===');
                System.debug('Query Response Status: ' + queryResponse.getStatusCode());
                System.debug('Query Response Headers: Content-Type=' + queryResponse.getHeader('Content-Type'));
                System.debug('Query Response Body Length: ' + queryResponse.getBody().length());
                System.debug('Query Response Body: ' + queryResponse.getBody());
                
                if (queryResponse.getStatusCode() != 200) {
                    System.debug('Error response from API: ' + queryResponse.getBody());
                    response.put('error', 'API returned status ' + queryResponse.getStatusCode() + ': ' + queryResponse.getBody());
                    return response;
                }
                
                // Parse job response
                Map<String, Object> jobResponse = (Map<String, Object>) JSON.deserializeUntyped(queryResponse.getBody());
                Map<String, Object> data = (Map<String, Object>) jobResponse.get('data');
                String jobId = (String) data.get('jobId');
                System.debug('Job ID: ' + jobId);
                
                // Step 2: Poll for job completion and get download link
                String downloadLink = null;
                Integer attempts = 0;
                
                while (attempts < MAX_POLLING_ATTEMPTS) {
                    attempts++;
                    System.debug('Polling attempt ' + attempts + ' of ' + MAX_POLLING_ATTEMPTS);
                    
                    // Check CPU time before polling
                    if (Limits.getCpuTime() > 14000) { // Leave some buffer
                        System.debug('CPU time limit approaching, breaking polling loop');
                        break;
                    }
                    
                    // Wait between polling attempts
                    if (attempts > 1) {
                        System.debug('Waiting ' + POLLING_DELAY_SECONDS + ' seconds before next attempt');
                        Integer delay = POLLING_DELAY_SECONDS * 1000; // Convert to milliseconds
                        Long startTime = System.currentTimeMillis();
                        while (System.currentTimeMillis() - startTime < delay) {
                            // Busy wait
                        }
                    }
                    
                    // Check job status
                    String statusEndpoint = BASE_URL + '/v1/reports/jobs/' + jobId;
                    HttpRequest statusRequest = new HttpRequest();
                    statusRequest.setEndpoint(statusEndpoint);
                    statusRequest.setMethod('GET');
                    statusRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                    
                    HttpResponse statusResponse = http.send(statusRequest);
                    System.debug('Status Response: ' + statusResponse.getBody());
                    
                    if (statusResponse.getStatusCode() == 200) {
                        Map<String, Object> statusResult = (Map<String, Object>) JSON.deserializeUntyped(statusResponse.getBody());
                        Map<String, Object> statusData = (Map<String, Object>) statusResult.get('data');
                        String status = (String) statusData.get('status');
                        
                        if (status == 'finished') {
                            downloadLink = (String) statusData.get('link');
                            System.debug('Job finished, download link: ' + downloadLink);
                            break;
                        } else if (status == 'failed') {
                            System.debug('Job failed');
                            response.put('error', 'Report generation failed');
                            return response;
                        }
                        // If still in progress, continue polling
                    }
                }
                
                if (downloadLink == null) {
                    System.debug('Job did not finish in time');
                    response.put('error', 'Report generation timed out');
                    return response;
                }
                
                // Step 3: Download and parse CSV
                HttpRequest downloadRequest = new HttpRequest();
                downloadRequest.setEndpoint(downloadLink);
                downloadRequest.setMethod('GET');
                downloadRequest.setHeader('Authorization', 'Bearer ' + accessToken);
                System.debug('Sending download request to: ' + downloadLink);
                
                HttpResponse downloadResponse = http.send(downloadRequest);
                System.debug('Download Response Status: ' + downloadResponse.getStatusCode());
                System.debug('Download Response Headers: ' + downloadResponse.getHeaderKeys());
                System.debug('Download Response Body Length: ' + downloadResponse.getBody().length());
                System.debug('Download Response Body: ' + downloadResponse.getBody());
                
                String csvData = downloadResponse.getBody();
                List<String> lines = csvData.split('\n');
                System.debug('Number of lines in CSV: ' + lines.size());
                
                List<Object> analyticsData = new List<Object>();
                for(Integer i = 1; i < lines.size(); i++) {
                    String line = lines[i];
                    if(String.isNotBlank(line)) {
                        System.debug('Processing line: ' + line);
                        List<String> values = new List<String>();
                        Boolean inQuotes = false;
                        String currentValue = '';
                        for(Integer j = 0; j < line.length(); j++) {
                            String c = line.substring(j, j+1);
                            if(c == '"') {
                                inQuotes = !inQuotes;
                            } else if(c == ',' && !inQuotes) {
                                values.add(currentValue.trim());
                                currentValue = '';
                            } else {
                                currentValue += c;
                            }
                        }
                        values.add(currentValue.trim());
                        System.debug('Split values: ' + values);
                        
                        try {
                            if (reportType == 'user_count_analytics' && values.size() >= 1) {
                                String userCount = values[0].removeStart('"').removeEnd('"');
                                System.debug('Parsed user_count: ' + userCount);
                                analyticsData.add(new Map<String, Object>{
                                    'id' => 'user-count-analytics',
                                    'title' => 'User Count Analytics',
                                    'description' => 'Total User Count from Analytics',
                                    'value' => Integer.valueOf(userCount),
                                    'user_count' => Integer.valueOf(userCount)
                                });
                                System.debug('Added user count data point');
                            } else if (reportType == 'user_course_progress' && values.size() >= 6) {
                                String userId = values[0].removeStart('"').removeEnd('"');
                                String userEmail = values[1].removeStart('"').removeEnd('"');
                                String userDisplayName = values[2].removeStart('"').removeEnd('"');
                                String courseId = values[3].removeStart('"').removeEnd('"');
                                String courseTitle = values[4].removeStart('"').removeEnd('"');
                                String startDate = values[5].removeStart('"').removeEnd('"');
                                String completionDate = values.size() > 6 ? values[6].removeStart('"').removeEnd('"') : '';
                                String lastProgressDate = values.size() > 7 ? values[7].removeStart('"').removeEnd('"') : '';
                                String courseInstance = values.size() > 8 ? values[8].removeStart('"').removeEnd('"') : '';
                                
                                System.debug('Parsed user course progress: ' + userDisplayName + ' - ' + courseTitle);
                                analyticsData.add(new Map<String, Object>{
                                    'id' => userId + '-' + courseId,
                                    'title' => userDisplayName + ' - ' + courseTitle,
                                    'description' => 'Started: ' + startDate + (String.isNotBlank(completionDate) ? ', Completed: ' + completionDate : ''),
                                    'user_id' => userId,
                                    'user_email' => userEmail,
                                    'user_display_name' => userDisplayName,
                                    'course_id' => courseId,
                                    'course_title' => courseTitle,
                                    'start_date' => startDate,
                                    'completion_date' => completionDate,
                                    'last_progress_date' => lastProgressDate,
                                    'course_instance' => courseInstance,
                                    'value' => String.isNotBlank(completionDate) ? 1 : 0 // 1 if completed, 0 if not
                                });
                                System.debug('Added user course progress data point');
                            } else if (reportType == 'course_type_analytics' && values.size() >= 2) {
                                String courseType = values[0].removeStart('"').removeEnd('"');
                                String courseCount = values[1].removeStart('"').removeEnd('"');
                                System.debug('Parsed values - courseType: ' + courseType + ', courseCount: ' + courseCount);
                                analyticsData.add(new Map<String, Object>{
                                    'course_type' => courseType,
                                    'course_count' => Integer.valueOf(courseCount)
                                });
                                System.debug('Added course type data point');
                            }
                        } catch(Exception e) {
                            System.debug('Error parsing line: ' + e.getMessage());
                            System.debug('Stack trace: ' + e.getStackTraceString());
                        }
                    }
                }
                
                if(analyticsData.isEmpty()) {
                    System.debug('No valid data points found in CSV');
                    response.put('error', 'No valid data points found in response');
                } else {
                    // Cache the successful response
                    cacheReportData(reportType, analyticsData);
                    
                    response.put('data', analyticsData);
                    response.put('cached', false);
                    response.put('lastUpdated', System.now());
                    System.debug('Analytics data retrieved successfully. Count: ' + analyticsData.size());
                    System.debug('Final data: ' + JSON.serialize(analyticsData));
                }
                return response;
            } else {
                // Get users data for other report types
                String usersEndpoint = BASE_URL + '/v0/users';
                System.debug('Fetching users from endpoint: ' + usersEndpoint);
                
                HttpRequest request = new HttpRequest();
                request.setEndpoint(usersEndpoint);
                request.setMethod('GET');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Authorization', 'Bearer ' + accessToken);
                
                Http http = new Http();
                HttpResponse httpResponse = http.send(request);
                
                System.debug('Response Status: ' + httpResponse.getStatusCode());
                System.debug('Response Body: ' + httpResponse.getBody());
                
                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
                    if (result.containsKey('data')) {
                        Object data = result.get('data');
                        List<Object> users;
                        
                        if (data instanceof List<Object>) {
                            users = (List<Object>)data;
                        } else if (data instanceof Map<String, Object>) {
                            users = new List<Object>{ data };
                        } else {
                            users = new List<Object>();
                        }
                        
                        List<Object> metricsData = new List<Object>();
                        metricsData.add(new Map<String, Object>{
                            'id' => 'user-metrics',
                            'title' => 'User Activity Metrics',
                            'description' => 'Total Users: ' + users.size(),
                            'value' => users.size()
                        });
                        
                        // Cache the successful response
                        cacheReportData(reportType, metricsData);
                        
                        response.put('data', metricsData);
                        response.put('cached', false);
                        response.put('lastUpdated', System.now());
                        System.debug('User metrics data processed successfully');
                    } else {
                        response.put('error', 'No data found in response');
                    }
                } else {
                    String errorMessage = 'Failed to fetch users. Status: ' + httpResponse.getStatusCode() + 
                                        ', Body: ' + httpResponse.getBody();
                    System.debug('Error: ' + errorMessage);
                    response.put('error', errorMessage);
                }
            }
            
        } catch (Exception e) {
            System.debug('=== EXCEPTION IN getInsightsReport ===');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('Type Name: ' + e.getTypeName());
            response.put('error', 'Unexpected error: ' + e.getMessage());
        }
        
        System.debug('=== FINAL RESPONSE ===');
        System.debug(JSON.serializePretty(response));
        return response;
    }

    @AuraEnabled
    public static String startUserCompletionsAnalyticsJob() {
        try {
            System.debug('=== STARTING USER COMPLETIONS ANALYTICS JOB ===');
            String tokenResponse = SanaLearnController.generateNewTokenWithScope('write');
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                throw new AuraHandledException('Failed to generate token: ' + tokenResponse);
            }
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            String queryEndpoint = BASE_URL + '/v1/reports/query';
            HttpRequest queryRequest = new HttpRequest();
            queryRequest.setEndpoint(queryEndpoint);
            queryRequest.setMethod('POST');
            queryRequest.setHeader('Content-Type', 'application/json');
            queryRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            String sqlQuery = 'SELECT "user", "courses_completed" FROM "analytics"."analytics"';
            Map<String, Object> queryParams = new Map<String, Object>{
                'query' => sqlQuery,
                'format' => 'csv'
            };
            String requestBody = JSON.serialize(queryParams);
            queryRequest.setBody(requestBody);
            Http http = new Http();
            HttpResponse queryResponse = http.send(queryRequest);
            if (queryResponse.getStatusCode() != 200) {
                throw new AuraHandledException('API returned status ' + queryResponse.getStatusCode() + ': ' + queryResponse.getBody());
            }
            Map<String, Object> jobResponse = (Map<String, Object>) JSON.deserializeUntyped(queryResponse.getBody());
            Map<String, Object> data = (Map<String, Object>) jobResponse.get('data');
            if (data == null || !data.containsKey('jobId')) {
                throw new AuraHandledException('No jobId in API response');
            }
            return (String) data.get('jobId');
        } catch (Exception e) {
            throw new AuraHandledException('Error starting user completions analytics job: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> checkAnalyticsJobStatus(String jobId) {
        try {
            System.debug('=== CHECKING USER COMPLETIONS ANALYTICS JOB STATUS ===');
            System.debug('Job ID: ' + jobId);
            
            String tokenResponse = SanaLearnController.generateNewTokenWithScope('read');
            System.debug('Token Response: ' + tokenResponse);
            
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                throw new AuraHandledException('Failed to generate token: ' + tokenResponse);
            }
            
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            String statusEndpoint = BASE_URL + '/v1/reports/jobs/' + jobId;
            System.debug('Status Endpoint: ' + statusEndpoint);
            
            HttpRequest statusRequest = new HttpRequest();
            statusRequest.setEndpoint(statusEndpoint);
            statusRequest.setMethod('GET');
            statusRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            System.debug('Request Headers: Authorization=Bearer [REDACTED]');
            
            Http http = new Http();
            HttpResponse statusResponse = http.send(statusRequest);
            System.debug('Status Response Status: ' + statusResponse.getStatusCode());
            System.debug('Status Response Body: ' + statusResponse.getBody());
            
            if (statusResponse.getStatusCode() != 200) {
                throw new AuraHandledException('API returned status ' + statusResponse.getStatusCode() + ': ' + statusResponse.getBody());
            }
            
            String responseBody = statusResponse.getBody();
            if (String.isBlank(responseBody)) {
                throw new AuraHandledException('Empty response body received from API');
            }
            
            try {
                Map<String, Object> statusResult = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                System.debug('Parsed Status Result: ' + JSON.serialize(statusResult));
                
                if (statusResult == null) {
                    throw new AuraHandledException('Failed to parse API response: null result');
                }
                
                if (!statusResult.containsKey('data')) {
                    throw new AuraHandledException('Invalid response format: missing data field');
                }
                
                Map<String, Object> data = (Map<String, Object>) statusResult.get('data');
                if (data == null) {
                    throw new AuraHandledException('Invalid response format: data field is null');
                }
                
                Map<String, Object> result = new Map<String, Object>();
                if (data.containsKey('status')) {
                    result.put('status', data.get('status'));
                } else {
                    throw new AuraHandledException('Invalid response format: missing status field');
                }
                
                if (data.containsKey('link')) {
                    result.put('link', data.get('link'));
                }
                
                System.debug('Final Result: ' + JSON.serialize(result));
                return result;
                
            } catch (JSONException je) {
                System.debug('JSON Parsing Error: ' + je.getMessage());
                System.debug('Stack Trace: ' + je.getStackTraceString());
                throw new AuraHandledException('Failed to parse API response: ' + je.getMessage());
            }
            
        } catch (AuraHandledException ae) {
            System.debug('AuraHandledException: ' + ae.getMessage());
            System.debug('Stack Trace: ' + ae.getStackTraceString());
            throw ae;
        } catch (Exception e) {
            System.debug('Unexpected Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Type Name: ' + e.getTypeName());
            throw new AuraHandledException('Error checking job status: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> fetchAnalyticsResult(String downloadLink, String reportType) {
        List<Map<String, Object>> analyticsData = new List<Map<String, Object>>();
        try {
            System.debug('=== FETCHING USER COMPLETIONS ANALYTICS RESULT ===');
            System.debug('Report Type: ' + reportType);
            String tokenResponse = SanaLearnController.generateNewTokenWithScope('read');
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                throw new AuraHandledException('Failed to generate token: ' + tokenResponse);
            }
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            HttpRequest downloadRequest = new HttpRequest();
            downloadRequest.setEndpoint(downloadLink);
            downloadRequest.setMethod('GET');
            downloadRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            System.debug('Sending download request to: ' + downloadLink);
            
            Http http = new Http();
            HttpResponse downloadResponse = http.send(downloadRequest);
            System.debug('Download Response Status: ' + downloadResponse.getStatusCode());
            System.debug('Download Response Headers: ' + downloadResponse.getHeaderKeys());
            System.debug('Download Response Body Length: ' + downloadResponse.getBody().length());
            System.debug('Download Response Body: ' + downloadResponse.getBody());
            
            String csvData = downloadResponse.getBody();
            System.debug('Raw CSV Data: ' + csvData);
            
            // Use simple string operations to avoid regex complexity
            // First, limit the data size to prevent issues
            if (csvData.length() > 50000) {
                csvData = csvData.substring(0, 50000); // Limit to first 50KB
                System.debug('CSV data truncated to 50KB to avoid complexity issues');
            }
            
            // Simple line parsing using indexOf instead of split
            List<String> lines = new List<String>();
            Integer startPos = 0;
            Integer newlinePos = csvData.indexOf('\n', startPos);
            
            while (newlinePos != -1 && lines.size() < 20) { // Limit to 20 lines max
                String line = csvData.substring(startPos, newlinePos).trim();
                if (String.isNotBlank(line)) {
                    lines.add(line);
                }
                startPos = newlinePos + 1;
                newlinePos = csvData.indexOf('\n', startPos);
            }
            
            // Add the last line if there's no trailing newline
            if (startPos < csvData.length() && lines.size() < 20) {
                String lastLine = csvData.substring(startPos).trim();
                if (String.isNotBlank(lastLine)) {
                    lines.add(lastLine);
                }
            }
            
            System.debug('CSV has ' + lines.size() + ' lines (limited)');
            for (Integer debugIdx = 0; debugIdx < lines.size() && debugIdx < 5; debugIdx++) {
                System.debug('Line ' + debugIdx + ': ' + lines[debugIdx]);
            }
            
            for(Integer i = 1; i < lines.size() && i < 10; i++) { // Limit to first 9 data rows to avoid governor limits
                String line = lines[i];
                if(String.isNotBlank(line)) {
                    System.debug('Processing line ' + i + ': ' + line);
                    
                    // Simple CSV parsing using indexOf instead of split
                    List<String> values = new List<String>();
                    Integer valueStart = 0;
                    Integer commaPos = line.indexOf(',', valueStart);
                    
                    while (commaPos != -1) {
                        values.add(line.substring(valueStart, commaPos));
                        valueStart = commaPos + 1;
                        commaPos = line.indexOf(',', valueStart);
                    }
                    
                    // Add the last value
                    if (valueStart < line.length()) {
                        values.add(line.substring(valueStart));
                    }
                    
                    System.debug('Parsed values for line ' + i + ': ' + values);
                    System.debug('Values size: ' + values.size());
                    
                    try {
                        if (reportType == 'user_completions_analytics' && values.size() >= 4) {
                            String userId = values[0].replace('"', '').trim();
                            String userEmail = values[1].replace('"', '').trim();
                            String userDisplayName = values[2].replace('"', '').trim();
                            String coursesCompleted = values[3].replace('"', '').trim();
                            
                            System.debug('Processing user: ' + userDisplayName + ' (' + userEmail + '), courses completed: ' + coursesCompleted);
                            
                            analyticsData.add(new Map<String, Object>{
                                'id' => 'user-' + userId,
                                'title' => userDisplayName,
                                'description' => userEmail + ' - Courses completed: ' + coursesCompleted,
                                'user_id' => userId,
                                'user_email' => userEmail,
                                'user_display_name' => userDisplayName,
                                'user' => userEmail, // Keep for backward compatibility
                                'courses_completed' => Integer.valueOf(coursesCompleted),
                                'value' => Integer.valueOf(coursesCompleted)
                            });
                        } else {
                            System.debug('Skipping line - report type: ' + reportType + ', values size: ' + values.size() + ' (need at least 4)');
                        }
                    } catch(Exception e) {
                        System.debug('Error parsing line ' + i + ': ' + e.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching analytics result: ' + e.getMessage());
        }
        
        System.debug('Final analytics data count: ' + analyticsData.size());
        System.debug('Final analytics data: ' + JSON.serialize(analyticsData));
        return analyticsData;
    }
    
    @AuraEnabled
    public static Map<String, Object> debugAnalyticsFlow() {
        Map<String, Object> debugResult = new Map<String, Object>();
        
        try {
            System.debug('=== DEBUG USER COMPLETIONS ANALYTICS FLOW START ===');
            
            // Step 1: Test write token generation
            System.debug('Step 1: Generating write token...');
            String writeTokenResponse = SanaLearnController.generateNewTokenWithScope('write');
            debugResult.put('writeTokenResponse', writeTokenResponse);
            System.debug('Write token response: ' + writeTokenResponse);
            
            if (!writeTokenResponse.startsWith('New token generated successfully: ')) {
                debugResult.put('error', 'Write token generation failed: ' + writeTokenResponse);
                return debugResult;
            }
            
            String writeToken = writeTokenResponse.substringAfter('New token generated successfully: ');
            debugResult.put('writeTokenLength', writeToken.length());
            debugResult.put('writeTokenPrefix', writeToken.substring(0, Math.min(writeToken.length(), 20)));
            
            // Test the write token with a simple endpoint first
            System.debug('Step 1.5: Testing write token with simple request...');
            HttpRequest testWriteRequest = new HttpRequest();
            testWriteRequest.setEndpoint(BASE_URL + '/v0/users?limit=1');
            testWriteRequest.setMethod('GET');
            testWriteRequest.setHeader('Authorization', 'Bearer ' + writeToken);
            
            Http testHttp = new Http();
            HttpResponse testWriteResponse = testHttp.send(testWriteRequest);
            debugResult.put('writeTokenTestStatus', testWriteResponse.getStatusCode());
            debugResult.put('writeTokenTestResponse', testWriteResponse.getBody());
            System.debug('Write token test - Status: ' + testWriteResponse.getStatusCode());
            System.debug('Write token test - Response: ' + testWriteResponse.getBody());
            
            // Step 2: Test job creation
            System.debug('Step 2: Creating analytics job...');
            String queryEndpoint = BASE_URL + '/v1/reports/query';
            HttpRequest queryRequest = new HttpRequest();
            queryRequest.setEndpoint(queryEndpoint);
            queryRequest.setMethod('POST');
            queryRequest.setHeader('Content-Type', 'application/json');
            queryRequest.setHeader('Authorization', 'Bearer ' + writeToken);
            
            String sqlQuery = 'SELECT "user", "courses_completed" FROM "analytics"."analytics"';
            Map<String, Object> queryParams = new Map<String, Object>{
                'query' => sqlQuery,
                'format' => 'csv'
            };
            String requestBody = JSON.serialize(queryParams);
            queryRequest.setBody(requestBody);
            
            Http http = new Http();
            HttpResponse queryResponse = http.send(queryRequest);
            
            debugResult.put('jobCreationStatus', queryResponse.getStatusCode());
            debugResult.put('jobCreationResponse', queryResponse.getBody());
            System.debug('Job creation status: ' + queryResponse.getStatusCode());
            System.debug('Job creation response: ' + queryResponse.getBody());
            
            if (queryResponse.getStatusCode() != 200) {
                debugResult.put('error', 'Job creation failed with status ' + queryResponse.getStatusCode());
                return debugResult;
            }
            
            Map<String, Object> jobResponse = (Map<String, Object>) JSON.deserializeUntyped(queryResponse.getBody());
            Map<String, Object> jobData = (Map<String, Object>) jobResponse.get('data');
            String jobId = (String) jobData.get('jobId');
            debugResult.put('jobId', jobId);
            
            // Step 3: Test read token generation
            System.debug('Step 3: Generating read token...');
            String readTokenResponse = SanaLearnController.generateNewTokenWithScope('read');
            debugResult.put('readTokenResponse', readTokenResponse);
            System.debug('Read token response: ' + readTokenResponse);
            
            if (!readTokenResponse.startsWith('New token generated successfully: ')) {
                debugResult.put('error', 'Read token generation failed: ' + readTokenResponse);
                return debugResult;
            }
            
            String readToken = readTokenResponse.substringAfter('New token generated successfully: ');
            debugResult.put('readTokenLength', readToken.length());
            debugResult.put('readTokenPrefix', readToken.substring(0, Math.min(readToken.length(), 20)));
            
            // Test the read token with a simple endpoint first
            System.debug('Step 3.5: Testing read token with simple request...');
            HttpRequest testReadRequest = new HttpRequest();
            testReadRequest.setEndpoint(BASE_URL + '/v0/users?limit=1');
            testReadRequest.setMethod('GET');
            testReadRequest.setHeader('Authorization', 'Bearer ' + readToken);
            
            HttpResponse testReadResponse = testHttp.send(testReadRequest);
            debugResult.put('readTokenTestStatus', testReadResponse.getStatusCode());
            debugResult.put('readTokenTestResponse', testReadResponse.getBody());
            System.debug('Read token test - Status: ' + testReadResponse.getStatusCode());
            System.debug('Read token test - Response: ' + testReadResponse.getBody());
            
                         // Step 4: Test job status check with multiple attempts
            System.debug('Step 4: Checking job status...');
            String statusEndpoint = BASE_URL + '/v1/reports/jobs/' + jobId;
            
            // Try up to 3 times to check status
            for (Integer attempt = 1; attempt <= 3; attempt++) {
                System.debug('Status check attempt ' + attempt);
                
                HttpRequest statusRequest = new HttpRequest();
                statusRequest.setEndpoint(statusEndpoint);
                statusRequest.setMethod('GET');
                statusRequest.setHeader('Authorization', 'Bearer ' + readToken);
                
                HttpResponse statusResponse = http.send(statusRequest);
                
                debugResult.put('statusCheckStatus' + attempt, statusResponse.getStatusCode());
                debugResult.put('statusCheckResponse' + attempt, statusResponse.getBody());
                debugResult.put('statusCheckHeaders' + attempt, statusResponse.getHeaderKeys());
                
                System.debug('Attempt ' + attempt + ' - Status: ' + statusResponse.getStatusCode());
                System.debug('Attempt ' + attempt + ' - Response: ' + statusResponse.getBody());
                System.debug('Attempt ' + attempt + ' - Headers: ' + statusResponse.getHeaderKeys());
                
                if (statusResponse.getStatusCode() == 200) {
                    try {
                        Map<String, Object> statusResult = (Map<String, Object>) JSON.deserializeUntyped(statusResponse.getBody());
                        debugResult.put('statusResultParsed' + attempt, true);
                        
                        if (statusResult.containsKey('data')) {
                            Map<String, Object> statusData = (Map<String, Object>) statusResult.get('data');
                            String jobStatus = (String) statusData.get('status');
                            debugResult.put('jobStatus' + attempt, jobStatus);
                            
                            if (statusData.containsKey('link')) {
                                debugResult.put('jobLink' + attempt, statusData.get('link'));
                            }
                            
                            // If successful, break out of loop
                            if (jobStatus == 'successful' || jobStatus == 'finished') {
                                debugResult.put('finalJobStatus', jobStatus);
                                break;
                            }
                        } else {
                            debugResult.put('statusDataMissing' + attempt, true);
                        }
                    } catch (Exception parseEx) {
                        debugResult.put('statusParseError' + attempt, parseEx.getMessage());
                        System.debug('Parse error on attempt ' + attempt + ': ' + parseEx.getMessage());
                    }
                } else {
                    debugResult.put('statusCheckError' + attempt, 'HTTP ' + statusResponse.getStatusCode());
                }
                
                // Wait 1 second between attempts (if not last attempt)
                if (attempt < 3) {
                    // Simple wait - not ideal for production but fine for debugging
                    Long startTime = System.currentTimeMillis();
                    while (System.currentTimeMillis() - startTime < 1000) {
                        // Busy wait for 1 second
                    }
                }
            }
            
            debugResult.put('success', true);
            System.debug('=== DEBUG USER COMPLETIONS ANALYTICS FLOW SUCCESS ===');
            
        } catch (Exception e) {
            System.debug('=== DEBUG USER COMPLETIONS ANALYTICS FLOW ERROR ===');
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            debugResult.put('error', 'Exception: ' + e.getMessage());
            debugResult.put('stackTrace', e.getStackTraceString());
        }
        
        return debugResult;
    }
    
    private static SanaAnalyticsCache__c getCachedReport(String reportType) {
        try {
            List<SanaAnalyticsCache__c> caches = [
                SELECT Id, ReportType__c, ReportData__c, LastUpdated__c 
                FROM SanaAnalyticsCache__c 
                WHERE ReportType__c = :reportType 
                ORDER BY LastUpdated__c DESC 
                LIMIT 1
            ];
            
            if (!caches.isEmpty()) {
                SanaAnalyticsCache__c cache = caches[0];
                DateTime lastUpdated = cache.LastUpdated__c;
                DateTime now = System.now();
                
                // Check if cache is still valid (within 24 hours)
                if (lastUpdated.addHours(CACHE_DURATION_HOURS) > now) {
                    return cache;
                }
            }
        } catch (Exception e) {
            System.debug('Error retrieving cache: ' + e.getMessage());
        }
        return null;
    }
    
    private static void cacheReportData(String reportType, List<Object> data) {
        try {
            // Delete any existing cache for this report type
            List<SanaAnalyticsCache__c> existingCaches = [
                SELECT Id 
                FROM SanaAnalyticsCache__c 
                WHERE ReportType__c = :reportType
            ];
            if (!existingCaches.isEmpty()) {
                delete existingCaches;
            }
            
            // Create new cache entry
            SanaAnalyticsCache__c cache = new SanaAnalyticsCache__c(
                Name = reportType + ' - ' + System.now().format(),
                ReportType__c = reportType,
                ReportData__c = JSON.serialize(data),
                LastUpdated__c = System.now()
            );
            insert cache;
            
            System.debug('Successfully cached report data for: ' + reportType);
        } catch (Exception e) {
            System.debug('Error caching report data: ' + e.getMessage());
        }
    }
} 