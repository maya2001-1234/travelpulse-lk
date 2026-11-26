/**
 * TravelPulse LK — Crowd Intelligence & Report Reliability Controller
 * Owning Member: Suneth
 */

const { crowdRepository } = require('../repositories');
const db = require('../config/db');
const { memoryStore } = require('../config/db');

/**
 * 1. POST /api/v1/crowd/estimate
 * Submit real-time commuter crowd observation
 */
async function submitCrowdEstimate(req, res) {
  const userId = req.user.id;
  const { routeId, stopId, crowdLevel, passengerWaitTimeMinutes } = req.body;

  if (db.isLiveDb) {
    try {
      const result = await crowdRepository.submitCrowdEstimate({
        userId,
        routeId: routeId ? Number(routeId) : null,
        stopId: stopId ? Number(stopId) : null,
        crowdLevel: crowdLevel.toLowerCase(),
        passengerWaitTimeMinutes: passengerWaitTimeMinutes !== undefined ? Number(passengerWaitTimeMinutes) : null,
      });

      return res.status(201).json({
        success: true,
        statusCode: 201,
        message: 'Crowd observation recorded and aggregated successfully.',
        data: {
          estimate: result.estimate,
          aggregation: result.aggregation
            ? {
                targetType: result.aggregation.routeId ? 'route' : 'stop',
                targetId: result.aggregation.routeId || result.aggregation.stopId,
                currentCrowdLevel: result.aggregation.aggregatedCrowdLevel,
                sampleCount: result.aggregation.sampleCount,
                confidenceScore: result.aggregation.confidenceScore,
                lastUpdatedAt: result.aggregation.lastUpdatedAt || result.aggregation.timeSlot,
              }
            : null,
        },
      });
    } catch (error) {
      console.error('[CrowdController.submitCrowdEstimate] Error:', error);
      return res.status(400).json({
        success: false,
        statusCode: 400,
        message: error.message || 'Failed to record crowd observation.',
        error: { code: 'CROWD_ESTIMATE_ERROR' },
      });
    }
  }

  db.assertFallbackAllowed();
  try {
    const estimate = memoryStore.addCrowdEstimate({
      user_id: userId,
      route_id: routeId ? Number(routeId) : null,
      stop_id: stopId ? Number(stopId) : null,
      crowd_level: crowdLevel.toLowerCase(),
      passenger_wait_time_minutes: passengerWaitTimeMinutes !== undefined ? Number(passengerWaitTimeMinutes) : null,
    });

    const aggregation = memoryStore.getCrowdAggregation({
      routeId: estimate.route_id,
      stopId: estimate.stop_id,
    });

    return res.status(201).json({
      success: true,
      statusCode: 201,
      message: 'Crowd observation recorded and aggregated successfully.',
      data: {
        estimate: {
          id: estimate.id,
          userId: estimate.user_id,
          routeId: estimate.route_id,
          stopId: estimate.stop_id,
          crowdLevel: estimate.crowd_level,
          passengerWaitTimeMinutes: estimate.passenger_wait_time_minutes,
          reportedAt: estimate.reported_at,
        },
        aggregation: aggregation
          ? {
              targetType: aggregation.route_id ? 'route' : 'stop',
              targetId: aggregation.route_id || aggregation.stop_id,
              currentCrowdLevel: aggregation.aggregated_crowd_level,
              sampleCount: aggregation.sample_count,
              confidenceScore: aggregation.confidence_score,
              lastUpdatedAt: aggregation.last_updated_at,
            }
          : null,
      },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: error.message || 'Failed to record crowd observation.',
      error: { code: 'CROWD_ESTIMATE_ERROR' },
    });
  }
}

/**
 * 2. GET /api/v1/crowd/routes/:routeId
 * Get current aggregated crowd level for a transport route
 */
async function getRouteCrowd(req, res) {
  const routeId = Number(req.params.routeId);

  if (isNaN(routeId)) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Invalid routeId parameter.',
      error: { code: 'INVALID_ROUTE_ID' },
    });
  }

  if (db.isLiveDb) {
    try {
      let aggregation = await crowdRepository.getCrowdAggregation(routeId, null);
      if (!aggregation) {
        aggregation = {
          route_id: routeId,
          stop_id: null,
          time_slot: new Date().toISOString(),
          aggregated_crowd_level: 'moderate',
          sample_count: 0,
          confidence_score: 30.0,
          last_updated_at: new Date().toISOString(),
          is_baseline: true,
        };
      }
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Route crowd aggregation retrieved successfully.',
        data: {
          targetType: 'route',
          targetId: routeId,
          currentCrowdLevel: aggregation.aggregatedCrowdLevel || aggregation.aggregated_crowd_level,
          sampleCount: aggregation.sampleCount || aggregation.sample_count,
          confidenceScore: aggregation.confidenceScore || aggregation.confidence_score,
          lastUpdatedAt: aggregation.lastUpdatedAt || aggregation.last_updated_at || aggregation.time_slot,
          isBaseline: Boolean(aggregation.is_baseline),
        },
      });
    } catch (err) {
      console.error('[CrowdController.getRouteCrowd] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  let aggregation = memoryStore.getCrowdAggregation({ routeId });
  if (!aggregation) {
    aggregation = {
      route_id: routeId,
      stop_id: null,
      time_slot: new Date().toISOString(),
      aggregated_crowd_level: 'moderate',
      sample_count: 0,
      confidence_score: 30.0,
      last_updated_at: new Date().toISOString(),
      is_baseline: true,
    };
  }

  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Route crowd aggregation retrieved successfully.',
    data: {
      targetType: 'route',
      targetId: routeId,
      currentCrowdLevel: aggregation.aggregated_crowd_level,
      sampleCount: aggregation.sample_count,
      confidenceScore: aggregation.confidence_score,
      lastUpdatedAt: aggregation.last_updated_at || aggregation.time_slot,
      isBaseline: Boolean(aggregation.is_baseline),
    },
  });
}

