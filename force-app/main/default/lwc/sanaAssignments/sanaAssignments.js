import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserAssignments from '@salesforce/apex/SanaLearnController.getUserAssignments';
import testConnection from '@salesforce/apex/SanaLearnController.testConnection';
import generateNewToken from '@salesforce/apex/SanaLearnController.generateNewToken';

export default class SanaAssignments extends LightningElement {
    @track userEmail = 'dbergqvist@gmail.com'; // Hardcoded email
    @track rawAssignments = [];
    @track isLoading = false;
    @track error;

    // Called automatically when component is connected
    connectedCallback() {
        // Auto-fetch assignments for the hardcoded email
        this.fetchAssignments();
    }
    
    get assignments() {
        return this.rawAssignments.map(assignment => {
            // Make sure status exists and has a completed property
            const status = assignment.status || {};
            
            // Format the date if it exists
            let formattedDate = 'N/A';
            if (assignment.assignmentTime) {
                try {
                    const dateObj = new Date(assignment.assignmentTime);
                    if (!isNaN(dateObj.getTime())) {
                        formattedDate = dateObj.toLocaleString();
                    }
                } catch (e) {
                    console.error('Error formatting date:', e);
                }
            }
            
            return {
                ...assignment,
                formattedStatus: status.completed ? 'Completed' : 'Not Completed',
                // Provide fallback values for assignment properties
                courseTitle: assignment.courseTitle || 'No Title Available',
                assignmentTime: formattedDate
            };
        });
    }

    handleUserEmailChange(event) {
        this.userEmail = event.target.value;
    }

    async testAuth() {
        this.isLoading = true;
        this.error = null;
        try {
            const result = await testConnection();
            this.showToast('Test Result', result, 'success');
        } catch (error) {
            console.error('Error testing connection:', error);
            this.error = error.body ? error.body.message : error.message;
            this.showToast('Error', this.error, 'error');
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
            
            if (result.error) {
                this.error = result.error;
                this.showToast('Error', this.error, 'error');
                return;
            }
            
            if (result && result.assignments) {
                this.rawAssignments = result.assignments;
                console.log('Assignments:', this.rawAssignments);
                
                if (this.rawAssignments.length === 0) {
                    this.showToast('Info', 'No assignments found for this user', 'info');
                } else {
                    this.showToast('Success', `Found ${this.rawAssignments.length} assignments`, 'success');
                }
            } else {
                console.log('No assignments in response');
                this.showToast('Info', 'No assignments found for this user', 'info');
            }
        } catch (error) {
            console.error('Error fetching assignments:', error);
            this.error = error.body ? error.body.message : error.message;
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async generateToken() {
        this.isLoading = true;
        this.error = null;
        try {
            const result = await generateNewToken();
            this.showToast('Token Generation', result, 'success');
        } catch (error) {
            console.error('Error generating token:', error);
            this.error = error.body ? error.body.message : error.message;
            this.showToast('Error', this.error, 'error');
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