({
    testConnection: function(component, event, helper) {
        component.set('v.isLoading', true);
        component.set('v.connectionStatus', '');
        
        var action = component.get('c.testConnection');
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set('v.connectionStatus', response.getReturnValue());
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        component.set('v.connectionStatus', 'Error: ' + errors[0].message);
                    }
                } else {
                    component.set('v.connectionStatus', 'Unknown error');
                }
            }
        });
        $A.enqueueAction(action);
    }
}) 