/**
 * 3. GET /api/v1/crowd/stops/:stopId
 * Get current aggregated crowd level for a stop
 */
async function getStopCrowd(req, res) {
  const stopId = Number(req.params.stopId);

  if (isNaN(stopId)) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Invalid stopId parameter.',
      error: { code: 'INVALID_STOP_ID' },
    });
  }

  if (db.isLiveDb) {
    try {
      let aggregation = await crowdRepository.getCrowdAggregation(null, stopId);
      if (!aggregation) {
        aggregation = {
          route_id: null,
          stop_id: stopId,
          time_slot: new Date().toISOString(),
          aggregated_crowd_level: 'moderate',
          sample_count: 0,
          confidence_score: 30.0,
          last_updated_at: new Date().toISOString(),
          is_baseline: true,
        };
      }
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Stop crowd aggregation retrieved successfully.',
        data: {
          targetType: 'stop',
          targetId: stopId,
          currentCrowdLevel: aggregation.aggregatedCrowdLevel || aggregation.aggregated_crowd_level,
          sampleCount: aggregation.sampleCount || aggregation.sample_count,
          confidenceScore: aggregation.confidenceScore || aggregation.confidence_score,
          lastUpdatedAt: aggregation.lastUpdatedAt || aggregation.last_updated_at || aggregation.time_slot,
          isBaseline: Boolean(aggregation.is_baseline),
        },
      });
    } catch (err) {
      console.error('[CrowdController.getStopCrowd] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  let aggregation = memoryStore.getCrowdAggregation({ stopId });
  if (!aggregation) {
    aggregation = {
      route_id: null,
      stop_id: stopId,
      time_slot: new Date().toISOString(),
      aggregated_crowd_level: 'moderate',
      sample_count: 0,
      confidence_score: 30.0,
      last_updated_at: new Date().toISOString(),
      is_baseline: true,
    };
  }

  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Stop crowd aggregation retrieved successfully.',
    data: {
      targetType: 'stop',
      targetId: stopId,
      currentCrowdLevel: aggregation.aggregated_crowd_level,
      sampleCount: aggregation.sample_count,
      confidenceScore: aggregation.confidence_score,
      lastUpdatedAt: aggregation.last_updated_at || aggregation.time_slot,
      isBaseline: Boolean(aggregation.is_baseline),
    },
  });
}

/**
 * 4. GET /api/v1/crowd/aggregations
 * Get all active crowd aggregations across transit network
 */
async function getAggregations(req, res) {
  if (db.isLiveDb) {
    try {
      const [rows] = await db.query('SELECT * FROM crowd_aggregations ORDER BY last_updated_at DESC');
      const formatted = rows.map((a) => ({
        id: a.id,
        targetType: a.route_id ? 'route' : 'stop',
        targetId: a.route_id || a.stop_id,
        currentCrowdLevel: a.aggregated_crowd_level,
        sampleCount: a.sample_count,
        confidenceScore: parseFloat(a.confidence_score),
        timeSlot: a.time_slot,
        lastUpdatedAt: a.last_updated_at,
      }));
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Active transit crowd aggregations retrieved successfully.',
        data: formatted,
      });
    } catch (err) {
      console.error('[CrowdController.getAggregations] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const rawList = memoryStore.getAllCrowdAggregations();
  const formatted = rawList.map((a) => ({
    id: a.id,
    targetType: a.route_id ? 'route' : 'stop',
    targetId: a.route_id || a.stop_id,
    currentCrowdLevel: a.aggregated_crowd_level,
    sampleCount: a.sample_count,
    confidenceScore: a.confidence_score,
    timeSlot: a.time_slot,
    lastUpdatedAt: a.last_updated_at,
  }));

  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Active transit crowd aggregations retrieved successfully.',
    data: formatted,
  });
}

/**
 * 5. POST /api/v1/reports/:id/vote or /api/v1/crowd/vote
 * Cast peer verification vote on a community report
 */
