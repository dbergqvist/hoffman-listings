@isTest
public class SanaConnectionTest {
    @isTest
    static void testTokenGeneration() {
        Test.startTest();
        String result = SanaLearnController.generateNewToken();
        Test.stopTest();
        
        System.debug('Token generation result: ' + result);
        System.assert(result.startsWith('New token generated successfully: '), 
            'Token generation failed: ' + result);
    }
    
    @isTest
    static void testInsightsReport() {
        Test.startTest();
        Map<String, Object> result = SanaInsightsController.getInsightsReport('monthly_active_users');
        Test.stopTest();
        
        System.debug('Insights report result: ' + JSON.serializePretty(result));
        System.assert(!result.containsKey('error'), 
            'Insights report failed: ' + result.get('error'));
    }
} 