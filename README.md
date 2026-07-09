# ⚽ 5omasi

A cross-platform football match booking application built with **Flutter** and **Firebase**.

5omasi simplifies organizing local football matches by allowing players to book games without contacting pitch owners or assembling a full team beforehand. Players can join matches individually and be matched with other players, creating an experience similar to online game matchmaking.

The platform also creates gig-work opportunities for referees by providing dedicated tools to manage and officiate matches.

> **Project Status:** Feature Complete – Under Active Refinement

---

# Features

## Player Features

* Email & Password authentication
* Google Sign-In
* Guest Mode
* Browse available football matches
* Book matches instantly
* Join waiting lists for full matches
* Automatic booking restrictions to prevent overlapping matches
* Match history
* Player profile management
* Player rating system
* Live leaderboard
* In-app match chat
* Google Maps navigation to football pitches
* Distance calculation between player and stadium
* Token compensation system for cancelled matches
* Push notifications

---

## Referee Features

* Dedicated referee interface
* Live match management screen
* Booking conflict prevention
* Match control tools
* Player rating management

---

## Smart Features

* Team balancing
* Real-time Firestore synchronization
* Waiting list management
* Automatic booking validation
* Token reward system
* Match history tracking
* Leaderboards
* Location-aware features
* Cloud Messaging notifications

---

# Technology Stack

### Frontend

* Flutter
* Dart

### Backend

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging

### Architecture

* Provider State Management
* Service Layer Architecture
* Model-Based Design

---

# Screenshots

| Login                           | Home                           |
| ------------------------------- | ------------------------------ |
| ![](screenshots/login-page.jpg) | ![](screenshots/home-page.jpg) |

| Booking                           | Successful Booking                      |
| --------------------------------- | --------------------------------------- |
| ![](screenshots/booking-page.jpg) | ![](screenshots/successful-booking.jpg) |

| Leaderboard                           | Profile                             |
| ------------------------------------- | ----------------------------------- |
| ![](screenshots/leaderboard-page.jpg) | ![](screenshots/profile-page-1.jpg) |

| Settings                           | Register                           |
| ---------------------------------- | ---------------------------------- |
| ![](screenshots/settings-page.jpg) | ![](screenshots/register-page.jpg) |

---

# Project Structure

```
lib/
├── components/
├── models/
├── pages/
├── providers/
├── services/
├── firebase_options.dart
└── main.dart
```

The application follows a layered architecture that separates the UI, business logic, and data models, making the project easier to maintain and extend.

---

# Firebase Services

The project uses Firebase for backend functionality:

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging

Database documentation can be found in:

```
docs/database/
```

---

# Key Challenges

One of the biggest technical challenges was implementing server-side functionality despite Google Cloud Billing not being available in Iraq.

To overcome this limitation, an alternative cloud-based solution was implemented, allowing the application to support the required backend functionality without relying on unavailable billing services.

---

# Future Improvements

* Improve referee workflow and experience
* UI and UX refinements
* Performance optimization
* Production deployment
* Additional quality-of-life features

---

# Installation

1. Clone the repository.

```bash
git clone https://github.com/YOUR_USERNAME/5omasi.git
```

2. Install dependencies.

```bash
flutter pub get
```

3. Configure Firebase for your own project.

4. Run the application.

```bash
flutter run
```

---

# Project Goal

The long-term goal of **5omasi** is to become a fully scalable platform for the Iraqi football community by simplifying match organization, reducing coordination overhead, and creating new opportunities for referees through a dedicated digital platform.

---

## Author

Developed independently as a personal software engineering project.
