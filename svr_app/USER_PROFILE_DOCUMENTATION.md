# User Profile Screen Documentation

## Overview
The User Profile Screen is a comprehensive user management interface that adapts to both regular users and super administrators. It provides a complete profile management experience with all the core elements needed for user interaction.

## Core Features

### 1. Profile Card (Top Section)
- **Profile Photo/Avatar**: Circular avatar with default icon fallback
- **Display Name**: Editable user name with inline editing capability
- **Role Badge**: Visual indicator for "Super Administrator" or "User" 
- **User Bio**: Editable description section
- **Contact Information**: Email display
- **Admin Badge**: Special crown icon for super administrators

### 2. Key Stats/Metrics
The stats section adapts based on user role:

**For Regular Users:**
- My Devices: Total devices assigned to user
- Active Devices: Currently online devices
- Help Requests: Total alerts/support requests
- Open Requests: Active alerts needing attention

**For Super Administrators:**
- Total Devices: User's personal devices
- Active Devices: User's active devices
- Total Alerts: User's alerts
- System Users: Total users in system
- System Devices: All devices in system
- System Alerts: All system alerts

### 3. Tab-Based Content Organization

#### Devices Tab
- Lists user's assigned devices (up to 5 most recent)
- Shows device status with color-coded indicators:
  - Green: Online/Active
  - Red: Offline
  - Orange: Faulty
  - Grey: Unknown
- Displays room name and location
- Empty state guidance for new users

#### Activity Tab
- Shows recent alerts and help requests
- Color-coded status indicators:
  - Orange: Active alerts
  - Green: Resolved alerts
  - Blue: Pending alerts
- Formatted timestamps for each activity
- Empty state when no activity exists

#### Settings Tab
- **Personal Information Section**:
  - Phone number (editable)
  - Location (editable)
- **App Settings Section**:
  - Notifications management
  - Security settings
  - Help & Support access
- **Logout Button**: Prominent red logout with confirmation dialog

### 4. Edit Profile Functionality
- Toggle edit mode with pencil icon
- Yellow-themed form fields matching app design
- Save/Cancel buttons in edit mode
- Real-time form validation
- Success/error feedback via snackbars

### 5. Security & Trust Features
- Logout confirmation dialog
- Secure user data handling
- Role-based feature access
- Real-time data synchronization with Firestore

## Design Features

### Visual Hierarchy
- Green gradient background matching app theme
- White text on dark background for readability
- Yellow (#E7FF76) accent color for interactive elements
- Proper spacing and card-based layout

### Mobile Optimization
- Single-hand friendly navigation
- Large tappable buttons and icons
- Vertical scrolling design
- Responsive layout elements

### User Experience
- Immediate feedback for all actions
- Loading states for data fetching
- Empty states with helpful guidance
- Consistent navigation patterns

## Navigation Integration

### Regular Users (Dashboard)
- Accessible via Settings tab in bottom navigation
- Seamless navigation from main dashboard

### Super Administrators (Admin Dashboard)
- Profile icon in app bar for quick access
- Maintains admin context while viewing profile

## Technical Implementation

### Data Sources
- **User Profile Data**: Firestore users collection
- **Device Data**: Real-time queries from devices collection
- **Activity Data**: Real-time queries from alerts collection
- **Statistics**: Aggregated data from multiple collections

### Real-time Updates
- Automatic data refresh when returning to screen
- Live statistics based on current database state
- Real-time device status monitoring

### Error Handling
- Graceful handling of network issues
- User-friendly error messages
- Fallback states for missing data

## Usage Flow

1. **Access Profile**: Navigate via Settings tab or Profile icon
2. **View Information**: Browse tabs to see devices, activity, and settings
3. **Edit Profile**: Tap edit icon to modify personal information
4. **Manage Settings**: Configure app preferences and security
5. **Logout**: Secure logout with confirmation

## Benefits for Smart Voice Recognizer App

- **User Engagement**: Comprehensive profile encourages user interaction
- **Administrative Oversight**: Super admins can monitor system-wide metrics
- **Device Management**: Easy access to device status and management
- **Support Integration**: Direct access to help requests and activity
- **Security**: Proper authentication and role-based access control

## Future Enhancements

- Profile photo upload functionality
- Advanced notification preferences
- Two-factor authentication setup
- Device grouping and management
- Enhanced analytics for super admins
- Export functionality for user data
