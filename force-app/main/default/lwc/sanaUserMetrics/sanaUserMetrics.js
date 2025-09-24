import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import getInsightsReport from '@salesforce/apex/SanaInsightsController.getInsightsReport';
import startUserCompletionsAnalyticsJob from '@salesforce/apex/SanaInsightsController.startUserCompletionsAnalyticsJob';
import checkAnalyticsJobStatus from '@salesforce/apex/SanaInsightsController.checkAnalyticsJobStatus';
import fetchAnalyticsResult from '@salesforce/apex/SanaInsightsController.fetchAnalyticsResult';
import debugAnalyticsFlow from '@salesforce/apex/SanaInsightsController.debugAnalyticsFlow';
import chartjsResource from '@salesforce/resourceUrl/chartjs';

export default class SanaUserMetrics extends LightningElement {
    @track metricsData = [];
    @track isLoading = false;
    @track error;
    @track selectedMetricType = 'user_completions_analytics';
    @track debugInfo = [];
    @track sortedBy = 'courses_completed';
    @track sortDirection = 'desc';
    @track chartData = [];
    @track showFallbackChart = false;
    
    chartInstance;
    chartjsInitialized = false;

    get metricTypeOptions() {
        return [
            { label: 'Monthly Active Users', value: 'monthly_active_users' },
            { label: 'User Completions Analytics', value: 'user_completions_analytics' }
        ];
    }

    get showUserCompletionsAnalytics() {
        return this.selectedMetricType === 'user_completions_analytics' && this.metricsData.length > 0;
    }

    get totalUsers() {
        const realUsers = this.metricsData.length;
        console.log('Total real users (after filtering):', realUsers);
        return realUsers;
    }

    get totalCompletions() {
        const total = this.metricsData.reduce((sum, user) => sum + user.courses_completed, 0);
        console.log('Total completions (after filtering):', total);
        return total;
    }

    get averageCompletions() {
        if (this.metricsData.length === 0) return 0;
        const avg = this.totalCompletions / this.totalUsers;
        const rounded = Math.round(avg * 10) / 10; // Round to 1 decimal place
        console.log('Average completions (after filtering):', rounded);
        return rounded;
    }

    get columns() {
        return [
            {
                label: 'User',
                fieldName: 'title',
                type: 'text',
                sortable: true
            },
            {
                label: 'Email',
                fieldName: 'user_email',
                type: 'email',
                sortable: true
            },
            {
                label: 'Courses Completed',
                fieldName: 'courses_completed',
                type: 'number',
                sortable: true,
                cellAttributes: { alignment: 'left' }
            }
        ];
    }

    handleMetricTypeChange(event) {
        this.selectedMetricType = event.detail.value;
        this.fetchMetrics();
    }

