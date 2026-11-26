/**
 * TravelPulse LK — Crowd Intelligence Routes
 * Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)
 * Base URL: /api/v1/crowd
 */

const express = require('express');
const router = express.Router();

const {
  submitCrowdEstimate,
  getRouteCrowd,
  getStopCrowd,
  getAggregations,
  voteOnReport,
  getUserReputation,
} = require('../controllers/crowd.controller');

const { requireAuth, optionalAuth } = require('../middleware/auth.middleware');
const { validateCrowdEstimate, validateReportVote } = require('../validators/crowd.validator');

// 1. Submit real-time crowd estimate (Protected — Requires Authentication)
router.post('/estimate', requireAuth, validateCrowdEstimate, submitCrowdEstimate);

// 2. Get current crowd aggregation for a route (Public)
router.get('/routes/:routeId', getRouteCrowd);

// 3. Get current crowd aggregation for a stop (Public)
router.get('/stops/:stopId', getStopCrowd);

// 4. Get all active crowd aggregations across transit lines (Public)
router.get('/aggregations', getAggregations);

// 5. Cast peer verification vote on a report (Protected — Requires Authentication)
router.post('/vote', requireAuth, validateReportVote, voteOnReport);

// 6. Get user reputation & credibility score (Protected)
router.get('/reputation', requireAuth, getUserReputation);

module.exports = router;

