public with sharing class SanaLearnController {
    private static String getCourseTitle(String courseId, String token) {
        try {
            System.debug('=== COURSE TITLE REQUEST ===');
            System.debug('Course ID: ' + courseId);
            String courseEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/courses/' + courseId;
            System.debug('Endpoint: ' + courseEndpoint);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(courseEndpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + token);
            
            HttpResponse response = http.send(request);
            System.debug('=== COURSE API RESPONSE ===');
            System.debug('Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                System.debug('Parsed Response: ' + JSON.serializePretty(result));
                
                if (result.containsKey('data')) {
                    Map<String, Object> courseData = (Map<String, Object>)result.get('data');
                    System.debug('Course Data: ' + JSON.serializePretty(courseData));
                    String title = (String)courseData.get('title');
                    System.debug('Found title: ' + title);
                    return title;
                }
            }
            return null;
        } catch (Exception e) {
            System.debug('Error fetching course title: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }

    @AuraEnabled
    public static Map<String, Object> getUserAssignments(String userEmail) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            if (String.isBlank(userEmail)) {
                System.debug('Error: userEmail is null or empty');
                response.put('error', 'User email is required');
                return response;
            }
            
            // First, generate a token for API authentication
            String tokenResponse = generateNewToken();
            System.debug('Token response: ' + tokenResponse);
            
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                response.put('error', 'Failed to generate token: ' + tokenResponse);
                return response;
            }
            
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            System.debug('Extracted access token');
            
            // Now, let's get the user ID from the email
            String usersEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/users?email=' + EncodingUtil.urlEncode(userEmail, 'UTF-8');
            System.debug('=== GET USER BY EMAIL REQUEST ===');
            System.debug('Endpoint: ' + usersEndpoint);
            
            Http http = new Http();
            HttpRequest usersRequest = new HttpRequest();
            usersRequest.setEndpoint(usersEndpoint);
            usersRequest.setMethod('GET');
            usersRequest.setHeader('Content-Type', 'application/json');
            usersRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            
            System.debug('=== USERS REQUEST DETAILS ===');
            System.debug('Method: ' + usersRequest.getMethod());
            System.debug('Headers: ' + usersRequest.getHeader('Content-Type'));
            
            HttpResponse usersResponse;
            try {
                usersResponse = http.send(usersRequest);
            } catch (Exception e) {
                response.put('error', 'HTTP Request failed: ' + e.getMessage());
                return response;
            }
            
            System.debug('=== USERS RESPONSE DETAILS ===');
            System.debug('Status Code: ' + usersResponse.getStatusCode());
            System.debug('Response Body: ' + usersResponse.getBody());
            
            if (usersResponse.getStatusCode() != 200) {
                response.put('error', 'Failed to fetch user: ' + usersResponse.getBody());
                return response;
            }
            
            // Parse the users response to get the user ID
            Map<String, Object> usersResult = (Map<String, Object>) JSON.deserializeUntyped(usersResponse.getBody());
            Object dataObj = usersResult.get('data');
            List<Object> users;
            
            // Handle different possible data structures
            if (dataObj instanceof List<Object>) {
                users = (List<Object>)dataObj;
            } else if (dataObj instanceof Map<String, Object>) {
                // Handle case where data might be a single object rather than an array
                users = new List<Object>{ dataObj };
            } else {
                users = new List<Object>();
            }
            
            if (users == null || users.isEmpty()) {
                response.put('error', 'No user found with email: ' + userEmail);
                return response;
            }
            
            // Get the user's ID
            Map<String, Object> user = (Map<String, Object>)users[0];
            String userId = (String)user.get('id');
            System.debug('Found user ID: ' + userId);
            
            // Now use this user ID to fetch assignments
            String assignmentsEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/users/' + userId + '/assignments';
            System.debug('=== GET ASSIGNMENTS REQUEST ===');
            System.debug('Endpoint: ' + assignmentsEndpoint);
            System.debug('User ID: ' + userId);
            
            HttpRequest assignmentsRequest = new HttpRequest();
            assignmentsRequest.setEndpoint(assignmentsEndpoint);
            assignmentsRequest.setMethod('GET');
            assignmentsRequest.setHeader('Content-Type', 'application/json');
            assignmentsRequest.setHeader('Authorization', 'Bearer ' + accessToken);
            
            System.debug('=== ASSIGNMENTS REQUEST DETAILS ===');
            System.debug('Method: ' + assignmentsRequest.getMethod());
            System.debug('Headers: ' + assignmentsRequest.getHeader('Content-Type'));
            
            HttpResponse assignmentsResponse;
            try {
                assignmentsResponse = http.send(assignmentsRequest);
            } catch (Exception e) {
                response.put('error', 'HTTP Request failed: ' + e.getMessage());
                return response;
            }
            
            System.debug('=== ASSIGNMENTS RESPONSE DETAILS ===');
            System.debug('Status Code: ' + assignmentsResponse.getStatusCode());
            System.debug('Response Body: ' + assignmentsResponse.getBody());
            
            if (assignmentsResponse.getStatusCode() == 200) {
                String responseBody = assignmentsResponse.getBody();
                if (String.isBlank(responseBody)) {
                    System.debug('Empty response body received');
                    response.put('assignments', new List<Object>());
                    return response;
                }
                
                try {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    System.debug('=== ASSIGNMENTS RESPONSE ===');
                    System.debug('Full response: ' + JSON.serializePretty(result));
                    
                    if (result.containsKey('data')) {
                        Object data = result.get('data');
                        List<Object> processedAssignments = new List<Object>();
                        
                        if (data instanceof Map<String, Object>) {
                            Map<String, Object> assignment = (Map<String, Object>)data;
                            System.debug('=== SINGLE ASSIGNMENT ===');
                            System.debug('Assignment: ' + JSON.serializePretty(assignment));
                            
                            if (assignment.containsKey('content')) {
                                Object content = assignment.get('content');
                                System.debug('Content: ' + JSON.serializePretty(content));
                                
                                if (content instanceof Map<String, Object>) {
                                    Map<String, Object> contentMap = (Map<String, Object>)content;
                                    if (contentMap.containsKey('id')) {
                                        String courseId = (String)contentMap.get('id');
                                        System.debug('Course ID: ' + courseId);
                                        String courseTitle = getCourseTitle(courseId, accessToken);
                                        assignment.put('courseTitle', courseTitle);
                                    }
                                }
                            }
                            processedAssignments.add(assignment);
                        } else if (data instanceof List<Object>) {
                            for (Object assignmentObj : (List<Object>)data) {
                                Map<String, Object> assignment = (Map<String, Object>)assignmentObj;
                                System.debug('=== ASSIGNMENT ===');
                                System.debug('Assignment: ' + JSON.serializePretty(assignment));
                                
                                if (assignment.containsKey('content')) {
                                    Object content = assignment.get('content');
                                    System.debug('Content: ' + JSON.serializePretty(content));
                                    
                                    if (content instanceof Map<String, Object>) {
                                        Map<String, Object> contentMap = (Map<String, Object>)content;
                                        if (contentMap.containsKey('id')) {
                                            String courseId = (String)contentMap.get('id');
                                            System.debug('Course ID: ' + courseId);
                                            String courseTitle = getCourseTitle(courseId, accessToken);
                                            assignment.put('courseTitle', courseTitle);
                                        }
                                    }
                                }
                                processedAssignments.add(assignment);
                            }
                        }
                        
                        response.put('assignments', processedAssignments);
                    } else {
                        response.put('assignments', new List<Object>());
                    }
                } catch (JSONException je) {
                    System.debug('JSON parsing error: ' + je.getMessage());
                    response.put('error', 'Invalid JSON response: ' + je.getMessage());
                    return response;
                }
            } else {
                String errorMessage;
                try {
                    if (String.isNotBlank(assignmentsResponse.getBody())) {
                        Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(assignmentsResponse.getBody());
                        errorMessage = errorResponse.containsKey('error') ? 
                            String.valueOf(errorResponse.get('error')) : 
                            'API call failed: ' + assignmentsResponse.getStatusCode() + ' ' + assignmentsResponse.getStatus();
                    } else {
                        errorMessage = 'API call failed with status ' + assignmentsResponse.getStatusCode() + 
                                     ' and empty response body';
                    }
                } catch (Exception e) {
                    errorMessage = 'API call failed with status ' + assignmentsResponse.getStatusCode() + 
                                 '. Response: ' + assignmentsResponse.getBody();
                }
                System.debug('Error: ' + errorMessage);
                response.put('error', errorMessage);
                return response;
            }
            
            return response;
        } catch (Exception e) {
            System.debug('Unexpected Exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            response.put('error', 'Unexpected error: ' + e.getMessage());
            return response;
        }
    }

    @AuraEnabled
    public static String testConnection() {
        try {
            System.debug('=== STARTING TEST CONNECTION ===');
            
            // Set to false to use the real API
            Boolean useMockResponse = false;
            if (useMockResponse) {
                System.debug('Using mock response for testing');
                return 'Connection successful! This is a mock response for testing. The component is working correctly.';
            }
            
            // First, generate a new token
            System.debug('Attempting to generate new token...');
            String tokenResponse = generateNewToken();
            System.debug('Token response: ' + tokenResponse);
            
            if (!tokenResponse.startsWith('New token generated successfully: ')) {
                // Don't throw exception, just return error message
                return 'Failed to generate token: ' + tokenResponse;
            }
            
            String accessToken = tokenResponse.substringAfter('New token generated successfully: ');
            System.debug('Extracted access token');
            
            // Now use the token to test the connection with a simple endpoint
            String endpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/users?limit=1';
            System.debug('Testing endpoint: ' + endpoint);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            
            System.debug('=== TEST CONNECTION REQUEST ===');
            System.debug('Method: ' + request.getMethod());
            System.debug('Endpoint: ' + request.getEndpoint());
            System.debug('Content-Type: ' + request.getHeader('Content-Type'));
            
            HttpResponse response;
            try {
                response = http.send(request);
            } catch (Exception e) {
                System.debug('HTTP Request Exception: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                return 'HTTP Request failed: ' + e.getMessage();
            }
            
            System.debug('=== TEST CONNECTION RESPONSE ===');
            System.debug('Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                return 'Connection successful! API response received.';
            } else {
                String errorMessage = 'Connection failed with status ' + response.getStatusCode();
                if (String.isNotBlank(response.getBody())) {
                    try {
                        Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        System.debug('Error response: ' + JSON.serializePretty(errorResponse));
                        if (errorResponse.containsKey('error')) {
                            errorMessage += ' - Error: ' + errorResponse.get('error');
                        }
                        if (errorResponse.containsKey('error_description')) {
                            errorMessage += ' - Description: ' + errorResponse.get('error_description');
                        }
                    } catch (Exception e) {
                        System.debug('Error parsing error response: ' + e.getMessage());
                        errorMessage += ' - Raw Response: ' + response.getBody();
                    }
                }
                return errorMessage;
            }
        } catch (Exception e) {
            System.debug('Error in testConnection: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw exception, just return error message
            return 'Connection test failed: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String generateNewToken() {
        try {
            System.debug('=== STARTING TOKEN GENERATION ===');
            
            // For debugging only - return a test token to see if the rest of the flow works
            Boolean useTestToken = false; // Set to true to bypass actual API call
            if (useTestToken) {
                System.debug('Using test token for debugging');
                return 'New token generated successfully: TEST_TOKEN_12345';
            }
            
            String tokenEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/token';
            System.debug('Token endpoint: ' + tokenEndpoint);
            
            // Sana API credentials
            String clientId = 'JmtkYyfU8wA5';
            String clientSecret = '824f4604cf1b45a3a15205f8f9ae5cd1';
            
            // Prepare the HTTP request
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(tokenEndpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setHeader('Accept', 'application/json');
            
            // Set the request body with all required parameters as shown in the documentation
            String requestBody = 'grant_type=client_credentials&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') + 
                              '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') + 
                              '&scope=read,write';
            request.setBody(requestBody);
            
            // Set timeout and log request details
            request.setTimeout(30000); // 30 seconds timeout
            System.debug('=== TOKEN REQUEST DETAILS ===');
            System.debug('Endpoint: ' + request.getEndpoint());
            System.debug('Method: ' + request.getMethod());
            System.debug('Headers: Content-Type=' + request.getHeader('Content-Type') + 
                         ', Accept=' + request.getHeader('Accept'));
            System.debug('Using Basic Authentication with client ID: ' + clientId);
            
            // Send the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
            } catch (System.CalloutException ce) {
                // Handle callout exceptions separately (often due to Salesforce config issues)
                System.debug('CalloutException: ' + ce.getMessage());
                if (ce.getMessage().contains('Unauthorized endpoint')) {
                    return 'Error: Unauthorized endpoint. Please verify Remote Site Settings for: ' + tokenEndpoint;
                } else {
                    return 'Callout error: ' + ce.getMessage();
                }
            }
            
            // Process the response
            System.debug('=== TOKEN RESPONSE ===');
            System.debug('Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                // Success - parse the response and extract the token
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                if (result.containsKey('data')) {
                    Map<String, Object> data = (Map<String, Object>)result.get('data');
                    if (data.containsKey('accessToken')) {
                        String accessToken = (String)data.get('accessToken');
                        System.debug('Successfully obtained access token');
                        return 'New token generated successfully: ' + accessToken;
                    } else {
                        return 'Response data does not contain accessToken';
                    }
                } else {
                    return 'Response does not contain data element';
                }
            } else {
                // Error - parse the error response
                String errorMessage = 'Token generation failed with status ' + response.getStatusCode();
                if (String.isNotBlank(response.getBody())) {
                    try {
                        Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        if (errorResponse.containsKey('error')) {
                            errorMessage += ' - Error: ' + errorResponse.get('error');
                        }
                        if (errorResponse.containsKey('error_description')) {
                            errorMessage += ' - Description: ' + errorResponse.get('error_description');
                        }
                    } catch (Exception e) {
                        errorMessage += ' - Response: ' + response.getBody();
                    }
                }
                return errorMessage;
            }
        } catch (Exception e) {
            // Log and return error message
            System.debug('Error in generateNewToken: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return 'Token generation failed: ' + e.getMessage();
        }
    }
} 