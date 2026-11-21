# TravelPulse LK

> **Community-Driven Smart Public Transport and Road Condition Platform for Sri Lanka**  
> *SE5104 Mini Project — Group 10*

[![Backend Node Test](https://img.shields.io/badge/backend%20tests-32%2F32%20passing%20(100%25)-brightgreen)](backend/tests)
[![Flutter Version](https://img.shields.io/badge/flutter-%3E%3D3.1.0-blue)](mobile-app)
[![Node Version](https://img.shields.io/badge/node-%3E%3D20.0.0-green)](backend)
[![MySQL Version](https://img.shields.io/badge/mysql-8.0-orange)](database)

---

## 1. System Overview & Problem Statement

Urban mobility in Sri Lanka's major metropolitan transit corridors (Colombo High-Level Road, Galle Road, Kandy-Colombo Main Line, and Outer Circular Corridors) is heavily impacted by unannounced service disruptions, unpredictable overcrowding, flash flooding, and traffic incidents.

**TravelPulse LK** is a full-stack, crowdsourced transit intelligence platform designed to empower Sri Lankan commuters and transport authorities. By synthesizing commuter-generated incident reports with algorithmic sliding-window crowd estimations, peer verification voting, and verified road condition alerts, TravelPulse LK provides real-time situational awareness across bus routes, railways, and major arterial roads.

---

## 2. Verified Figma Design System & Brand Tokens

The mobile user interface strictly adheres to the verified Figma design specifications and Sri Lankan transit accessibility guidelines:

| Design Token | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| **Primary Brand** | `#1F6F7C` | Primary buttons, app bars, active tab icons, brand accents |
| **Background** | `#F7FBFC` | Main screen background, surface cards, list canvas |
| **Text Primary** | `#152238` | Headings, high-emphasis text, primary titles, metrics |
| **Text Secondary** | `#526C77` | Subheadings, timestamps, secondary labels, metadata |
| **Accent / Amber** | `#D97706` | Warning alerts, moderate crowd density, disputed states |
| **Accent / Crimson** | `#DC2626` | Critical road hazards, flash flooding, emergency disruptions |
| **Accent / Emerald** | `#16A34A` | Verified reports, normal schedules, on-time journeys |

---

## 3. Team Responsibilities & Module Architecture

The system is organized into four distinct, cohesive modules owned by the project members:

```
                            ┌────────────────────────────────────────┐
                            │        TravelPulse LK Platform         │
                            └───────────────────┬────────────────────┘
                                                │
         ┌───────────────────────┬──────────────┴────────┬───────────────────────┐
         │                       │                       │                       │
┌────────▼────────┐     ┌────────▼────────┐     ┌────────▼────────┐     ┌────────▼────────┐
│    MODULE 1     │     │    MODULE 2     │     │    MODULE 3     │     │    MODULE 4     │
│  Nisal (Owner)  │     │ Dumindi (Owner) │     │ Suneth (Owner)  │     │ Thimaya (Owner) │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ • Auth & Tokens │     │ • Community     │     │ • Crowd Engine  │     │ • Road Incidents│
│ • User Profiles │     │   Reports       │     │ • Reliability   │     │ • Interactive   │
│ • Bus & Train   │     │ • Disruption    │     │   Scoring       │     │   Maps          │
│   Routes        │     │   Tracking      │     │ • Peer Voting   │     │ • Travel Alerts │
│ • Stops & Seq.  │     │ • Anonymous     │     │ • Time-Decay    │     │ • Geo-Fenced    │
│ • Schedules     │     │   Reporting     │     │   Freshness     │     │   Subscriptions │
│ • Journeys      │     │ • Taxonomy      │     │ • Reputations   │     │ • Push Alerts   │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ Tables: 1 - 8   │     │ Tables: 9 - 11  │     │ Tables: 12 - 16 │     │ Tables: 17 - 20 │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Module 1: User Authentication, Routes & Journeys (Nisal)
- JWT session issuance, authentication middleware, commuter profiles, and role management (`commuter`, `moderator`, `admin`).
- Sri Lankan transport catalog: Bus routes (138 Pettah–Homagama, 100 Pettah–Panadura, 177 Kollupitiya–Kaduwela, 120 Pettah–Horana) and Railway routes (Main Line Colombo Fort–Polgahawela).
- Sequential route stops, GPS waypoints, timetables, and commuter journey logging.
- **Database Tables (1–8):** `users`, `user_profiles`, `transport_modes`, `transport_routes`, `route_stops`, `route_schedules`, `journeys`, `journey_legs`.

### Module 2: Community Reporting & Disruption Management (Dumindi)
- Commuter incident submission pipeline with mandatory structured reasons (e.g., breakdown, signal failure, road inundation) preventing arbitrary severity inflation.
- Commuter privacy protection: internal tracking retains `user_id` for ownership while masking public responses as `"Anonymous Commuter"`.
- Commuter ownership enforcement: non-moderators can only view and delete reports they authored.
- **Database Tables (9–11):** `report_categories`, `community_reports`, `service_disruptions`.

### Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)
- Sliding-window crowd level aggregation (5-level scale: `empty`, `many_seats`, `few_seats`, `standing_only`, `very_crowded`).
- Dynamic reliability scoring ($0.0 - 100.0$) combining commuter reputation, peer voting ($+1 / -1$), and exponential time-decay freshness.
- Strict constraint validation: dual nullable foreign-key enforcement for routes vs stops.
- **Database Tables (12–16):** `user_reputations`, `report_votes`, `crowd_estimates`, `crowd_aggregations`, `reliability_history`.

### Module 4: Road Conditions, Maps & Travel Alert System (Thimaya)
- Interactive map view displaying geolocated road hazards, transit disruptions, and crowd hotspots.
- Promotion pipeline: elevates verified community reports into confirmed road incidents.
- Geo-fenced push notifications: matches critical alerts to subscribed routes and radii ($0.5\text{km} - 25.0\text{km}$).
- **Database Tables (17–20):** `road_incidents`, `travel_alerts`, `alert_subscriptions`, `alert_deliveries`.

---

## 4. Repository Structure

```
travelpulse-lk/
├── docker-compose.yml              # One-command full-stack container orchestration
├── .env.example                    # Root environment variable documentation
├── README.md                       # Master project handover documentation
│
├── backend/                        # Express.js REST API Service
│   ├── Dockerfile                  # Container definition for API service
│   ├── .env.example                # Backend-specific environment template
│   ├── package.json                # NPM configuration, dependencies & test scripts
│   ├── src/
│   │   ├── server.js               # HTTP server entry point & listener
│   │   ├── app.js                  # Express middleware configuration & route mounting
│   │   ├── config/
│   │   │   ├── db.js               # Dual MySQL pool & in-memory relational store
│   │   │   └── firebase.js         # Firebase Cloud Messaging service adapter
│   │   ├── controllers/            # Module controllers (auth, routes, reports, crowd, alerts)
│   │   ├── middleware/             # JWT auth verification, roles & error handlers
│   │   ├── engine/                 # Reliability, freshness, duplicate & crowd engines
│   │   ├── routes/                 # REST router definitions (/api/v1/...)
│   │   └── validators/             # Request payload schema validators
│   └── tests/                      # Automated Node.js test suites (100% passing)
│       ├── report.test.js          # Module 2 tests (8/8 pass)
│       ├── crowd.test.js           # Module 3 tests (8/8 pass)
│       ├── alerts.test.js          # Module 4 tests (8/8 pass)
│       └── integration.test.js     # Stage 7 End-to-end integration tests (8/8 pass)
│
├── database/                       # Relational Database Architecture (20 Tables)
│   ├── schema/
│   │   ├── full_schema.sql         # Consolidated, idempotent DDL (MySQL 8.0+)
│   │   ├── 01_nisal_user_transport_schema.sql
│   │   ├── 02_dumindi_community_reports_schema.sql
│   │   ├── 03_suneth_crowd_reliability_schema.sql
│   │   └── 04_thimaya_road_alerts_schema.sql
│   └── seeds/                      # Authentic Sri Lankan transit datasets
│       ├── 01_nisal_user_transport_seeds.sql
│       ├── 02_dumindi_community_reports_seeds.sql
│       ├── 03_suneth_crowd_reliability_seeds.sql
│       └── 04_thimaya_road_alerts_seeds.sql
│
├── mobile-app/                     # Flutter (Dart) Mobile Application
│   ├── pubspec.yaml                # Flutter dependencies (http, provider, etc.)
│   ├── android/                    # Android host config & permissions
│   │   └── app/src/main/AndroidManifest.xml
│   └── lib/
│       ├── main.dart               # MultiProvider application bootstrap
│       ├── core/                   # Theme, constants, API client, local storage
│       │   ├── constants/          # Brand colors, typography, endpoints
│       │   ├── services/           # ApiService (HTTP client with Bearer injection)
│       │   └── storage/            # LocalStorageService (token persistence)
│       ├── modules/                # Feature modules
│       │   ├── nisal/              # Auth, User Profile, Routes, Journeys
│       │   ├── dumindi/            # Incident Reporting, Categories, Disruption Feed
│       │   ├── suneth/             # Crowd Intelligence, Peer Voting, Reliability
│       │   └── thimaya/            # Interactive Map, Incidents, Alert Subscriptions
│       └── shared/widgets/         # Reusable design system UI components
│
├── docs/                           # Architecture Specifications & Contracts
│   ├── api-contracts.md            # Detailed REST API endpoints, schemas, responses
│   ├── database-design.md          # Complete 20-table schema dictionary & relationships
│   ├── module-integration.md       # Cross-module communication & integration flows
│   ├── module-ownership.md         # Individual group member responsibility matrix
│   └── system_architecture.md      # High-level architecture and subsystem design
│
└── diagrams/                       # Visual Architecture & Sequence Diagrams
```

---

## 5. Quick Start: One-Command Docker Setup

The entire backend and database stack can be launched with Docker Compose:

```bash
# 1. Clone or navigate to the repository
cd travelpulse-lk

# 2. Launch MySQL 8.0 and the Express API service
docker compose up -d --build

# 3. Check container status
docker compose ps
```

The MySQL container automatically executes `full_schema.sql` and the four seed files in order. The backend service starts at `http://localhost:5000`.

- Health check: `http://localhost:5000/health`
- Community reports feed: `http://localhost:5000/api/v1/reports`

---

## 6. Local Manual Setup

### 6.1 Database Setup (MySQL 8.0+)
If running without Docker, initialize your local MySQL instance:

```bash
# Connect to MySQL as root or privileged user
mysql -u root -p < database/schema/full_schema.sql

# Load the coordinated seed data in sequence
mysql -u root -p travelpulse_lk < database/seeds/01_nisal_user_transport_seeds.sql
mysql -u root -p travelpulse_lk < database/seeds/02_dumindi_community_reports_seeds.sql
mysql -u root -p travelpulse_lk < database/seeds/03_suneth_crowd_reliability_seeds.sql
mysql -u root -p travelpulse_lk < database/seeds/04_thimaya_road_alerts_seeds.sql
```

### 6.2 Backend API Service
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Copy the environment configuration:
   ```bash
   cp .env.example .env
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Start the server:
   ```bash
   # Production mode
   npm start

   # Development mode (with auto-reload)
   npm run dev
   ```

### 6.3 Mobile Application (Flutter)
1. Navigate to the mobile application directory:
   ```bash
   cd mobile-app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Verify environment endpoints:
   - For Android Emulator: API points to `http://10.0.2.2:5000/api/v1` (configured by default in `AppConstants.defaultApiBaseUrl`).
   - For iOS Simulator / Web / Desktop: API points to `http://localhost:5000/api/v1`.
4. Launch the application:
   ```bash
   # Run on connected device or emulator
   flutter run

   # Or run on Chrome / Windows desktop
   flutter run -d chrome
   ```

---

## 7. Verification & Automated Test Suites

The backend includes a comprehensive, zero-dependency Node.js test harness covering all four modules and cross-module end-to-end integration:

```bash
# Run all 32 tests across 4 suites
npm test

# Or run individual module suites
npm run test:unit
npm run test:integration
```

### Current Test Execution Results (Stage 8 Verified):
```
▶ TravelPulse LK — Module 4: Road Conditions, Maps & Alerts (Thimaya)
  ✔ 1. getIncidents returns road incidents with coordinates and severity
  ✔ 2. getIncidents correctly filters by incidentType and severity
  ✔ 3. promoteReport promotes verified community report into confirmed road incident
  ✔ 4. promoteReport rejects unverified report promotion by non-moderators
  ✔ 5. getAlerts returns active travel alerts with route details
  ✔ 6. createAlert restricts broadcast to moderators and triggers notification audit
  ✔ 7. updateSubscription and getSubscriptions manage commuter notification preferences
  ✔ 8. registerDeviceToken persists FCM device token
✔ TravelPulse LK — Module 4: Road Conditions, Maps & Alerts (Thimaya)

▶ TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)
  ✔ 1. FreshnessEngine calculates correct time-decay curve for crowd vs incident reports
  ✔ 2. DuplicateDetector computes Haversine distance and clusters related reports
  ✔ 3. ConfidenceScorer computes score and confidence status
  ✔ 4. CrowdEngine deduplicates multiple submissions from same commuter and aggregates level
  ✔ 5. validateCrowdEstimate rejects when both routeId and stopId are provided or both missing
  ✔ 6. voteOnReport prevents self-voting and records valid peer vote with score recalculation
  ✔ 7. submitCrowdEstimate persists estimate and updates active route aggregation
  ✔ 8. getUserReputation returns commuter trust metrics
✔ TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)

▶ TravelPulse LK — Cross-Module System-Wide Integration (Stage 7)
  ✔ 1. Commuter can sign in and obtain a valid JWT session token
  ✔ 2. New commuter can register, receive token, and inspect user profile
  ✔ 3. Commuter can search routes by corridor and inspect stops sequence & timetables
  ✔ 4. Commuter can start and complete an active travel journey
  ✔ 5. Full Pipeline: Community report submitted anonymously, voted by peers, reaches verified status, and promoted to road incident
  ✔ 6. Commuter crowd observation updates sliding-window crowd aggregation
  ✔ 7. Moderator broadcasts critical travel alert and system audits push delivery
  ✔ 8. Enforces role-based security and ownership boundaries across all modules
✔ TravelPulse LK — Cross-Module System-Wide Integration (Stage 7)

▶ TravelPulse LK — Community Reporting Backend Logic (Dumindi)
  ✔ 1. getCategories returns all 6 master categories with appropriate codes
  ✔ 2. validateCreateReport enforces required title, description, category and coordinates
  ✔ 3. validateCreateReport strictly requires disruptionReason for Category 4 and rejects invented severity
  ✔ 4. getPublicReports masks anonymous reporter identity for public commuters
  ✔ 5. createReport extracts userId strictly from JWT session and persists anonymous flag
  ✔ 6. getMyReports returns all authored reports including anonymous submissions
  ✔ 7. deleteReport enforces strict ownership (403 Forbidden for non-authors)
  ✔ 8. deleteReport permits moderator override
✔ TravelPulse LK — Community Reporting Backend Logic (Dumindi)

ℹ tests 32 | suites 4 | pass 32 | fail 0 | 100% pass rate
```

---

## 8. REST API Reference

All API routes are prefixed with `/api/v1`. Protected endpoints require an `Authorization: Bearer <token>` header.

| Method | Endpoint | Access | Module | Description |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/auth/register` | Public | Nisal | Register commuter account |
| `POST` | `/auth/login` | Public | Nisal | Login and receive JWT token |
| `GET` | `/auth/profile` | Auth | Nisal | Get authenticated commuter profile |
| `GET` | `/routes` | Public | Nisal | Search bus & train routes |
| `GET` | `/routes/:id` | Public | Nisal | Get route details with sequential stops |
| `GET` | `/routes/:id/schedules`| Public | Nisal | Get scheduled departure timetable |
| `GET` | `/journeys` | Auth | Nisal | Get commuter journey history |
| `POST` | `/journeys` | Auth | Nisal | Start new journey |
| `PATCH`| `/journeys/:id/complete`| Auth | Nisal | Complete an active journey |
| `GET` | `/reports/categories` | Public | Dumindi | List 6 master report categories |
| `GET` | `/reports` | Public | Dumindi | Feed of community reports (anonymous masked) |
| `GET` | `/reports/:id` | Public | Dumindi | Single community report details |
| `GET` | `/reports/my-reports` | Auth | Dumindi | List commuter's own authored reports |
| `POST` | `/reports` | Auth | Dumindi | Submit new community incident |
| `DELETE`| `/reports/:id` | Auth | Dumindi | Delete owned report (strict 403 enforcement) |
| `POST` | `/reports/:id/vote` | Auth | Suneth | Vote on report (+1 upvote / -1 downvote) |
| `GET` | `/crowd/aggregations` | Public | Suneth | Active network crowd aggregations |
| `GET` | `/crowd/routes/:id` | Public | Suneth | Live crowd aggregation for route |
| `POST` | `/crowd/estimates` | Auth | Suneth | Submit commuter crowd estimate |
| `GET` | `/crowd/users/:id/reputation`| Auth | Suneth | Commuter reliability reputation score |
| `GET` | `/incidents` | Public | Thimaya | Active road incidents & hazards |
| `POST` | `/incidents/promote/:id` | Mod/Admin | Thimaya | Promote verified report to road incident |
| `GET` | `/alerts` | Public | Thimaya | Active official travel alerts |
| `POST` | `/alerts` | Mod/Admin | Thimaya | Broadcast emergency alert & trigger push |
| `GET` | `/alerts/subscriptions`| Auth | Thimaya | Commuter geo-fenced alert preferences |
| `POST` | `/alerts/subscriptions`| Auth | Thimaya | Update route & radius subscription |

---

## 9. Security & Governance Policies

1. **Reporter Privacy & Anonymity:** When `is_anonymous` is set to `true`, the public feed masks the reporter's name as `"Anonymous Commuter"` and nullifies personal identifiers. The backend securely retains `user_id` internally to guarantee ownership verification and auditability.
2. **Strict Ownership Enforcement:** Commuters are prohibited from deleting reports authored by other users (`403 Forbidden`). Only the original author or authorized staff (`moderator`, `admin`) can delete or resolve reports.
3. **Disruption Integrity:** Category 4 (`SERVICE_DISRUPTION`) strictly mandates an explicit `disruptionReason` from the official taxonomy (e.g., `Vehicle Breakdown`, `Signal Failure`, `Track Maintenance`) and rejects arbitrary client-supplied severity levels.
4. **Offline Resilience:** The Flutter mobile application incorporates a dual-mode communication layer. When the backend service is offline or unreachable, the application continues to run seamlessly using realistic in-memory Sri Lankan transit caches without throwing unhandled exceptions.

---

## 10. Team Handover Sign-off (Group 10)

| Member | Module Focus | Responsibility |
| :--- | :--- | :--- |
| **Nisal** | Module 1 | Authentication, Commuter Profiles, Transit Routes, Stops, Schedules, Journeys |
| **Dumindi** | Module 2 | Community Reporting Pipeline, Disruption Management, Taxonomy, Ownership |
| **Suneth** | Module 3 | Crowd Intelligence, Peer Reliability Engine, Aggregations, User Reputations |
| **Thimaya** | Module 4 | Road Conditions, Interactive Map, Incident Promotion, Alerts & Subscriptions |

*TravelPulse LK — Developed for the SE5104 Mini Project Module, 2026.*
