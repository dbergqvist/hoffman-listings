import { LightningElement } from 'lwc';

export default class SanaAnalytics extends LightningElement {
    courseUrl = 'https://sanalabs.sana.ai/auth/scorm/redirect-secure?token=EXAMPLE_TOKEN&studentId=12345&studentName=Anna%20Svensson';
 
    openSanaAnalytics() {
        window.open(this.courseUrl, '_blank');
    }
} 