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
        try {
            if (String.isBlank(userEmail)) {
                System.debug('Error: userEmail is null or empty');
                throw new AuraHandledException('User email is required');
            }

            // Use the new token
            String workingToken = 'eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWI4NjI1ZS05MmEwLTQ5OWQtYjVmYi1mNWRlMGE0NzNjZGIiLCJpc3MiOiJkYmVyZ3F2aXN0LXNhbmRib3guc2FuYS5haSIsImNpZCI6IkptdGtZeWZVOHdBNSIsInNjcCI6WyJyZWFkIiwid3JpdGUiXSwiZXhwIjoxNzQ0ODA0MjE1fQ.7ghUThnkarpwj_rYoHMI5T1haCsnwwm2FC7GG18K8UF8EB2wiRqP2HLTb8bBuWESmki_Yi0k5BfR_D9OhUL-kQ';
            
            // First, let's get the user ID from the email
            String usersEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/users?email=' + EncodingUtil.urlEncode(userEmail, 'UTF-8');
            System.debug('=== GET USER BY EMAIL REQUEST ===');
            System.debug('Endpoint: ' + usersEndpoint);
            
            Http http = new Http();
            HttpRequest usersRequest = new HttpRequest();
            usersRequest.setEndpoint(usersEndpoint);
            usersRequest.setMethod('GET');
            usersRequest.setHeader('Content-Type', 'application/json');
            usersRequest.setHeader('Authorization', 'Bearer ' + workingToken);
            
            System.debug('=== USERS REQUEST DETAILS ===');
            System.debug('Method: ' + usersRequest.getMethod());
            System.debug('Headers: ' + usersRequest.getHeader('Content-Type'));
            System.debug('Auth Header: Bearer ' + workingToken.substring(0, 20) + '...');
            
            HttpResponse usersResponse = http.send(usersRequest);
            System.debug('=== USERS RESPONSE DETAILS ===');
            System.debug('Status Code: ' + usersResponse.getStatusCode());
            System.debug('Response Body: ' + usersResponse.getBody());
            
            if (usersResponse.getStatusCode() != 200) {
                throw new AuraHandledException('Failed to fetch user: ' + usersResponse.getBody());
            }
            
            // Parse the users response to get the user ID
            Map<String, Object> usersResult = (Map<String, Object>) JSON.deserializeUntyped(usersResponse.getBody());
            List<Object> users = (List<Object>)usersResult.get('data');
            
            if (users == null || users.isEmpty()) {
                throw new AuraHandledException('No user found with email: ' + userEmail);
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
            assignmentsRequest.setHeader('Authorization', 'Bearer ' + workingToken);
            
            System.debug('=== ASSIGNMENTS REQUEST DETAILS ===');
            System.debug('Method: ' + assignmentsRequest.getMethod());
            System.debug('Headers: ' + assignmentsRequest.getHeader('Content-Type'));
            System.debug('Auth Header: Bearer ' + workingToken.substring(0, 20) + '...');
            
            HttpResponse assignmentsResponse = http.send(assignmentsRequest);
            System.debug('=== ASSIGNMENTS RESPONSE DETAILS ===');
            System.debug('Status Code: ' + assignmentsResponse.getStatusCode());
            System.debug('Response Body: ' + assignmentsResponse.getBody());
            
            Map<String, Object> response = new Map<String, Object>();
            
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
                                        String courseTitle = getCourseTitle(courseId, workingToken);
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
                                            String courseTitle = getCourseTitle(courseId, workingToken);
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
                    throw new AuraHandledException('Invalid JSON response: ' + je.getMessage());
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
                throw new AuraHandledException(errorMessage);
            }
            
            return response;
        } catch (AuraHandledException e) {
            System.debug('AuraHandledException: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Unexpected Exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String testConnection() {
        try {
            // Use the new token
            String workingToken = 'eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWI4NjI1ZS05MmEwLTQ5OWQtYjVmYi1mNWRlMGE0NzNjZGIiLCJpc3MiOiJkYmVyZ3F2aXN0LXNhbmRib3guc2FuYS5haSIsImNpZCI6IkptdGtZeWZVOHdBNSIsInNjcCI6WyJyZWFkIiwid3JpdGUiXSwiZXhwIjoxNzQ0ODA0MjE1fQ.7ghUThnkarpwj_rYoHMI5T1haCsnwwm2FC7GG18K8UF8EB2wiRqP2HLTb8bBuWESmki_Yi0k5BfR_D9OhUL-kQ';
            
            String apiEndpoint = 'https://dbergqvist-sandbox.sana.ai/api/v0/users?limit=1';
            System.debug('Testing API with known working token');
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(apiEndpoint);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + workingToken);
            
            System.debug('=== DIRECT API REQUEST WITH WORKING TOKEN ===');
            System.debug('Endpoint: ' + apiEndpoint);
            System.debug('Authorization Header: Bearer ' + workingToken.substring(0, 20) + '...');
            
            HttpResponse response = http.send(request);
            System.debug('=== DIRECT API RESPONSE ===');
            System.debug('Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                return 'Connection successful with direct token! Response: ' + response.getBody();
            }
            
            // If direct token works but Named Credential doesn't, we know it's a Named Credential issue
            String ncEndpoint = 'callout:SanaLearn_API/api/v0/users?limit=1';
            System.debug('Testing Named Credential endpoint: ' + ncEndpoint);
            
            HttpRequest ncRequest = new HttpRequest();
            ncRequest.setEndpoint(ncEndpoint);
            ncRequest.setMethod('GET');
            ncRequest.setHeader('Content-Type', 'application/json');
            
            System.debug('=== NAMED CREDENTIAL REQUEST ===');
            System.debug('Method: ' + ncRequest.getMethod());
            System.debug('Endpoint: ' + ncRequest.getEndpoint());
            
            HttpResponse ncResponse = http.send(ncRequest);
            System.debug('=== NAMED CREDENTIAL RESPONSE ===');
            System.debug('Status Code: ' + ncResponse.getStatusCode());
            System.debug('Response Body: ' + ncResponse.getBody());
            
            if (ncResponse.getStatusCode() == 200) {
                return 'Connection successful with Named Credential! Response: ' + ncResponse.getBody();
            } else if (ncResponse.getStatusCode() == 401) {
                String errorMessage = 'Authentication failed (401 Unauthorized). Please verify:\n\n' +
                                    'Named Credential Settings:\n' +
                                    '1. URL: Should be https://dbergqvist-sandbox.sana.ai\n' +
                                    '2. Authentication Protocol: OAuth 2.0\n' +
                                    '3. Identity Type: Named Principal\n' +
                                    '4. All checkboxes should be checked\n\n' +
                                    'Auth Provider Settings:\n' +
                                    '1. Token Endpoint URL: Should be https://dbergqvist-sandbox.sana.ai/api/token\n' +
                                    '2. Authorize Endpoint URL: Should be https://dbergqvist-sandbox.sana.ai/api/token\n' +
                                    '3. Client ID: JmtkYyfU8wA5\n' +
                                    '4. Client Secret: 824f4604cf1b45a3a15205f8f9ae5cd1\n' +
                                    '5. Send Client Credentials in Header: Should be UNCHECKED\n' +
                                    '6. Default Scopes: Should be "read,write" (with comma)\n\n';
                
                if (String.isNotBlank(ncResponse.getBody())) {
                    errorMessage += 'API Response: ' + ncResponse.getBody() + '\n\n';
                }
                
                // Add Named Credential debug info
                try {
                    NamedCredential nc = [SELECT Id, DeveloperName, Endpoint, AuthProviderId FROM NamedCredential WHERE DeveloperName = 'SanaLearn_API' LIMIT 1];
                    AuthProvider ap = [SELECT Id, ConsumerKey FROM AuthProvider WHERE Id = :nc.AuthProviderId LIMIT 1];
                    errorMessage += 'Named Credential Info:\n';
                    errorMessage += 'Developer Name: ' + nc.DeveloperName + '\n';
                    errorMessage += 'Endpoint: ' + nc.Endpoint + '\n';
                    errorMessage += 'Auth Provider ID: ' + nc.AuthProviderId + '\n';
                    errorMessage += 'Client ID: ' + ap.ConsumerKey + '\n\n';
                } catch (Exception e) {
                    errorMessage += 'Could not retrieve Named Credential info: ' + e.getMessage() + '\n\n';
                }
                
                errorMessage += 'Please also check:\n' +
                              '1. The Named Credential URL is exactly: https://dbergqvist-sandbox.sana.ai\n' +
                              '2. The Auth Provider endpoints are correct\n' +
                              '3. The Client ID and Secret are correct\n' +
                              '4. Your Salesforce org has network access to the API domain\n' +
                              '5. Try to authenticate the Named Credential manually in Setup';
                
                return errorMessage;
            } else {
                return 'Connection failed with status ' + ncResponse.getStatusCode() + '. Response: ' + ncResponse.getBody();
            }
        } catch (Exception e) {
            System.debug('Error in testConnection: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Connection test failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String generateNewToken() {
        try {
            // Use the Named Credential endpoint
            String tokenEndpoint = 'callout:SanaLearn_API/api/token';
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(tokenEndpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            request.setHeader('Accept', 'application/json');
            
            // The Named Credential should handle the authentication
            // We just need to specify the grant type
            String requestBody = 'grant_type=client_credentials';
            request.setBody(requestBody);
            
            System.debug('=== TOKEN REQUEST ===');
            System.debug('Endpoint: ' + tokenEndpoint);
            System.debug('Method: ' + request.getMethod());
            System.debug('Headers: ' + request.getHeader('Content-Type'));
            System.debug('Request Body: ' + requestBody);
            
            // Add timeout to prevent hanging
            request.setTimeout(120000); // 2 minutes timeout
            
            HttpResponse response;
            try {
                response = http.send(request);
            } catch (Exception e) {
                System.debug('HTTP Request Exception: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                throw new AuraHandledException('HTTP Request failed: ' + e.getMessage());
            }
            
            System.debug('=== TOKEN RESPONSE ===');
            System.debug('Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                try {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    if (result.containsKey('access_token')) {
                        String accessToken = (String)result.get('access_token');
                        return 'New token generated successfully: ' + accessToken;
                    } else {
                        throw new AuraHandledException('Response does not contain access_token: ' + response.getBody());
                    }
                } catch (Exception e) {
                    System.debug('JSON Parsing Exception: ' + e.getMessage());
                    throw new AuraHandledException('Failed to parse token response: ' + e.getMessage());
                }
            } else {
                String errorMessage = 'Failed to generate token. Status: ' + response.getStatusCode();
                if (String.isNotBlank(response.getBody())) {
                    try {
                        Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        if (errorResponse.containsKey('error')) {
                            errorMessage += '\nError: ' + errorResponse.get('error');
                        }
                        if (errorResponse.containsKey('error_description')) {
                            errorMessage += '\nDescription: ' + errorResponse.get('error_description');
                        }
                    } catch (Exception e) {
                        errorMessage += '\nResponse: ' + response.getBody();
                    }
                }
                throw new AuraHandledException(errorMessage);
            }
        } catch (AuraHandledException e) {
            System.debug('AuraHandledException: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Unexpected Exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
} 