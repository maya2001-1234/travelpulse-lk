/**
 * TravelPulse LK — Community Reporting Backend Automated Unit Tests
 * Module 2: Community Reporting & Transport Disruption Management (Dumindi)
 * ---------------------------------------------------------------------------
 * Directly verifies:
 * 1. Category taxonomy (all 6 master categories)
 * 2. Input validation for report creation
 * 3. Service disruption reason mandate and rejection of invented severity
 * 4. Anonymous reporting masking (public views hide reporter details)
 * 5. Report creation retaining internal ownership
 * 6. User-specific report isolation (My Reports)
 * 7. Ownership enforcement on deletion (403 Forbidden for non-authors)
 * ---------------------------------------------------------------------------
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { memoryStore } = require('../src/config/db');
const {
  getCategories,
  getPublicReports,
  getReportById,
  getMyReports,
  createReport,
  updateReport,
  deleteReport,
} = require('../src/controllers/report.controller');
const { validateCreateReport } = require('../src/validators/report.validator');

// Helper to create mock Express response object
function createMockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.body = data;
      return this;
    },
  };
}

describe('TravelPulse LK — Community Reporting Backend Logic (Dumindi)', () => {
  beforeEach(() => {
    memoryStore.reset();
  });

  it('1. getCategories returns all 6 master categories with appropriate codes', () => {
    const req = {};
    const res = createMockRes();

    getCategories(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(Array.isArray(res.body.data), true);
    assert.strictEqual(res.body.data.length, 6);

    const codes = res.body.data.map((c) => c.code);
    assert.deepStrictEqual(codes, [
      'CROWD',
      'ROAD_CONDITION',
      'TRANSPORT_TRACKING',
      'SERVICE_DISRUPTION',
      'ACCIDENT_INCIDENT',
      'OTHER',
    ]);
  });

  it('2. validateCreateReport enforces required title, description, category and coordinates', () => {
    const req = {
      body: {
        title: 'Sh', // Too short (< 5)
        description: 'Tiny', // Too short (< 10)
        categoryId: 99, // Invalid (> 6)
        latitude: 'bad-coord',
        longitude: 250, // Out of bounds
      },
    };
    const res = createMockRes();
    let nextCalled = false;

    validateCreateReport(req, res, () => {
      nextCalled = true;
    });

    assert.strictEqual(nextCalled, false);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.error.code, 'VALIDATION_ERROR');
    assert.ok(res.body.error.details.length >= 4);
  });

  it('3. validateCreateReport strictly requires disruptionReason for Category 4 and rejects invented severity', () => {
    // 3a. Missing disruption reason on Service Disruption
    const reqMissingReason = {
      body: {
        title: 'Main Line Train Stoppage',
        description: 'Passenger train stuck between Ragama and Gampaha.',
        categoryId: 4, // Service Disruption
        latitude: 7.0270,
        longitude: 79.9230,
      },
    };
    const resMissing = createMockRes();
    let nextCalledA = false;

    validateCreateReport(reqMissingReason, resMissing, () => {
      nextCalledA = true;
    });

    assert.strictEqual(nextCalledA, false);
    assert.strictEqual(resMissing.statusCode, 400);
    assert.ok(resMissing.body.error.details.some((d) => d.field === 'disruptionReason'));

    // 3b. Invented severity submitted for Service Disruption (Must be rejected!)
    const reqSeverity = {
      body: {
        title: 'Main Line Train Stoppage',
        description: 'Passenger train stuck between Ragama and Gampaha.',
        categoryId: 4,
        disruptionReason: 'Engine Overheating',
        severity: 'critical', // Invalid for Service Disruption!
        latitude: 7.0270,
        longitude: 79.9230,
      },
    };
    const resSeverity = createMockRes();
    let nextCalledB = false;

    validateCreateReport(reqSeverity, resSeverity, () => {
      nextCalledB = true;
    });

    assert.strictEqual(nextCalledB, false);
    assert.strictEqual(resSeverity.statusCode, 400);
    assert.ok(resSeverity.body.error.details.some((d) => d.field === 'severity'));

    // 3c. Valid Service Disruption report with specific reason passes validation
    const reqValid = {
      body: {
        title: 'Main Line Train Stoppage',
        description: 'Passenger train stuck between Ragama and Gampaha due to signal fault.',
        categoryId: 4,
        disruptionReason: 'Signal Failure',
        latitude: 7.0270,
        longitude: 79.9230,
      },
    };
    const resValid = createMockRes();
    let nextCalledC = false;

    validateCreateReport(reqValid, resValid, () => {
      nextCalledC = true;
    });

    assert.strictEqual(nextCalledC, true);
  });

  it('4. getPublicReports masks anonymous reporter identity for public commuters', () => {
    const req = { query: {}, user: null }; // Unauthenticated guest
    const res = createMockRes();

    getPublicReports(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);

    // Report #102 in seed is an anonymous Road Condition report by Dilshan (userId: 2)
    const report102 = res.body.data.find((r) => r.id === 102);
    assert.ok(report102);
    assert.strictEqual(report102.isAnonymous, true);
    assert.strictEqual(report102.userName, 'Anonymous Commuter');
    assert.strictEqual(report102.userId, null); // Public must not see internal user_id
    assert.strictEqual(report102.isOwnReport, false);

    // Report #101 is identified by Kamal (userId: 1)
    const report101 = res.body.data.find((r) => r.id === 101);
    assert.ok(report101);
    assert.strictEqual(report101.isAnonymous, false);
    assert.strictEqual(report101.userName, 'Kamal Perera');
  });

  it('5. createReport extracts userId strictly from JWT session and persists anonymous flag', () => {
    const req = {
      user: { id: 1, name: 'Kamal Perera', email: 'kamal@example.com' },
      body: {
        categoryId: 2,
        title: 'Deep Pothole on Duplication Road',
        description: 'Large hazardous pothole right in front of Liberty Plaza entrance.',
        latitude: 6.9050,
        longitude: 79.8510,
        locationDescription: 'Kollupitiya',
        isAnonymous: true,
        userId: 9999, // Malicious spoofed client ID — MUST BE IGNORED!
      },
    };
    const res = createMockRes();

    createReport(req, res);

    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.isAnonymous, true);
    assert.strictEqual(res.body.data.isOwnReport, true);

    // Verify stored entity in database retains internal authenticated user_id: 1
    const stored = memoryStore.getReportById(res.body.data.id);
    assert.strictEqual(stored.user_id, 1);
    assert.strictEqual(stored.is_anonymous, true);
  });

  it('6. getMyReports returns all authored reports including anonymous submissions', () => {
    // Kamal (userId: 1) authored reports #101, #103 in seed
    const req = { user: { id: 1, name: 'Kamal Perera' } };
    const res = createMockRes();

    getMyReports(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.data.length >= 2);
    assert.ok(res.body.data.every((r) => r.userId === 1));
    assert.ok(res.body.data.every((r) => r.isOwnReport === true));
  });

  it('7. deleteReport enforces strict ownership (403 Forbidden for non-authors)', () => {
    // Dilshan (userId: 2) tries to delete Kamal's report (#101)
    const reqUnauthorized = {
      params: { id: 101 },
      user: { id: 2, role: 'commuter' },
    };
    const resUnauthorized = createMockRes();

    deleteReport(reqUnauthorized, resUnauthorized);

    assert.strictEqual(resUnauthorized.statusCode, 403);
    assert.strictEqual(resUnauthorized.body.success, false);
    assert.strictEqual(resUnauthorized.body.error.code, 'FORBIDDEN_RESOURCE');

    // Verify report #101 was NOT deleted
    assert.ok(memoryStore.getReportById(101));

    // Kamal (userId: 1) deletes his own report (#101)
    const reqAuthorized = {
      params: { id: 101 },
      user: { id: 1, role: 'commuter' },
    };
    const resAuthorized = createMockRes();

    deleteReport(reqAuthorized, resAuthorized);

    assert.strictEqual(resAuthorized.statusCode, 200);
    assert.strictEqual(resAuthorized.body.success, true);
    assert.strictEqual(resAuthorized.body.data.deletedReportId, 101);

    // Verify report #101 is now removed
    assert.strictEqual(memoryStore.getReportById(101), undefined);
  });

  it('8. deleteReport permits moderator override', () => {
    // Dilshan's report #102 deleted by moderator (userId: 99, role: 'moderator')
    const reqModerator = {
      params: { id: 102 },
      user: { id: 99, role: 'moderator' },
    };
    const resModerator = createMockRes();

    deleteReport(reqModerator, resModerator);

    assert.strictEqual(resModerator.statusCode, 200);
    assert.strictEqual(resModerator.body.success, true);
    assert.strictEqual(memoryStore.getReportById(102), undefined);
  });

  it('9. validateCreateReport enforces transport fields and valid crowdLevel for Category 1 (Crowd Report)', () => {
    // 9a. Missing transportType
    const reqMissingTransport = {
      body: {
        title: 'Pettah Stand Overcrowding',
        description: 'Large crowds waiting for departure.',
        categoryId: 1,
        crowdLevel: 'heavy',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resA = createMockRes();
    let nextA = false;
    validateCreateReport(reqMissingTransport, resA, () => { nextA = true; });
    assert.strictEqual(nextA, false);
    assert.strictEqual(resA.statusCode, 400);
    assert.ok(resA.body.error.details.some((d) => d.field === 'transportType'));

    // 9b. Invalid transportType (e.g. 'car')
    const reqInvalidTransport = {
      body: {
        title: 'Pettah Stand Overcrowding',
        description: 'Large crowds waiting for departure.',
        categoryId: 1,
        transportType: 'car',
        crowdLevel: 'heavy',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resB = createMockRes();
    let nextB = false;
    validateCreateReport(reqInvalidTransport, resB, () => { nextB = true; });
    assert.strictEqual(nextB, false);
    assert.strictEqual(resB.statusCode, 400);
    assert.ok(resB.body.error.details.some((d) => d.field === 'transportType'));

    // 9c. Bus report missing busRouteNumber and destination
    const reqIncompleteBus = {
      body: {
        title: 'Pettah Stand Overcrowding',
        description: 'Large crowds waiting for departure.',
        categoryId: 1,
        transportType: 'bus',
        crowdLevel: 'heavy',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resC = createMockRes();
    let nextC = false;
    validateCreateReport(reqIncompleteBus, resC, () => { nextC = true; });
    assert.strictEqual(nextC, false);
    assert.strictEqual(resC.statusCode, 400);
    assert.ok(resC.body.error.details.some((d) => d.field === 'busRouteNumber'));
    assert.ok(resC.body.error.details.some((d) => d.field === 'destination'));

    // 9d. Train report missing trainNameOrNumber, startingStation, destination
    const reqIncompleteTrain = {
      body: {
        title: 'Fort Station Train Crowd',
        description: 'Overcrowded platform 3 waiting for express train.',
        categoryId: 1,
        transportType: 'train',
        crowdLevel: 'packed',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resD = createMockRes();
    let nextD = false;
    validateCreateReport(reqIncompleteTrain, resD, () => { nextD = true; });
    assert.strictEqual(nextD, false);
    assert.strictEqual(resD.statusCode, 400);
    assert.ok(resD.body.error.details.some((d) => d.field === 'trainNameOrNumber'));
    assert.ok(resD.body.error.details.some((d) => d.field === 'startingStation'));
    assert.ok(resD.body.error.details.some((d) => d.field === 'destination'));

    // 9e. Invalid crowdLevel (must only accept 'light', 'moderate', 'heavy', 'packed')
    const reqInvalidCrowdLevel = {
      body: {
        title: 'Route 138 Bus Overcrowding',
        description: 'Bus completely filled at Town Hall stop.',
        categoryId: 1,
        transportType: 'bus',
        busRouteNumber: '138',
        destination: 'Maharagama',
        crowdLevel: 'very_crowded', // Invalid: only light, moderate, heavy, packed permitted!
        latitude: 6.9147,
        longitude: 79.8653,
      },
    };
    const resE = createMockRes();
    let nextE = false;
    validateCreateReport(reqInvalidCrowdLevel, resE, () => { nextE = true; });
    assert.strictEqual(nextE, false);
    assert.strictEqual(resE.statusCode, 400);
    assert.ok(resE.body.error.details.some((d) => d.field === 'crowdLevel'));
  });

  it('10. validateCreateReport accepts valid Bus and Train crowd reports', () => {
    // Valid Bus crowd report
    const reqBus = {
      body: {
        title: 'Route 138 Evening Rush Hour Crowds',
        description: 'Queue extending along the bay with packed buses.',
        categoryId: 1,
        transportType: 'bus',
        busRouteNumber: '138',
        destination: 'Homagama',
        busRegistrationNumber: 'ND-4521',
        crowdLevel: 'heavy',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resBus = createMockRes();
    let nextBus = false;
    validateCreateReport(reqBus, resBus, () => { nextBus = true; });
    assert.strictEqual(nextBus, true);

    // Valid Train crowd report
    const reqTrain = {
      body: {
        title: 'Udarata Menike Severe Overcrowding',
        description: 'Second and third class carriages completely packed at Fort.',
        categoryId: 1,
        transportType: 'train',
        trainNameOrNumber: 'Udarata Menike (1015)',
        startingStation: 'Colombo Fort',
        destination: 'Badulla',
        crowdLevel: 'packed',
        latitude: 6.9355,
        longitude: 79.8530,
      },
    };
    const resTrain = createMockRes();
    let nextTrain = false;
    validateCreateReport(reqTrain, resTrain, () => { nextTrain = true; });
    assert.strictEqual(nextTrain, true);
  });

  it('11. createReport correctly persists and returns bus crowd transport details', () => {
    const req = {
      user: { id: 1, name: 'Kamal Perera', email: 'kamal@example.com' },
      body: {
        categoryId: 1,
        title: 'Route 138 Rush Hour Overcrowding',
        description: 'Buses leaving Pettah are fully packed with no standing room.',
        latitude: 6.9355,
        longitude: 79.8530,
        locationDescription: 'Pettah Central Bus Stand',
        transportType: 'bus',
        busRouteNumber: '138',
        destination: 'Maharagama',
        busRegistrationNumber: 'NA-4512',
        crowdLevel: 'heavy',
      },
    };
    const res = createMockRes();

    createReport(req, res);

    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.transportType, 'bus');
    assert.strictEqual(res.body.data.busRouteNumber, '138');
    assert.strictEqual(res.body.data.destination, 'Maharagama');
    assert.strictEqual(res.body.data.busRegistrationNumber, 'NA-4512');
    assert.strictEqual(res.body.data.crowdLevel, 'heavy');

    const stored = memoryStore.getReportById(res.body.data.id);
    assert.strictEqual(stored.transport_type, 'bus');
    assert.strictEqual(stored.bus_route_number, '138');
    assert.strictEqual(stored.destination, 'Maharagama');
    assert.strictEqual(stored.bus_registration_number, 'NA-4512');
    assert.strictEqual(stored.crowd_level, 'heavy');
  });

  it('12. createReport correctly persists and returns train crowd transport details', () => {
    const req = {
      user: { id: 2, name: 'Dilshan Silva', email: 'dilshan@example.com' },
      body: {
        categoryId: 1,
        title: 'Main Line Evening Commuter Train Packed',
        description: 'Office train 1015 completely packed with passengers on footboards.',
        latitude: 6.9355,
        longitude: 79.8530,
        locationDescription: 'Colombo Fort Platform 4',
        transportType: 'train',
        trainNameOrNumber: 'Office Express 1015',
        startingStation: 'Colombo Fort',
        destination: 'Polgahawela',
        crowdLevel: 'packed',
      },
    };
    const res = createMockRes();

    createReport(req, res);

    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.transportType, 'train');
    assert.strictEqual(res.body.data.trainNameOrNumber, 'Office Express 1015');
    assert.strictEqual(res.body.data.startingStation, 'Colombo Fort');
    assert.strictEqual(res.body.data.destination, 'Polgahawela');
    assert.strictEqual(res.body.data.crowdLevel, 'packed');

    const stored = memoryStore.getReportById(res.body.data.id);
    assert.strictEqual(stored.transport_type, 'train');
    assert.strictEqual(stored.train_name_or_number, 'Office Express 1015');
    assert.strictEqual(stored.starting_station, 'Colombo Fort');
    assert.strictEqual(stored.destination, 'Polgahawela');
    assert.strictEqual(stored.crowd_level, 'packed');
  });
});