async function voteOnReport(req, res) {
  const reportId = Number(req.params.id || req.body.reportId);
  const userId = req.user.id;
  const { voteType } = req.body;

  if (isNaN(reportId)) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Invalid report ID.',
      error: { code: 'INVALID_REPORT_ID' },
    });
  }

  if (db.isLiveDb) {
    try {
      const result = await crowdRepository.voteOnReport(reportId, userId, voteType.toLowerCase());

      if (result.error === 'REPORT_NOT_FOUND') {
        return res.status(404).json({
          success: false,
          statusCode: 404,
          message: `Community report #${reportId} not found.`,
          error: { code: 'REPORT_NOT_FOUND' },
        });
      }

      if (result.error === 'SELF_VOTING_FORBIDDEN') {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          message: result.message || 'Authors cannot vote on their own community reports.',
          error: { code: 'SELF_VOTING_DISALLOWED' },
        });
      }

      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: `Vote '${voteType}' recorded successfully.`,
        data: {
          ...result,
          reportId: result.id,
          userVote: voteType.toLowerCase(),
        },
      });
    } catch (err) {
      console.error('[CrowdController.voteOnReport] Error:', err);
      return res.status(400).json({
        success: false,
        statusCode: 400,
        message: err.message || 'Failed to record vote.',
        error: { code: 'VOTE_ERROR' },
      });
    }
  }

  db.assertFallbackAllowed();
  const report = memoryStore.getReportById(reportId);
  if (!report) {
    return res.status(404).json({
      success: false,
      statusCode: 404,
      message: `Community report #${reportId} not found.`,
      error: { code: 'REPORT_NOT_FOUND' },
    });
  }

  // Prevent author from voting on their own report
  if (Number(report.user_id) === Number(userId)) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Authors cannot vote on their own community reports.',
      error: { code: 'SELF_VOTING_DISALLOWED' },
    });
  }

  try {
    const result = memoryStore.castReportVote({
      reportId,
      userId,
      voteType: voteType.toLowerCase(),
    });

    return res.status(200).json({
      success: true,
      statusCode: 200,
      message: `Vote '${voteType}' recorded successfully.`,
      data: {
        id: result.report.id,
        reportId: result.report.id,
        userId: result.report.user_id,
        userName: result.report.is_anonymous ? 'Anonymous Commuter' : result.report.user_name,
        isAnonymous: Boolean(result.report.is_anonymous),
        categoryId: result.report.category_id,
        categoryName: result.report.category_name,
        routeId: result.report.route_id,
        routeNumber: result.report.route_number,
        stopId: result.report.stop_id,
        stopName: result.report.stop_name,
        latitude: result.report.latitude,
        longitude: result.report.longitude,
        locationDescription: result.report.location_description,
        title: result.report.title,
        description: result.report.description,
        disruptionReason: result.report.disruption_reason,
        mediaUrl: result.report.media_url,
        status: result.report.status,
        reliabilityScore: result.report.reliability_score,
        confidenceStatus: result.report.confidence_status,
        upvotesCount: result.report.upvotes_count,
        downvotesCount: result.report.downvotes_count,
        userVote: result.userVote,
        createdAt: result.report.created_at,
        resolvedAt: result.report.resolved_at,
      },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: error.message || 'Failed to record vote.',
      error: { code: 'VOTE_ERROR' },
    });
  }
}

/**
 * 6. GET /api/v1/crowd/reputation
 * Retrieve commuter credibility score and contribution stats
 */
async function getUserReputation(req, res) {
  const targetUserId = req.query.userId ? Number(req.query.userId) : req.user.id;

  if (db.isLiveDb) {
    try {
      const reputation = await crowdRepository.getUserReputation(targetUserId);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'User reputation retrieved successfully.',
        data: {
          userId: reputation.user_id,
          reputationScore: parseFloat(reputation.reputation_score),
          totalReportsSubmitted: Number(reputation.total_reports_submitted),
          verifiedReportsCount: Number(reputation.verified_reports_count),
          rejectedReportsCount: Number(reputation.rejected_reports_count),
          totalVotesCast: Number(reputation.total_votes_cast),
          updatedAt: reputation.updated_at,
        },
      });
    } catch (err) {
      console.error('[CrowdController.getUserReputation] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const reputation = memoryStore.getUserReputation(targetUserId);
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'User reputation retrieved successfully.',
    data: {
      userId: reputation.user_id,
      reputationScore: reputation.reputation_score,
      totalReportsSubmitted: reputation.total_reports_submitted,
      verifiedReportsCount: reputation.verified_reports_count,
      rejectedReportsCount: reputation.rejected_reports_count,
      totalVotesCast: reputation.total_votes_cast,
      updatedAt: reputation.updated_at,
    },
  });
}

module.exports = {
  submitCrowdEstimate,
  getRouteCrowd,
  getStopCrowd,
  getAggregations,
  voteOnReport,
  getUserReputation,
};
