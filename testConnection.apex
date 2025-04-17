try {
    String result = SanaLearnController.testConnection();
    System.debug('Test Connection Result: ' + result);
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}
