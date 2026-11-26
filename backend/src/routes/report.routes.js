/**
 * TravelPulse LK — Community Reporting Routes
 * Module 2: Community Reporting & Transport Disruption Management (Dumindi)
 * Base URL: /api/v1/reports
 */

const express = require('express');
const router = express.Router();

const {
  getCategories,
  getPublicReports,
  getReportById,
  getMyReports,
  getDisruptions,
  createReport,
  updateReport,
  deleteReport,
} = require('../controllers/report.controller');

const { requireAuth, optionalAuth } = require('../middleware/auth.middleware');
const { validateCreateReport, validateUpdateReport } = require('../validators/report.validator');
const { voteOnReport } = require('../controllers/crowd.controller');
const { validateReportVote } = require('../validators/crowd.validator');

// 1. Master Categories Taxonomy (Public)
router.get('/categories', getCategories);

// 2. Verified Transport Disruptions (Public)
router.get('/disruptions', getDisruptions);

// 3. Commuter's Authored Reports (Protected — Requires Authentication)
router.get('/my-reports', requireAuth, getMyReports);

// 4. Public Community Feed (Public with optional auth for personal indicators)
router.get('/', optionalAuth, getPublicReports);

// 5. Single Report Details (Public with optional auth)
router.get('/:id', optionalAuth, getReportById);

// 6. Submit New Community Report (Protected — Requires Authentication)
router.post('/', requireAuth, validateCreateReport, createReport);

// 7. Update Report (Protected — Author or Moderator)
router.patch('/:id', requireAuth, validateUpdateReport, updateReport);

// 8. Delete Report (Protected — Strictly Author or Moderator)
router.delete('/:id', requireAuth, deleteReport);

// 9. Peer Verification Voting on Report (Protected — Commuter)
router.post('/:id/vote', requireAuth, validateReportVote, voteOnReport);

module.exports = router;
