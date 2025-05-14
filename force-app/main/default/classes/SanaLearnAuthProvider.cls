global class SanaLearnAuthProvider extends Auth.AuthProviderPluginClass {
    global String getCustomMetadataType() {
        return null;
    }

    global PageReference initiate(Map<string,string> authProviderConfiguration, String stateToPropagate) {
        String authUrl = authProviderConfiguration.get('Authorize_Endpoint_URL');
        PageReference pageRef = new PageReference(authUrl);
        return pageRef;
    }

    global Auth.AuthProviderTokenResponse handleCallback(Map<string,string> authProviderConfiguration, Auth.AuthProviderCallbackState state) {
        String accessToken = state.queryParameters.get('access_token');
        String refreshToken = state.queryParameters.get('refresh_token');
        return new Auth.AuthProviderTokenResponse('SanaLearnAuth', accessToken, refreshToken, null);
    }

    global Auth.UserData getUserInfo(Map<string,string> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData(
            'sanaUserId',
            'firstName',
            'lastName',
            'fullName',
            'email@example.com',
            'link',
            'username',
            'locale',
            'provider',
            null,
            new Map<String, String>()
        );
    }
} 