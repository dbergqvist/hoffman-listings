global class SanaLearnAuthRegistrationHandler implements Auth.RegistrationHandler {
    global User createUser(Id portalId, Auth.UserData data) {
        return null;
    }
    
    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        // No implementation needed for client credentials flow
    }
} 