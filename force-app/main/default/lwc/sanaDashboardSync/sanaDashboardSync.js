import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncUserCompletionData from '@salesforce/apex/SanaDashboardDataSync.syncUserCompletionData';
import getLastSyncInfo from '@salesforce/apex/SanaDashboardDataSync.getLastSyncInfo';

export default class SanaDashboardSync extends LightningElement {
    @track isLoading = false;
    @track lastSyncInfo = '';

    connectedCallback() {
        this.loadSyncInfo();
    }

    async loadSyncInfo() {
        try {
            this.lastSyncInfo = await getLastSyncInfo();
        } catch (error) {
            console.error('Error loading sync info:', error);
        }
    }

    async handleSyncData() {
        this.isLoading = true;
        
        try {
            const result = await syncUserCompletionData();
            
            this.showToast('Success', result, 'success');
            await this.loadSyncInfo(); // Refresh sync info
            
        } catch (error) {
            console.error('Sync error:', error);
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
} 