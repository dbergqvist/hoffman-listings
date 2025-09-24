# Sana Learn Salesforce Integration

A comprehensive **Salesforce integration with the Sana Learn API** for analytics reporting and user completion tracking. This solution provides real-time learning analytics data within Salesforce's reporting and dashboard ecosystem.

## 🔐 Authentication & Token Management

### Core Authentication Components

- **`SanaLearnAuthSettings__mdt`**: Custom metadata type storing API credentials (client ID, secret, tenant info)
- **Token Management**: Automatic OAuth token retrieval and refresh using Sana's authentication endpoints
- **Secure Storage**: API credentials stored in custom metadata for easy configuration without code changes

### Authentication Flow

1. Retrieves OAuth tokens using stored client credentials
2. Handles token refresh automatically when tokens expire
3. Supports multiple environments through metadata configuration

## 📊 Analytics Data Pipeline

### Available Analytics Reports from Sana

#### 1. **Course Type Analytics** (`course_type_analytics`)
- Breakdown of course completions by course type
- Shows distribution across different learning content types
- Useful for understanding which content formats are most popular

#### 2. **User Completions Analytics** (`user_completions_analytics`) 
- Individual user completion data with:
  - **User Display Names** → parsed into **First Name** and **Last Name**
  - **Email addresses**
  - **Course completion counts**
  - **Sana User IDs**
  - **Last sync timestamps**

#### 3. **Extensible Framework**
- **`SanaInsightsController.cls`**: Main API integration class handling all analytics types
- Easy to add new analytics endpoints by extending the existing pattern
- Standardized error handling and data processing

## 🚀 Data Processing Architecture

### Asynchronous Job Pattern

1. **Job Creation**: POST request to Sana API creates analytics job
2. **Polling System**: Monitors job status with configurable intervals
3. **Data Retrieval**: Downloads CSV results when job completes
4. **Data Filtering**: Removes test users and invalid data automatically

### Performance Optimizations

- **24-Hour Caching**: `SanaAnalyticsCache__c` custom object prevents unnecessary API calls
- **Smart Polling**: Configurable delays and retry limits to respect API limits
- **Batch Processing**: Handles large datasets efficiently

## 📈 Salesforce Integration Options

### Lightning Web Components (LWC)

- **`sanaDashboardSync`**: Manual sync interface with progress tracking
- **Real-time Status**: Shows last sync information and relative timestamps
- **User-Friendly Interface**: Toast notifications and loading states

### Classic Salesforce Reports & Dashboards

- **Custom Object Storage**: `Sana_User_Completion__c` stores all user completion data
- **Standard Reports**: "Top Course Completers" report with sortable columns
- **Dashboard Components**: Bar charts, tables, pie charts showing completion metrics
- **Folder Organization**: Dedicated "Sana Reports" and "Sana Dashboards" folders

### Lightning Experience Integration

- **Lightning Pages**: "Sana Analytics" page for easy access
- **App Launcher**: Searchable components accessible from anywhere
- **Navigation Integration**: Can be added to app navigation menus

## 🔄 Data Synchronization Features

### Intelligent Data Management

- **Upsert Logic**: Uses `Sana_User_ID__c` as external ID to prevent duplicates
- **Name Parsing**: Automatically splits display names into first/last name fields
- **Test Data Filtering**: Removes Sana test accounts and invalid entries
- **Timestamp Tracking**: Records when each sync occurred

### Error Handling

- **Comprehensive Logging**: Debug information for troubleshooting
- **Graceful Degradation**: System continues working even if individual records fail
- **User Feedback**: Clear error messages displayed in UI

## 🏗️ Technical Architecture

### Core Classes

| Class | Purpose |
|-------|---------|
| `SanaInsightsController` | Main API integration and analytics job management |
| `SanaDashboardDataSync` | User completion data synchronization logic |
| `SanaConnectionTestLWC` | API connectivity testing and validation |

### Custom Objects

| Object | Purpose |
|--------|---------|
| `Sana_User_Completion__c` | Stores individual user completion data |
| `SanaAnalyticsCache__c` | 24-hour caching for API responses |
| `SanaLearnAuthSettings__mdt` | API authentication configuration |

### Lightning Web Components

| Component | Purpose |
|-----------|---------|
| `sanaDashboardSync` | Manual data synchronization interface |
| `sanaConnectionTestLWC` | API connection testing tool |

## 🎯 Business Value

### For Learning & Development Teams

