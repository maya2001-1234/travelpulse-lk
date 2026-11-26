/**
 * TravelPulse LK — Module 3: Crowd Intelligence & Reliability Unit Tests
 * Owning Member: Suneth
 * ---------------------------------------------------------------------------
 * Verifies:
 *  1. Freshness decay calculations (crowd vs incident decay curves)
 *  2. Haversine distance and spatial-temporal duplicate detection
 *  3. Algorithmic report reliability scoring and status determination
 *  4. Crowd density aggregation with sliding windows and user deduplication
 *  5. Dual-nullable target constraints (route_id XOR stop_id)
 *  6. Peer voting execution, self-vote prevention, and author reputation rewards
 *  7. Crowd controller endpoints
 * ---------------------------------------------------------------------------
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { memoryStore } = require('../src/config/db');
const { calculateFreshnessWeight, isExpired, getTimeElapsedMinutes } = require('../src/engine/freshnessEngine');
const { calculateHaversineDistance, findDuplicates } = require('../src/engine/duplicateDetector');
const { calculateReliability } = require('../src/engine/confidenceScorer');
const { aggregateCrowdEstimates, resolveCrowdLevel } = require('../src/engine/crowdEngine');
const {
  submitCrowdEstimate,
  getRouteCrowd,
  getStopCrowd,
  getAggregations,
  voteOnReport,
  getUserReputation,
} = require('../src/controllers/crowd.controller');
const { validateCrowdEstimate, validateReportVote } = require('../src/validators/crowd.validator');

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

describe('TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)', () => {
  beforeEach(() => {
    memoryStore.reset();
  });

  // ---------------------------------------------------------------------------
  // 1. Freshness Decay Engine
  // ---------------------------------------------------------------------------
  it('1. FreshnessEngine calculates correct time-decay curve for crowd vs incident reports', () => {
    const now = new Date();
    const tenMinsAgo = new Date(now.getTime() - 10 * 60 * 1000);
    const thirtyMinsAgo = new Date(now.getTime() - 30 * 60 * 1000);
    const seventyMinsAgo = new Date(now.getTime() - 70 * 60 * 1000);

    // Crowd decay: 10 mins is 100% fresh
    const freshCrowd = calculateFreshnessWeight(tenMinsAgo, 'CROWD');
    assert.strictEqual(freshCrowd, 1.0);

    // Crowd decay: 30 mins has decayed to 0.70
    const decayedCrowd = calculateFreshnessWeight(thirtyMinsAgo, 'CROWD');
    assert.strictEqual(Math.round(decayedCrowd * 10) / 10, 0.7);

    // Crowd decay: 70 mins is expired
    assert.strictEqual(isExpired(seventyMinsAgo, 'CROWD'), true);
    assert.strictEqual(calculateFreshnessWeight(seventyMinsAgo, 'CROWD'), 0.0);

    // Incident decay: 70 mins is still active (> 0.7)
    const incidentWeight = calculateFreshnessWeight(seventyMinsAgo, 'ROAD_CONDITION');
    assert.ok(incidentWeight >= 0.70);
    assert.strictEqual(isExpired(seventyMinsAgo, 'ROAD_CONDITION'), false);
  });

  // ---------------------------------------------------------------------------
  // 2. Duplicate Detection & Proximity
  // ---------------------------------------------------------------------------
  it('2. DuplicateDetector computes Haversine distance and clusters related reports', () => {
    // Town Hall Colombo (6.9147, 79.8653) to Public Library (6.9135, 79.8640) ~ 195 meters
    const distMeters = calculateHaversineDistance(6.9147, 79.8653, 6.9135, 79.8640);
    assert.ok(distMeters > 150 && distMeters < 250, `Calculated distance: ${distMeters}m`);

    const existingReports = [
      {
        id: 101,
        userId: 1,
        categoryId: 4,
        latitude: 6.9147,
        longitude: 79.8653,
        createdAt: new Date(Date.now() - 10 * 60 * 1000).toISOString(),
      },
    ];

    // New report nearby (195m away) within 10 mins, same category (4) by different user (2)
    const newNearbyReport = {
      id: 105,
      userId: 2,
      categoryId: 4,
      latitude: 6.9135,
      longitude: 79.8640,
      createdAt: new Date().toISOString(),
    };

    const result = findDuplicates(newNearbyReport, existingReports, 250, 30);
    assert.strictEqual(result.hasDuplicate, true);
    assert.strictEqual(result.isSelfDuplicate, false);
    assert.strictEqual(result.corroborationCount, 1);
    assert.strictEqual(result.matches[0].reason, 'GEO_PROXIMITY');
  });

  // ---------------------------------------------------------------------------
  // 3. Confidence & Reliability Scoring
  // ---------------------------------------------------------------------------
  it('3. ConfidenceScorer computes score and confidence status', () => {
    // Low reputation, 0 votes -> unverified
    const unverified = calculateReliability({
      baseReputation: 10.0,
      upvotes: 0,
      downvotes: 0,
      corroborations: 0,
      createdAt: new Date(),
    });
    assert.strictEqual(unverified.confidenceStatus, 'unverified');
    assert.ok(unverified.reliabilityScore < 40.0);

    // High reputation, 8 upvotes, 1 downvote -> verified
    const verified = calculateReliability({
      baseReputation: 85.0,
      upvotes: 8,
      downvotes: 1,
      corroborations: 2,
      createdAt: new Date(),
    });
    assert.strictEqual(verified.confidenceStatus, 'verified');
    assert.ok(verified.reliabilityScore >= 75.0);

    // Disputed when downvotes >= 3 and downvotes > upvotes
    const disputed = calculateReliability({
      baseReputation: 50.0,
      upvotes: 1,
      downvotes: 4,
      corroborations: 0,
      createdAt: new Date(),
    });
    assert.strictEqual(disputed.confidenceStatus, 'disputed');
  });

  // ---------------------------------------------------------------------------
  // 4. Crowd Aggregation & Deduplication
  // ---------------------------------------------------------------------------
  it('4. CrowdEngine deduplicates multiple submissions from same commuter and aggregates level', () => {
    const estimates = [
      // User 1 submitted 'empty' 25 mins ago, but updated to 'very_crowded' 10 mins ago
      { userId: 1, routeId: 1, crowdLevel: 'empty', reportedAt: new Date(Date.now() - 25 * 60 * 1000).toISOString() },
      { userId: 1, routeId: 1, crowdLevel: 'very_crowded', reportedAt: new Date(Date.now() - 10 * 60 * 1000).toISOString() },
      // User 2 submitted 'crowded' 12 mins ago
      { userId: 2, routeId: 1, crowdLevel: 'crowded', reportedAt: new Date(Date.now() - 12 * 60 * 1000).toISOString() },
      // User 3 submitted 'very_crowded' 5 mins ago
      { userId: 3, routeId: 1, crowdLevel: 'very_crowded', reportedAt: new Date(Date.now() - 5 * 60 * 1000).toISOString() },
    ];

    const aggregation = aggregateCrowdEstimates({
      routeId: 1,
      stopId: null,
      estimates,
      userReputations: { 1: 80, 2: 75, 3: 90 },
      windowMinutes: 30,
    });

    // Deduplication should result in sample_count = 3 (not 4)
    assert.strictEqual(aggregation.sample_count, 3);
    assert.strictEqual(aggregation.route_id, 1);
    assert.strictEqual(aggregation.stop_id, null);
    assert.strictEqual(aggregation.aggregated_crowd_level, 'very_crowded');
    assert.ok(aggregation.confidenceScore >= 70.0);
  });

  // ---------------------------------------------------------------------------
  // 5. Dual-Nullable Target Constraints (chk_crowd_agg_target)
  // ---------------------------------------------------------------------------
  it('5. validateCrowdEstimate rejects when both routeId and stopId are provided or both missing', () => {
    // Both provided
    const reqBoth = {
      body: { routeId: 1, stopId: 101, crowdLevel: 'moderate' },
    };
    const resBoth = createMockRes();
    let nextCalledBoth = false;
    validateCrowdEstimate(reqBoth, resBoth, () => { nextCalledBoth = true; });
    assert.strictEqual(nextCalledBoth, false);
    assert.strictEqual(resBoth.statusCode, 400);

    // Neither provided
    const reqNeither = {
      body: { crowdLevel: 'moderate' },
    };
    const resNeither = createMockRes();
    let nextCalledNeither = false;
    validateCrowdEstimate(reqNeither, resNeither, () => { nextCalledNeither = true; });
    assert.strictEqual(nextCalledNeither, false);
    assert.strictEqual(resNeither.statusCode, 400);

    // Exactly one provided (valid)
    const reqValid = {
      body: { routeId: 1, crowdLevel: 'moderate' },
    };
    const resValid = createMockRes();
    let nextCalledValid = false;
    validateCrowdEstimate(reqValid, resValid, () => { nextCalledValid = true; });
    assert.strictEqual(nextCalledValid, true);
  });

  // ---------------------------------------------------------------------------
  // 6. Peer Voting & Self-Vote Prevention
  // ---------------------------------------------------------------------------
  it('6. voteOnReport prevents self-voting and records valid peer vote with score recalculation', () => {
    // Report 101 author is Kamal (userId: 1)
    // 6a. Kamal attempts to vote on his own report (Disallowed!)
    const reqSelfVote = {
      params: { id: 101 },
      user: { id: 1 },
      body: { voteType: 'upvote' },
    };
    const resSelfVote = createMockRes();
    voteOnReport(reqSelfVote, resSelfVote);

    assert.strictEqual(resSelfVote.statusCode, 400);
    assert.strictEqual(resSelfVote.body.error.code, 'SELF_VOTING_DISALLOWED');

    // 6b. Independent commuter (userId: 6) upvotes report 101
    const reqPeerVote = {
      params: { id: 101 },
      user: { id: 6 },
      body: { voteType: 'upvote' },
    };
    const resPeerVote = createMockRes();
    voteOnReport(reqPeerVote, resPeerVote);

    assert.strictEqual(resPeerVote.statusCode, 200);
    assert.strictEqual(resPeerVote.body.success, true);
    assert.strictEqual(resPeerVote.body.data.upvotesCount, 9);
    assert.ok(resPeerVote.body.data.reliabilityScore >= 75.0);
    assert.strictEqual(resPeerVote.body.data.confidenceStatus, 'verified');

    // 6c. Toggling vote off when same user clicks again
    const resToggle = createMockRes();
    voteOnReport(reqPeerVote, resToggle);
    assert.strictEqual(resToggle.statusCode, 200);
    assert.strictEqual(resToggle.body.data.upvotesCount, 8);
  });

  // ---------------------------------------------------------------------------
  // 7. Crowd Estimation & Retrieval Controllers
  // ---------------------------------------------------------------------------
  it('7. submitCrowdEstimate persists estimate and updates active route aggregation', () => {
    const req = {
      user: { id: 3 },
      body: {
        routeId: 2,
        crowdLevel: 'crowded',
        passengerWaitTimeMinutes: 12,
      },
    };
    const res = createMockRes();

    submitCrowdEstimate(req, res);

    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.estimate.routeId, 2);
    assert.strictEqual(res.body.data.estimate.crowdLevel, 'crowded');
    assert.strictEqual(res.body.data.aggregation.targetType, 'route');
    assert.strictEqual(res.body.data.aggregation.targetId, 2);

    // Retrieve route crowd
    const reqGet = { params: { routeId: 2 } };
    const resGet = createMockRes();
    getRouteCrowd(reqGet, resGet);
    assert.strictEqual(resGet.statusCode, 200);
    assert.strictEqual(resGet.body.data.targetId, 2);
  });

  // ---------------------------------------------------------------------------
  // 8. Commuter Reputation
  // ---------------------------------------------------------------------------
  it('8. getUserReputation returns commuter trust metrics', () => {
    const req = { user: { id: 1 }, query: {} };
    const res = createMockRes();

    getUserReputation(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.userId, 1);
    assert.ok(res.body.data.reputationScore >= 80.0);
    assert.ok(res.body.data.totalReportsSubmitted >= 6);
  });
});