    async fetchMetrics() {
        this.isLoading = true;
        this.error = null;
        this.metricsData = [];
        this.debugInfo = [];
        this.showFallbackChart = false;
        this.chartData = [];

        if (this.selectedMetricType === 'user_completions_analytics') {
            // New async polling logic for analytics queries
            try {
                this.addDebugInfo('Starting async analytics job', { type: this.selectedMetricType });
                
                let jobId = await startUserCompletionsAnalyticsJob();
                
                this.addDebugInfo('Job started', { jobId, type: this.selectedMetricType });
                let pollCount = 0;
                const maxPolls = 6; // 30 seconds (6 x 5s) - jobs complete quickly
                let finished = false;
                let downloadLink;
                while (pollCount < maxPolls && !finished) {
                    pollCount++;
                    this.addDebugInfo('Polling job status', { jobId, pollCount });
                    // eslint-disable-next-line no-await-in-loop
                    const statusResult = await checkAnalyticsJobStatus({ jobId });
                    this.addDebugInfo('Status result received', { jobId, pollCount, statusResult });
                    if ((statusResult.status === 'finished' || statusResult.status === 'successful') && statusResult.link) {
                        finished = true;
                        // Extract URL from link object if it's an object, otherwise use as-is
                        downloadLink = statusResult.link.url ? statusResult.link.url : statusResult.link;
                        this.addDebugInfo('Job completed', { jobId, status: statusResult.status, downloadLink, linkObject: statusResult.link });
                        break;
                    } else if (statusResult.status === 'failed') {
                        this.error = 'Report job failed.';
                        this.addDebugInfo('Job failed', { jobId, statusResult });
                        this.showToast('Error', this.error, 'error');
                        this.isLoading = false;
                        return;
                    }
                    // Wait 5 seconds before next poll
                    // eslint-disable-next-line no-await-in-loop
                    await new Promise(resolve => setTimeout(resolve, 5000));
                }
                if (!finished) {
                    this.error = 'Report job did not finish in time.';
                    this.addDebugInfo('Job timeout', { jobId });
                    this.showToast('Error', this.error, 'error');
                    this.isLoading = false;
                    return;
                }
                // Fetch and process result
                const data = await fetchAnalyticsResult({ downloadLink, reportType: this.selectedMetricType });
                this.metricsData = this.processMetricsData(data);
                this.addDebugInfo('Data processed', { processedData: this.metricsData, originalData: data });
                
                // Always render some form of chart when we have user completions data
                if (this.selectedMetricType === 'user_completions_analytics') {
                    console.log('Ensuring chart renders for user completions data');
                    setTimeout(() => {
                        this.renderFallbackChart(); // Always use fallback for now
                    }, 100);
                }
                
                this.showToast('Success', 'User completions analytics loaded successfully', 'success');
            } catch (error) {
                this.addDebugInfo('Exception caught', { error: error.message, stack: error.stack, body: error.body ? JSON.parse(JSON.stringify(error.body)) : null });
                this.error = error.body ? (typeof error.body === 'object' ? JSON.stringify(error.body) : error.body.message) : error.message;
                this.showToast('Error', this.error, 'error');
            } finally {
                this.isLoading = false;
            }
            return;
        }

        try {
            console.log('Fetching metrics for type:', this.selectedMetricType);
            this.addDebugInfo('Starting metrics fetch', { type: this.selectedMetricType });
            
            const result = await getInsightsReport({ reportType: this.selectedMetricType });
            console.log('API Response:', JSON.stringify(result, null, 2));
            this.addDebugInfo('API Response received', JSON.parse(JSON.stringify(result)));
            
            if (result.error) {
                this.error = typeof result.error === 'object' ? JSON.stringify(result.error) : result.error;
                this.addDebugInfo('Error in response', { 
                    error: this.error,
                    fullResponse: JSON.parse(JSON.stringify(result))
                });
                this.showToast('Error', this.error, 'error');
                return;
            }
            
            if (result.data) {
                this.metricsData = this.processMetricsData(result.data);
                this.addDebugInfo('Data processed', { 
                    processedData: this.metricsData,
                    originalData: result.data 
                });
                this.showToast('Success', 'Metrics data loaded successfully', 'success');
            } else {
                this.addDebugInfo('No data available', { 
                    response: JSON.parse(JSON.stringify(result))
                });
                this.showToast('Info', 'No metrics data available', 'info');
            }
        } catch (error) {
            console.error('Error fetching metrics:', error);
            this.addDebugInfo('Exception caught', { 
                error: error.message,
                stack: error.stack,
                body: error.body ? JSON.parse(JSON.stringify(error.body)) : null
            });
            this.error = error.body ? 
                (typeof error.body === 'object' ? JSON.stringify(error.body) : error.body.message) : 
                error.message;
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    processMetricsData(data) {
        console.log('=== PROCESSING METRICS DATA ===');
        console.log('selectedMetricType:', this.selectedMetricType);
        console.log('Raw data:', JSON.stringify(data, null, 2));
        
        if (this.selectedMetricType === 'user_completions_analytics' && Array.isArray(data)) {
            // For user completions analytics, data includes user and courses_completed
            let processedData = data.map(item => ({
                id: item.id,
                title: item.title,
                description: item.description,
                value: item.value,
                // Additional fields for detailed view
                user: item.user,
                user_email: item.user_email,
                user_display_name: item.user_display_name,
                courses_completed: item.courses_completed
            }));
            
            // Filter out test/system users
            const filteredData = processedData.filter(item => {
                const isTestUser = 
                    item.title === 'LMSGetValue return' ||
                    item.user_email?.includes('sana-scorm-') ||
                    item.user_email?.includes('sana-live-') ||
                    item.title === '1234' ||
                    item.user_display_name === 'LMSGetValue return';
                
                if (isTestUser) {
                    console.log('Filtering out test user:', item.title, item.user_email);
                }
                
                return !isTestUser;
            });
            
            console.log(`Filtered ${processedData.length - filteredData.length} test users`);
            console.log('Processed user completions data:', filteredData);
            return filteredData;
        }
        if (Array.isArray(data)) {
            const processedData = data.map(item => ({
                id: item.id,
                title: item.title,
                description: item.description,
                value: item.value
            }));
            console.log('Processed general data:', processedData);
            return processedData;
        }
        console.log('No data to process - returning empty array');
        return [];
    }

    addDebugInfo(message, data) {
        const debugEntry = {
            timestamp: new Date().toISOString(),
            message,
            data: typeof data === 'object' ? JSON.stringify(data, null, 2) : data
        };
        console.log('Debug Entry:', JSON.stringify(debugEntry, null, 2));
        this.debugInfo = [...this.debugInfo, debugEntry];
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

    async debugAnalytics() {
        this.isLoading = true;
        this.error = null;
        this.debugInfo = [];
        
        try {
            this.addDebugInfo('Starting debug analytics flow', {});
            const result = await debugAnalyticsFlow();
            this.addDebugInfo('Debug flow completed', result);
            
            if (result.error) {
                this.error = result.error;
                this.showToast('Debug Error', this.error, 'error');
            } else {
                this.showToast('Debug Success', 'Analytics flow test completed successfully', 'success');
            }
        } catch (error) {
            this.addDebugInfo('Debug exception', { error: error.message, stack: error.stack });
            this.error = error.message;
            this.showToast('Debug Exception', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    connectedCallback() {
        this.fetchMetrics();
    }

    renderedCallback() {
        // Simplified - we'll rely on the data loading callback to render charts
        console.log('renderedCallback called - using simplified approach');
    }

    async loadChartJs() {
        try {
            console.log('Loading Chart.js...');
            console.log('Chart.js resource URL:', chartjsResource);
            await loadScript(this, chartjsResource);
            console.log('Chart.js loaded successfully');
            this.chartjsInitialized = true;
            // Add a small delay to ensure DOM is ready
            setTimeout(() => {
                this.renderChart();
            }, 100);
        } catch (error) {
            console.error('Error loading Chart.js', error);
            console.log('Falling back to CSS-based chart');
            // Fall back to CSS-based chart
            this.renderFallbackChart();
        }
    }

    renderChart() {
        console.log('renderChart called');
        console.log('chartjsInitialized:', this.chartjsInitialized);
        console.log('metricsData.length:', this.metricsData.length);
        
        if (!this.chartjsInitialized || !this.metricsData.length) {
            console.log('Exiting renderChart - conditions not met');
            return;
        }

        // Check if Chart is available globally
        if (typeof Chart === 'undefined') {
            console.error('Chart.js not available globally');
            console.log('Falling back to CSS-based chart');
            this.renderFallbackChart();
            return;
        }

        const canvas = this.template.querySelector('canvas[lwc\\:ref="chartCanvas"]');
        console.log('Canvas element found:', !!canvas);
        
        if (!canvas) {
            console.error('Canvas element not found');
            return;
        }

        // Destroy existing chart
        if (this.chartInstance) {
            console.log('Destroying existing chart');
            this.chartInstance.destroy();
        }

        // Sort data for better visualization
        const sortedData = [...this.metricsData].sort((a, b) => b.courses_completed - a.courses_completed);
        const topUsers = sortedData.slice(0, 10); // Show top 10 users
        
        console.log('Top users for chart:', topUsers);

        try {
            const ctx = canvas.getContext('2d');
            console.log('Creating new chart...');
            
            this.chartInstance = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: topUsers.map(user => user.title),
                datasets: [{
                    label: 'Courses Completed',
                    data: topUsers.map(user => user.courses_completed),
                    backgroundColor: [
                        '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
                        '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
                    ],
                    borderColor: '#1f77b4',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    title: {
                        display: true,
                        text: 'Top 10 Users by Course Completions'
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Number of Courses'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Users'
                        },
                        ticks: {
                            maxRotation: 45,
                            minRotation: 45
                        }
                    }
                }
            }
        });
        
        console.log('Chart created successfully');
        
        } catch (error) {
            console.error('Error creating chart:', error);
            console.log('Falling back to CSS-based chart due to error');
            this.renderFallbackChart();
        }
    }

    renderFallbackChart() {
        console.log('=== RENDERING FALLBACK CHART ===');
        console.log('metricsData length:', this.metricsData.length);
        console.log('metricsData:', this.metricsData);
        
        if (!this.metricsData.length) {
            console.log('No metrics data - exiting fallback chart render');
            return;
        }
        
        // Sort data for better visualization
        const sortedData = [...this.metricsData].sort((a, b) => b.courses_completed - a.courses_completed);
        const topUsers = sortedData.slice(0, 10); // Show top 10 users
        
        console.log('Top users for chart:', topUsers);
        
        // Find max value for scaling
        const maxValue = Math.max(...topUsers.map(user => user.courses_completed));
        console.log('Max value for scaling:', maxValue);
        
        // Create chart data for template
        this.chartData = topUsers.map(user => ({
            name: user.title,
            value: user.courses_completed,
            percentage: Math.round((user.courses_completed / maxValue) * 100),
            barStyle: `width: ${Math.round((user.courses_completed / maxValue) * 100)}%`
        }));
        
        this.showFallbackChart = true;
        console.log('=== FALLBACK CHART DATA CREATED ===');
        console.log('chartData:', this.chartData);
        console.log('showFallbackChart:', this.showFallbackChart);
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.metricsData];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.metricsData = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                return primer(x[field]);
            }
            : function (x) {
                return x[field];
            };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }
} 