# Flutter News Widget PRD
## 1. Project Introduction
**Project Name:** Flutter News Widget (iOS & Android)  
**Primary Goal:** Provide a simple, scrollable mobile widget displaying headlines, short summaries, and accompanying images scraped from The Church of Jesus Christ of Latter-day Saints Korea Newsroom. Tapping an article opens the corresponding original webpage.

### 1.1. Problem Statement
Many users prefer quick, at-a-glance news updates without needing to launch a full application. By providing a mobile widget, users can swiftly see the most recent headlines and summaries. Content should be pulled from the newsroom site via web scraping and displayed succinctly.

### 1.2. Objectives
- **Ease of Use** – Provide a widget that can be easily installed on iOS/Android home screens
- **Quick Access** – Show recent headlines, summaries, and images at a glance
- **Minimal Tap to Full Article** – Tapping a news item opens the original newsroom page
- **MVP Focus** – Deliver core functionalities quickly and gather early feedback

## 2. User Flow
### Install App
- User installs the Flutter app from the App Store/Play Store

### Add Widget
- **iOS:** Users add the widget via the "+" icon or home screen context menu
- **Android:** Users press & hold on the home screen, select Widgets, and place the News widget

### Widget Fetches Data
- On widget initialization or refresh, the app scrapes the newsroom webpage to retrieve article data

### Display Content
- A scrollable list of top headlines, each with a short summary and a thumbnail image (fetched dynamically)

### User Interaction
- Scroll through headlines on the widget
- Tap to open the related article in the device's browser (or optionally an in-app WebView)

### Background Updates
- The widget periodically refreshes based on OS scheduling constraints or manual user refresh

## 3. Core Functionalities
### Web Scraping
Scrape the newsroom webpage `https://news-kr.churchofjesuschrist.org/%EB%B3%B4%EB%8F%84-%EC%9E%90%EB%A3%8C` to get:
- Headline: Article title
- Summary: Brief excerpt
- Image URL: Link to the article's thumbnail image
- Article Link: URL of the article

### Data Storage & Management
#### Minimal Local Storage
Use `shared_preferences` to store:
- The last fetched JSON or list of articles (headline, summary, image URL, and article link)
- A timestamp indicating when the data was last updated

#### Images
Since storing images directly in shared_preferences is not supported, the widget/app will fetch images from their URLs each time it loads the data, caching them in memory (or through Flutter's built-in image cache) as needed.

### Widget UI
- Headline displayed in bold or larger font
- Summary truncated to one or two lines
- Image displayed as a small thumbnail
- Scrolling in the widget if space permits (subject to iOS/Android widget constraints)
- Tap to Open: Tapping an article launches the URL in the device's default browser (via url_launcher) or an optional in-app WebView

### Periodic Refresh
Use iOS and Android's available background refresh mechanisms:
- **iOS:** Leverage WidgetKit's refresh intervals or background app refresh
- **Android:** Use WorkManager or an alarm-like background task to periodically fetch new data

When the device runs a refresh task, the scrape is triggered, and new data is updated in shared_preferences.

### MVP Constraints
- Keep the implementation simple to focus on core functionality
- Ensure the widget reliably shows up-to-date headlines, even if images are fetched on demand each time

## 4. Tech Stack
### Frontend (Flutter)
- **Language:** Dart
- **UI:** Flutter framework to build both the main application and the native widgets for iOS/Android
- **Widget Implementation:**
  - iOS: Possibly use the WidgetKit plugin for Flutter or a bridging approach
  - Android: AppWidget-based widget integration with Flutter as the host

### Web Scraping & Networking
**Dart Libraries:**
- `http` for making HTTP requests
- `html` for parsing HTML content (if needed; or direct JSON if the site provides it)

### Local Data Storage
**shared_preferences:**
- Store basic info (article title, summary, image URL, article link, last fetched time)
- No direct image storage. Thumbnails are fetched each time from their URLs (Flutter's default image caching will help here)

### Navigation
- `url_launcher` to open the link in the user's default browser or another chosen app

## 5. Additional Feature Suggestions (Post-MVP)
### User Customization
- Allow users to pick the number of headlines displayed
- Let users set refresh frequency (within system limits)

### Offline Support
- Cache full article text or bigger images in local storage so that articles remain fully viewable offline
- Could eventually explore a more robust local DB like Hive or SQLite if needed

### Push Notifications
- Notify users when there's a breaking news article

### Localization & Multi-Site Support
- Expand to other language versions of the Church newsroom
- Add multi-lingual text inside the app if required

### Analytics
- Track widget usage, article clicks, etc., for insights into user behavior
