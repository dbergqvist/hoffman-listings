import { LightningElement, track } from 'lwc';
import testConnection from '@salesforce/apex/SanaLearnController.testConnection';

export default class SanaConnectionTestLWC extends LightningElement {
    @track connectionResult = '';
    @track isLoading = false;
    @track hasError = false;

    get resultClass() {
        return this.hasError ? 'slds-text-color_error' : 'slds-text-color_success';
    }

    handleTestConnection() {
        this.isLoading = true;
        this.connectionResult = '';
        this.hasError = false;

        testConnection()
            .then(result => {
                this.connectionResult = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.hasError = true;
                this.connectionResult = 'Error: ' + (error.body?.message || error.message || JSON.stringify(error));
                this.isLoading = false;
                console.error('Error testing connection:', error);
            });
    }
}