- **Real-time Visibility**: See course completion progress across organization
- **Performance Metrics**: Identify top learners and completion trends
- **Reporting Flexibility**: Use standard Salesforce reporting tools

### For IT/Admin Teams

- **Low Maintenance**: Caching reduces API usage and improves performance
- **Scalable Architecture**: Can handle growing user bases and data volumes
- **Secure Integration**: Uses Salesforce security model and encrypted credentials

## ⚙️ Setup & Configuration

### Prerequisites

1. **Salesforce Org** with Lightning Experience enabled
2. **Sana Learn API Access** with valid credentials
3. **Admin Permissions** to deploy custom objects and classes

### Installation Steps

1. **Deploy Metadata**:
   ```bash
   sf project deploy start --source-dir force-app/
   ```

2. **Configure API Credentials**:
   - Navigate to **Setup** → **Custom Metadata Types** → **Sana Learn Auth Settings**
   - Create new record with your Sana API credentials

3. **Setup Remote Site Settings**:
   - Add your Sana API endpoint to Remote Site Settings
   - Enable secure connections

4. **Assign Permissions**:
   - Grant users access to custom objects and Lightning components
   - Configure Lightning App with Sana Analytics page

### Configuration Options

| Setting | Location | Purpose |
|---------|----------|---------|
| API Credentials | Custom Metadata | Sana Learn authentication |
| Remote Sites | Setup → Remote Site Settings | Allow API calls to Sana |
| Page Assignments | Lightning App Builder | Add components to pages |

## 🔧 Usage Instructions

### Manual Data Sync

1. **Access Sync Interface**:
   - App Launcher → Search "Sana Analytics"
   - Click "Sync Data" button

2. **Monitor Progress**:
   - Watch for success/error toast notifications
   - Check "Last Sync" information for status

### Viewing Reports

1. **Access Reports**:
   - App Launcher → "Reports"
   - Navigate to "Sana Reports" folder
   - Open "Top Course Completers" report

2. **Create Dashboards**:
   - Reports tab → Dashboards
   - Click "New Dashboard" → "Classic Dashboard"
   - Add components using Sana reports

### API Integration Points

| Endpoint | Purpose | Frequency |
|----------|---------|-----------|
| `/api/analytics/course_type_analytics` | Course type breakdown | On-demand |
| `/api/analytics/user_completions_analytics` | User completion data | Daily recommended |
| `/oauth/token` | Authentication token refresh | As needed |

## 🔍 Monitoring & Troubleshooting

### Built-in Monitoring

- **Sync Status**: Last successful sync timestamp
- **Error Logging**: Debug logs for API calls and data processing
- **Cache Status**: 24-hour cache hit/miss tracking

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "No valid data points" | API returns job status instead of CSV | Check job polling logic |
| Authentication errors | Expired tokens or invalid credentials | Verify metadata configuration |
| Empty reports | No data synced yet | Run manual sync first |
| Slow performance | API rate limiting | Enable caching, reduce sync frequency |

### Debug Resources

- **Developer Console**: Check Apex debug logs
- **Setup → Jobs**: Monitor async operations
- **Custom Objects**: Verify data population in `Sana_User_Completion__c`

## 🚀 Future Enhancements

### Planned Features

- **Automated Scheduling**: Salesforce scheduled jobs for regular syncing
- **Advanced Filtering**: Additional user and course filtering options
- **Mobile Support**: Responsive design for mobile devices
- **Additional Analytics**: More Sana analytics endpoint integrations

### Extensibility

The codebase is designed for easy extension:

- **New Analytics Types**: Add to `SanaInsightsController.fetchAnalyticsResult()`
- **Custom Fields**: Extend `Sana_User_Completion__c` object
- **UI Components**: Create additional Lightning Web Components
- **Reporting**: Build custom reports and dashboards

## 📝 Support & Documentation

### Resources

- **Salesforce Trailhead**: Lightning Platform development
- **Sana API Documentation**: Official API reference
- **Apex Developer Guide**: Salesforce development best practices

### Getting Help

1. **Check Debug Logs**: Enable debug logging in Developer Console
2. **Verify Configuration**: Ensure all metadata settings are correct
3. **Test API Connectivity**: Use the built-in connection test component
4. **Review Error Messages**: Check toast notifications and system logs

---

**Version**: 1.0  
**Last Updated**: December 2024  
**Compatibility**: Salesforce API v58.0+, Sana Learn API v2+