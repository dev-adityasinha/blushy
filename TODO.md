# Partner Data Visibility, Notifications & AI Suggestions - Implementation Tracker

## Backend Changes (app blushy/backend)

### Phase 1: Database Schema
- [x] Update `initDatabase.js` — add `partner_data_views` table
- [x] Update `initDatabase.js` — add `partner_notifications` table

### Phase 2: Partner Repository
- [x] Update `partnerRepository.js` — add `getSharedData()` method
- [x] Update `partnerRepository.js` — add `markDataViewed()` method
- [x] Update `partnerRepository.js` — add notification CRUD methods

### Phase 3: Partner Controller & Routes
- [x] Update `partnerController.js` — add `getPartnerSharedData()`
- [x] Update `partnerController.js` — add `markPartnerDataViewed()`
- [x] Update `partnerController.js` — add `listPartnerNotifications()`
- [x] Update `partnerRoutes.js` — wire new endpoints

### Phase 4: Auth Controller — Notification Hooks
- [x] Update `authController.js` — create notification after mood update
- [x] Update `authController.js` — create notification after sleep update

### Phase 5: AI Controller & Routes
- [x] Update `aiController.js` — add `getPartnerSuggestions()`
- [x] Update `aiRoutes.js` — wire `/ai/partner-suggestions`

## Frontend Changes (app blushy/lib)

### Phase 6: Partner Service
- [x] Update `partner_service.dart` — add `getPartnerData()`
- [x] Update `partner_service.dart` — add `getNotifications()`
- [x] Update `partner_service.dart` — add `markNotificationsRead()`

### Phase 7: Models & Widgets
- [x] Update `partner_models.dart` — add `PartnerSharedData`, `MoodEntry`, `SleepEntry`, `CycleInfo`, `HealthInsights`, `PartnerNotification`
- [x] Create `partner_data_card.dart` — widget to display partner shared data

### Phase 8: Dashboard Screen
- [x] Update `dashboard_screen.dart` — fetch partner shared data for man role
- [x] Update `dashboard_screen.dart` — conditionally render mood/cycle/sleep/insights cards
- [x] Update `dashboard_screen.dart` — add notification badge on partner section
- [x] Update `dashboard_screen.dart` — add AI partner suggestions widget
- [x] Update `dashboard_screen.dart` — periodic refresh for partner data updates

## Website Mirror Changes

### Phase 9: Website Backend
- [x] Mirror all backend changes in `website blushy/backend`

### Phase 10: Website Frontend
- [x] Mirror all frontend changes in `website blushy/lib`

