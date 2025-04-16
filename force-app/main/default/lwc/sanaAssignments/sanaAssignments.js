import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserAssignments from '@salesforce/apex/SanaLearnController.getUserAssignments';
import testConnection from '@salesforce/apex/SanaLearnController.testConnection';
import generateNewToken from '@salesforce/apex/SanaLearnController.generateNewToken';

export default class SanaAssignments extends LightningElement {
    @track userEmail = '';
    @track rawAssignments = [];
    @track isLoading = false;
    @track error;

    get assignments() {
        return this.rawAssignments.map(assignment => ({
            ...assignment,
            formattedStatus: assignment.status.completed ? 'Completed' : 'Not Completed'
        }));
    }

    handleUserEmailChange(event) {
        this.userEmail = event.target.value;
    }

    async testAuth() {
        this.isLoading = true;
        try {
            const result = await testConnection();
            this.showToast('Test Result', result, 'success');
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async fetchAssignments() {
        if (!this.userEmail) {
            this.showToast('Error', 'Please enter a user email', 'error');
            return;
        }

        this.isLoading = true;
        this.error = null;
        this.rawAssignments = []; // Clear previous assignments

        try {
            console.log('Fetching assignments for email:', this.userEmail);
            const result = await getUserAssignments({ userEmail: this.userEmail });
            console.log('Raw API response:', result);
            
            if (result && result.assignments) {
                this.rawAssignments = result.assignments;
                console.log('Assignments:', this.rawAssignments);
                
                if (this.rawAssignments.length === 0) {
                    this.showToast('Info', 'No assignments found for this user', 'info');
                }
            } else {
                console.log('No assignments in response');
                this.showToast('Info', 'No assignments found for this user', 'info');
            }
        } catch (error) {
            console.error('Error fetching assignments:', error);
            this.error = error.body.message;
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async generateToken() {
        this.isLoading = true;
        try {
            const result = await generateNewToken();
            this.showToast('Token Generation', result, 'success');
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
} 