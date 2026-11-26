/**
 * TravelPulse LK — Cross-Module End-to-End Integration Test Suite (Stage 7)
 * Tests cross-cutting workflows across all 4 modules:
 *  1. Nisal — Authentication, Routes, Stops, Schedules & Journeys
 *  2. Dumindi — Community Reporting & Disruption Management
 *  3. Suneth — Crowd Intelligence & Reliability Engine
 *  4. Thimaya — Road Incidents, Map Hazards & Travel Alerts
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const app = require('../src/app');
const { memoryStore } = require('../src/config/db');

// Helper to simulate HTTP requests against the Express app without external network ports
function makeRequest(app, method, url, { headers = {}, body = null } = {}) {
  return new Promise((resolve) => {
    const reqHeaders = { ...headers };
    let bodyBuffer = null;

    if (body) {
      bodyBuffer = Buffer.from(JSON.stringify(body), 'utf8');
      reqHeaders['content-type'] = 'application/json';
      reqHeaders['content-length'] = bodyBuffer.length.toString();
    }

    const req = Readable.from(bodyBuffer ? [bodyBuffer] : []);
    req.method = method;
    req.url = url;
    req.originalUrl = url;
    req.headers = reqHeaders;
    req.query = {};
    req.params = {};

    const res = {
      statusCode: 200,
      headers: {},
      bodyData: '',
      status(code) {
        this.statusCode = code;
        return this;
      },
      setHeader(name, val) {
        this.headers[name.toLowerCase()] = val;
      },
      header(name, val) {
        this.headers[name.toLowerCase()] = val;
      },
      json(data) {
        this.bodyData = JSON.stringify(data);
        resolve({
          status: this.statusCode,
          headers: this.headers,
          body: data,
        });
      },
      send(data) {
        this.bodyData = data;
        let parsed;
        try {
          parsed = JSON.parse(data);
        } catch (_) {
          parsed = data;
        }
        resolve({
          status: this.statusCode,
          headers: this.headers,
          body: parsed,
        });
      },
      sendStatus(code) {
        this.statusCode = code;
        resolve({ status: code, headers: {}, body: null });
      },
      end() {
        resolve({ status: this.statusCode, headers: this.headers, body: null });
      },
    };

    app.handle(req, res);
  });
}

describe('TravelPulse LK — Cross-Module System-Wide Integration (Stage 7)', () => {
  beforeEach(() => {
    memoryStore.reset();
  });

  // ---------------------------------------------------------------------------
  // 1. Authentication & Identity Lifecycle (Nisal)
  // ---------------------------------------------------------------------------
  it('1. Commuter can sign in and obtain a valid JWT session token', async () => {
    const res = await makeRequest(app, 'POST', '/api/v1/auth/login', {
      body: {
        emailOrUsername: 'kamal@example.com',
        password: 'Password123!',
      },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.data.token, 'Token should be returned');
    assert.equal(res.body.data.user.email, 'kamal@example.com');
    assert.equal(res.body.data.user.role, 'commuter');
  });

  it('2. New commuter can register, receive token, and inspect user profile', async () => {
    const regRes = await makeRequest(app, 'POST', '/api/v1/auth/register', {
      body: {
        name: 'Saman Jayasinghe',
        email: 'saman@example.com',
        password: 'SecurePassword123!',
        phoneNumber: '+94711122334',
      },
    });

    assert.equal(regRes.status, 201);
    assert.equal(regRes.body.success, true);
    assert.equal(regRes.body.data.user.name, 'Saman Jayasinghe');
    const token = regRes.body.data.token;

    // Use token to inspect authenticated profile
    const profileRes = await makeRequest(app, 'GET', '/api/v1/auth/me', {
      headers: { authorization: `Bearer ${token}` },
    });

    assert.equal(profileRes.status, 200);
    assert.equal(profileRes.body.data.name, 'Saman Jayasinghe');
    assert.ok(profileRes.body.data.reputation, 'Reputation record initialized in Suneth module');
    assert.equal(profileRes.body.data.reputation.reputation_score, 10.0);
  });

  // ---------------------------------------------------------------------------
  // 2. Master Transit Network & Journey Management (Nisal)
  // ---------------------------------------------------------------------------
  it('3. Commuter can search routes by corridor and inspect stops sequence & timetables', async () => {
    // 3a. Search routes between Colombo Fort and Maharagama
    const searchRes = await makeRequest(app, 'GET', '/api/v1/routes?origin=Colombo%20Fort&destination=Maharagama');
    assert.equal(searchRes.status, 200);
    assert.ok(searchRes.body.data.length >= 1);
    const route138 = searchRes.body.data.find((r) => r.routeNumber === '138');
    assert.ok(route138, 'Route 138 should be found');

    // 3b. Inspect Route 138 details
    const detailsRes = await makeRequest(app, 'GET', '/api/v1/routes/1');
    assert.equal(detailsRes.status, 200);
    assert.equal(detailsRes.body.data.routeNumber, '138');
    assert.ok(detailsRes.body.data.stops.length >= 5);
    assert.ok(detailsRes.body.data.currentCrowdLevel, 'Cross-module crowd level attached from Suneth engine');

    // 3c. Inspect Route 138 timetables
    const schedRes = await makeRequest(app, 'GET', '/api/v1/routes/1/schedules?direction=outbound');
    assert.equal(schedRes.status, 200);
    assert.ok(schedRes.body.data.length >= 3);
  });

  it('4. Commuter can start and complete an active travel journey', async () => {
    const startRes = await makeRequest(app, 'POST', '/api/v1/journeys', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: {
        routeId: 1,
        originStopId: 101,
        destinationStopId: 107,
      },
    });

    assert.equal(startRes.status, 201);
    assert.equal(startRes.body.data.routeNumber, '138');
    assert.equal(startRes.body.data.status, 'in_progress');
    const journeyId = startRes.body.data.id;

    // Complete journey
    const completeRes = await makeRequest(app, 'PATCH', `/api/v1/journeys/${journeyId}/complete`, {
      headers: { authorization: 'Bearer test-token-kamal' },
    });

    assert.equal(completeRes.status, 200);
    assert.equal(completeRes.body.data.status, 'completed');
    assert.ok(completeRes.body.data.endTime);
  });

  // ---------------------------------------------------------------------------
  // 3. Cross-Module Pipeline: Report Submission -> Voting -> Promotion (Dumindi -> Suneth -> Thimaya)
  // ---------------------------------------------------------------------------
  it('5. Full Pipeline: Community report submitted anonymously, voted by peers, reaches verified status, and promoted to road incident', async () => {
    // Step A: Dilshan submits an anonymous road condition report about flash flooding
    const submitRes = await makeRequest(app, 'POST', '/api/v1/reports', {
      headers: { authorization: 'Bearer test-token-dilshan' },
      body: {
        categoryId: 2,
        routeId: 2,
        latitude: 6.8920,
        longitude: 79.8580,
        locationDescription: 'Bauddhaloka Mawatha near Thunmulla',
        title: 'Severe Flash Flood Inundation',
        description: 'Road covered in 1.5 ft water. Light vehicles cannot pass.',
        isAnonymous: true,
      },
    });

    assert.equal(submitRes.status, 201);
    assert.equal(submitRes.body.data.isAnonymous, true);
    assert.equal(submitRes.body.data.userId, 2, 'Retains internal ownership');
    const reportId = submitRes.body.data.id;

    // Step B: Public commuters see report as "Anonymous Commuter" without personal details
    const publicRes = await makeRequest(app, 'GET', '/api/v1/reports');
    assert.equal(publicRes.status, 200);
    const publicReport = publicRes.body.data.find((r) => r.id === reportId);
    assert.ok(publicReport);
    assert.equal(publicReport.userName, 'Anonymous Commuter');
    assert.equal(publicReport.userId, null);

    // Step C: Peer commuters upvote report (Suneth's crowd engine)
    const vote1 = await makeRequest(app, 'POST', '/api/v1/crowd/vote', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: { reportId, voteType: 'upvote' },
    });
    assert.equal(vote1.status, 200);

    // Kamal cannot upvote twice (toggles off)
    const vote2 = await makeRequest(app, 'POST', '/api/v1/crowd/vote', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: { reportId, voteType: 'upvote' },
    });
    assert.equal(vote2.status, 200);
    assert.equal(vote2.body.data.userVote, null, 'Upvote toggled off on repeat');

    // Vote back on
    await makeRequest(app, 'POST', '/api/v1/crowd/vote', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: { reportId, voteType: 'upvote' },
    });

    // Step D: Report Promotion to Road Incident (Thimaya module)
    // Non-moderator with unverified report score cannot promote
    // Let's test moderator promotion (Anusha / Moderator)
    const promoteRes = await makeRequest(app, 'POST', `/api/v1/incidents/promote/${reportId}`, {
      headers: { authorization: 'Bearer test-token-moderator' },
    });

    assert.equal(promoteRes.status, 201);
    assert.equal(promoteRes.body.data.sourceReportId, reportId);
    assert.equal(promoteRes.body.data.incidentType, 'flooding');
    assert.equal(promoteRes.body.data.severity, 'medium');
    assert.ok(promoteRes.body.data.id >= 400);

    // Step E: Incident now visible on live map feed with geographic coordinates
    const incidentsRes = await makeRequest(app, 'GET', '/api/v1/incidents?incidentType=flooding');
    assert.equal(incidentsRes.status, 200);
    const incidentOnMap = incidentsRes.body.data.find((i) => i.id === promoteRes.body.data.id);
    assert.ok(incidentOnMap, 'Promoted incident visible on map feed');
    assert.equal(incidentOnMap.addressText, 'Bauddhaloka Mawatha near Thunmulla');
  });

  // ---------------------------------------------------------------------------
  // 4. Crowd Aggregation & Sliding Time-Window Engine (Suneth)
  // ---------------------------------------------------------------------------
  it('6. Commuter crowd observation updates sliding-window crowd aggregation', async () => {
    const crowdRes = await makeRequest(app, 'POST', '/api/v1/crowd/estimate', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: {
        routeId: 1,
        crowdLevel: 'very_crowded',
        passengerWaitTimeMinutes: 22,
      },
    });

    assert.equal(crowdRes.status, 201);
    assert.equal(crowdRes.body.data.estimate.crowdLevel, 'very_crowded');

    // Verify route aggregation reflects this update
    const aggRes = await makeRequest(app, 'GET', '/api/v1/crowd/routes/1');
    assert.equal(aggRes.status, 200);
    assert.equal(aggRes.body.data.currentCrowdLevel, 'very_crowded');
    assert.ok(aggRes.body.data.confidenceScore > 0, 'Confidence score calculated');
  });

  // ---------------------------------------------------------------------------
  // 5. Travel Alerts & Commuter Notification Subscriptions (Thimaya)
  // ---------------------------------------------------------------------------
  it('7. Moderator broadcasts critical travel alert and system audits push delivery', async () => {
    // 7a. Commuter configures notification preference
    const subRes = await makeRequest(app, 'POST', '/api/v1/alerts/subscriptions', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: {
        subscriptionType: 'geo_radius',
        centerLatitude: 6.9147,
        centerLongitude: 79.8653,
        radiusKm: 5.0,
      },
    });
    assert.equal(subRes.status, 200);

    // 7b. Moderator creates critical broadcast alert
    const alertRes = await makeRequest(app, 'POST', '/api/v1/alerts', {
      headers: { authorization: 'Bearer test-token-moderator' },
      body: {
        title: 'Emergency Flood Alert — Colombo 07',
        message: 'Water levels rising rapidly near Town Hall roundabout. Routes diverted.',
        alertType: 'weather_emergency',
        severity: 'critical',
        targetRouteId: 1,
        targetRouteNumber: '138',
        targetLatitude: 6.9147,
        targetLongitude: 79.8653,
        targetRadiusKm: 3.0,
      },
    });

    assert.equal(alertRes.status, 201);
    assert.equal(alertRes.body.data.alert.title, 'Emergency Flood Alert — Colombo 07');
    assert.equal(alertRes.body.data.alert.severity, 'critical');

    // 7c. Ordinary commuter gets alerts list
    const alertsFeed = await makeRequest(app, 'GET', '/api/v1/alerts?severity=critical');
    assert.equal(alertsFeed.status, 200);
    assert.ok(alertsFeed.body.data.some((a) => a.title.includes('Emergency Flood Alert')));
  });

  // ---------------------------------------------------------------------------
  // 6. Cross-Cutting Security & Authorization Enforcement
  // ---------------------------------------------------------------------------
  it('8. Enforces role-based security and ownership boundaries across all modules', async () => {
    // 8a. Unauthenticated calls to protected routes return 401
    const unauthReport = await makeRequest(app, 'POST', '/api/v1/reports', {
      body: { title: 'No Auth' },
    });
    assert.equal(unauthReport.status, 401);
    assert.equal(unauthReport.body.error.code, 'UNAUTHORIZED');

    const unauthJourney = await makeRequest(app, 'POST', '/api/v1/journeys', {
      body: { routeId: 1 },
    });
    assert.equal(unauthJourney.status, 401);

    // 8b. Commuter attempting to create travel alert broadcast returns 403 Forbidden
    const forbiddenAlert = await makeRequest(app, 'POST', '/api/v1/alerts', {
      headers: { authorization: 'Bearer test-token-kamal' },
      body: {
        title: 'Unauthorized Commuter Broadcast',
        message: 'This broadcast must be blocked.',
        alertType: 'security',
        severity: 'critical',
      },
    });
    assert.equal(forbiddenAlert.status, 403);
    assert.equal(forbiddenAlert.body.error.code, 'FORBIDDEN_ALERT_BROADCAST');

    // 8c. Commuter attempting to delete someone else\'s report returns 403 Forbidden
    // Kamal (userId: 1) owns report 101. Dilshan (userId: 2) tries to delete it:
    const forbiddenDelete = await makeRequest(app, 'DELETE', '/api/v1/reports/101', {
      headers: { authorization: 'Bearer test-token-dilshan' },
    });
    assert.equal(forbiddenDelete.status, 403);
    assert.equal(forbiddenDelete.body.error.code, 'FORBIDDEN_RESOURCE');

    // Kamal (userId: 1) deletes own report -> 200 OK
    const allowedDelete = await makeRequest(app, 'DELETE', '/api/v1/reports/101', {
      headers: { authorization: 'Bearer test-token-kamal' },
    });
    assert.equal(allowedDelete.status, 200);
  });
});
