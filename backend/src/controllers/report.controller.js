/**
 * TravelPulse LK — Community Report Controller
 * Module 2: Community Reporting & Transport Disruption Management (Dumindi)
 */

const { reportRepository } = require('../repositories');
const db = require('../config/db');
const { memoryStore } = require('../config/db');

/**
 * Helper to mask anonymous reporter details in public views
 */
function sanitizeReportForPublic(report, requestingUserId = null, isStaff = false) {
  const isAuthor = requestingUserId !== null && Number(requestingUserId) === Number(report.user_id || report.userId);
  const canSeeIdentity = isAuthor || isStaff;

  return {
    id: report.id,
    userId: canSeeIdentity ? (report.user_id || report.userId) : null,
    userName: (report.is_anonymous || report.isAnonymous) && !canSeeIdentity ? 'Anonymous Commuter' : (report.user_name || report.userName),
    isAnonymous: Boolean(report.is_anonymous || report.isAnonymous),
    categoryId: report.category_id || report.categoryId,
    categoryName: report.category_name || report.categoryName,
    routeId: report.route_id || report.routeId,
    routeNumber: report.route_number || report.routeNumber,
    stopId: report.stop_id || report.stopId,
    stopName: report.stop_name || report.stopName,
    latitude: report.latitude,
    longitude: report.longitude,
    locationDescription: report.location_description || report.locationDescription,
    title: report.title,
    description: report.description,
    disruptionReason: report.disruption_reason || report.disruptionReason,
    transportType: report.transport_type || report.transportType || null,
    busRouteNumber: report.bus_route_number || report.busRouteNumber || null,
    destination: report.destination || null,
    busRegistrationNumber: report.bus_registration_number || report.busRegistrationNumber || null,
    trainNameOrNumber: report.train_name_or_number || report.trainNameOrNumber || null,
    startingStation: report.starting_station || report.startingStation || null,
    crowdLevel: report.crowd_level || report.crowdLevel || null,
    mediaUrl: report.media_url || report.mediaUrl,
    status: report.status,
    reliabilityScore: report.reliability_score !== undefined ? report.reliability_score : report.reliabilityScore,
    confidenceStatus: report.confidence_status || report.confidenceStatus,
    upvotesCount: report.upvotes_count !== undefined ? report.upvotes_count : report.upvotesCount,
    downvotesCount: report.downvotes_count !== undefined ? report.downvotes_count : report.downvotesCount,
    isOwnReport: isAuthor,
    createdAt: report.created_at || report.createdAt,
    resolvedAt: report.resolved_at || report.resolvedAt,
  };
}

/**
 * 1. GET /api/v1/reports/categories
 */
async function getCategories(req, res) {
  if (db.isLiveDb) {
    try {
      const categories = await reportRepository.getCategories();
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Report categories retrieved successfully',
        data: categories,
      });
    } catch (err) {
      console.error('[ReportController.getCategories] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const categories = memoryStore.getCategories();
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Report categories retrieved successfully',
    data: categories.map((c) => ({
      id: c.id,
      code: c.code,
      name: c.name,
      description: c.description,
      defaultSeverity: c.default_severity,
    })),
  });
}

/**
 * 2. GET /api/v1/reports
 */
async function getPublicReports(req, res) {
  const { categoryId, status, routeId, page = 1, limit = 20 } = req.query;
  const currentUserId = req.user ? req.user.id : null;
  const isStaff = req.user ? (req.user.role === 'moderator' || req.user.role === 'admin') : false;

  if (db.isLiveDb) {
    try {
      const reports = await reportRepository.getReports({
        categoryId: categoryId ? Number(categoryId) : null,
        status,
        routeId: routeId ? Number(routeId) : null,
        requestingUserId: currentUserId,
      });
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Community reports retrieved successfully',
        data: reports.map((r) => sanitizeReportForPublic(r, currentUserId, isStaff)),
        meta: { page: Number(page), limit: Number(limit), total: reports.length },
      });
    } catch (err) {
      console.error('[ReportController.getPublicReports] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const rawReports = memoryStore.getReports({
    categoryId: categoryId ? Number(categoryId) : null,
    status,
    routeId: routeId ? Number(routeId) : null,
  });

  const sanitized = rawReports.map((r) => sanitizeReportForPublic(r, currentUserId, isStaff));
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Community reports retrieved successfully',
    data: sanitized,
    meta: { page: Number(page), limit: Number(limit), total: sanitized.length },
  });
}

/**
 * 3. GET /api/v1/reports/:id
 */
async function getReportById(req, res) {
  const reportId = Number(req.params.id);
  const currentUserId = req.user ? req.user.id : null;
  const isStaff = req.user ? (req.user.role === 'moderator' || req.user.role === 'admin') : false;

  if (db.isLiveDb) {
    try {
      const report = await reportRepository.findReportById(reportId, currentUserId);
      if (!report) {
        return res.status(404).json({
          success: false,
          statusCode: 404,
          message: `Community report #${reportId} not found.`,
          error: { code: 'RESOURCE_NOT_FOUND' },
        });
      }
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Report details retrieved successfully',
        data: sanitizeReportForPublic(report, currentUserId, isStaff),
      });
    } catch (err) {
      console.error('[ReportController.getReportById] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const report = memoryStore.getReportById(reportId);
  if (!report) {
    return res.status(404).json({
      success: false,
      statusCode: 404,
      message: `Community report #${reportId} not found.`,
      error: { code: 'RESOURCE_NOT_FOUND' },
    });
  }

  const sanitized = sanitizeReportForPublic(report, currentUserId, isStaff);
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Report details retrieved successfully',
    data: sanitized,
  });
}

/**
 * 4. GET /api/v1/reports/my-reports
 */
async function getMyReports(req, res) {
  const userId = req.user.id;

  if (db.isLiveDb) {
    try {
      const reports = await reportRepository.getMyReports(userId);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Authored reports retrieved successfully',
        data: reports.map((r) => ({ ...r, isOwnReport: true })),
        meta: { total: reports.length },
      });
    } catch (err) {
      console.error('[ReportController.getMyReports] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const reports = memoryStore.getReportsByUserId(userId);
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Authored reports retrieved successfully',
    data: reports.map((r) => ({
      id: r.id,
      userId: r.user_id,
      userName: r.user_name,
      isAnonymous: Boolean(r.is_anonymous),
      categoryId: r.category_id,
      categoryName: r.category_name,
      routeId: r.route_id,
      routeNumber: r.route_number,
      stopId: r.stop_id,
      stopName: r.stop_name,
      latitude: r.latitude,
      longitude: r.longitude,
      locationDescription: r.location_description,
      title: r.title,
      description: r.description,
      disruptionReason: r.disruption_reason,
      transportType: r.transport_type || null,
      busRouteNumber: r.bus_route_number || null,
      destination: r.destination || null,
      busRegistrationNumber: r.bus_registration_number || null,
      trainNameOrNumber: r.train_name_or_number || null,
      startingStation: r.starting_station || null,
      crowdLevel: r.crowd_level || null,
      mediaUrl: r.media_url,
      status: r.status,
      reliabilityScore: r.reliability_score,
      confidenceStatus: r.confidence_status,
      upvotesCount: r.upvotes_count,
      downvotesCount: r.downvotes_count,
      isOwnReport: true,
      createdAt: r.created_at,
      resolvedAt: r.resolved_at,
    })),
    meta: { total: reports.length },
  });
}

/**
 * 5. POST /api/v1/reports
 */
async function createReport(req, res) {
  const {
    categoryId,
    routeId,
    routeNumber,
    stopId,
    stopName,
    latitude,
    longitude,
    locationDescription,
    title,
    description,
    disruptionReason,
    transportType,
    busRouteNumber,
    destination,
    busRegistrationNumber,
    trainNameOrNumber,
    startingStation,
    crowdLevel,
    isAnonymous,
    mediaUrl,
  } = req.body;

  const userId = req.user.id;
  const userName = req.user.name || 'Commuter';
  const userEmail = req.user.email || '';

  const isCrowdCategory = Number(categoryId) === 1;
  const rawTransportType = transportType || req.body.transport_type;
  const normTransportType = isCrowdCategory && rawTransportType
    ? rawTransportType.trim().toLowerCase()
    : null;

  const isBus = isCrowdCategory && normTransportType === 'bus';
  const isTrain = isCrowdCategory && normTransportType === 'train';

  const rawBusRoute = busRouteNumber || req.body.bus_route_number;
  const normBusRouteNumber = isBus && rawBusRoute ? rawBusRoute.trim() : null;

  const normDestination = (isBus || isTrain) && destination ? destination.trim() : null;

  const rawBusReg = busRegistrationNumber || req.body.bus_registration_number;
  const normBusRegistration = isBus && rawBusReg ? rawBusReg.trim() : null;

  const rawTrainName = trainNameOrNumber || req.body.train_name_or_number;
  const normTrainName = isTrain && rawTrainName ? rawTrainName.trim() : null;

  const rawStartStation = startingStation || req.body.starting_station;
  const normStartingStation = isTrain && rawStartStation ? rawStartStation.trim() : null;

  const rawCrowdLevel = crowdLevel || req.body.crowd_level;
  const normCrowdLevel = (isBus || isTrain) && rawCrowdLevel
    ? rawCrowdLevel.trim().toLowerCase()
    : null;

  if (db.isLiveDb) {
    try {
      const newReport = await reportRepository.createReport({
        userId,
        user: req.user,
        categoryId: Number(categoryId),
        routeId: routeId ? Number(routeId) : null,
        stopId: stopId ? Number(stopId) : null,
        latitude: Number(latitude),
        longitude: Number(longitude),
        locationDescription: locationDescription || '',
        title: title.trim(),
        description: description.trim(),
        disruptionReason: disruptionReason ? disruptionReason.trim() : null,
        transportType: normTransportType,
        busRouteNumber: normBusRouteNumber,
        destination: normDestination,
        busRegistrationNumber: normBusRegistration,
        trainNameOrNumber: normTrainName,
        startingStation: normStartingStation,
        crowdLevel: normCrowdLevel,
        mediaUrl: mediaUrl || null,
        isAnonymous: Boolean(isAnonymous),
      });

      return res.status(201).json({
        success: true,
        statusCode: 201,
        message: 'Community report created successfully',
        data: sanitizeReportForPublic(newReport, userId, false),
      });
    } catch (err) {
      console.error('[ReportController.createReport] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const newReport = memoryStore.createReport({
    user_id: userId,
    user_name: userName,
    user_email: userEmail,
    is_anonymous: Boolean(isAnonymous),
    category_id: Number(categoryId),
    route_id: routeId ? Number(routeId) : null,
    route_number: routeNumber || null,
    stop_id: stopId ? Number(stopId) : null,
    stop_name: stopName || null,
    latitude: Number(latitude),
    longitude: Number(longitude),
    location_description: locationDescription || '',
    title: title.trim(),
    description: description.trim(),
    disruption_reason: disruptionReason ? disruptionReason.trim() : null,
    transport_type: normTransportType,
    bus_route_number: normBusRouteNumber,
    destination: normDestination,
    bus_registration_number: normBusRegistration,
    train_name_or_number: normTrainName,
    starting_station: normStartingStation,
    crowd_level: normCrowdLevel,
    media_url: mediaUrl || null,
  });

  return res.status(201).json({
    success: true,
    statusCode: 201,
    message: 'Community report created successfully',
    data: sanitizeReportForPublic(newReport, userId, false),
  });
}

/**
 * 6. PATCH /api/v1/reports/:id
 */
async function updateReport(req, res) {
  const reportId = Number(req.params.id);
  const userId = req.user.id;
  const isStaff = req.user.role === 'moderator' || req.user.role === 'admin';

  if (db.isLiveDb) {
    try {
      const existing = await reportRepository.findReportById(reportId);
      if (!existing) {
        return res.status(404).json({
          success: false,
          statusCode: 404,
          message: `Report #${reportId} not found.`,
          error: { code: 'RESOURCE_NOT_FOUND' },
        });
      }

      if (Number(existing.userId) !== Number(userId) && !isStaff) {
        return res.status(403).json({
          success: false,
          statusCode: 403,
          message: 'Unauthorized. You can only update reports that you have authored.',
          error: { code: 'FORBIDDEN_RESOURCE' },
        });
      }

      const updates = {};
      if (req.body.title) updates.title = req.body.title.trim();
      if (req.body.description) updates.description = req.body.description.trim();
      if (req.body.status && isStaff) updates.status = req.body.status;
      if (req.body.locationDescription !== undefined) updates.location_description = req.body.locationDescription;

      const updated = await reportRepository.updateReport(reportId, updates);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Report updated successfully',
        data: sanitizeReportForPublic(updated, userId, isStaff),
      });
    } catch (err) {
      console.error('[ReportController.updateReport] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const existing = memoryStore.getReportById(reportId);
  if (!existing) {
    return res.status(404).json({
      success: false,
      statusCode: 404,
      message: `Report #${reportId} not found.`,
      error: { code: 'RESOURCE_NOT_FOUND' },
    });
  }

  if (existing.user_id !== userId && !isStaff) {
    return res.status(403).json({
      success: false,
      statusCode: 403,
      message: 'Unauthorized. You can only update reports that you have authored.',
      error: { code: 'FORBIDDEN_RESOURCE' },
    });
  }

  const updates = {};
  if (req.body.title) updates.title = req.body.title.trim();
  if (req.body.description) updates.description = req.body.description.trim();
  if (req.body.status && isStaff) updates.status = req.body.status;
  if (req.body.locationDescription !== undefined) updates.location_description = req.body.locationDescription;

  const updated = memoryStore.updateReport(reportId, updates);
  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Report updated successfully',
    data: sanitizeReportForPublic(updated, userId, isStaff),
  });
}

/**
 * 7. DELETE /api/v1/reports/:id
 */
async function deleteReport(req, res) {
  const reportId = Number(req.params.id);
  const userId = req.user.id;
  const isStaff = req.user.role === 'moderator' || req.user.role === 'admin';

  if (db.isLiveDb) {
    try {
      const result = await reportRepository.deleteReport(reportId, userId, isStaff);
      if (result.error === 'REPORT_NOT_FOUND') {
        return res.status(404).json({
          success: false,
          statusCode: 404,
          message: `Report #${reportId} not found.`,
          error: { code: 'RESOURCE_NOT_FOUND' },
        });
      }
      if (result.error === 'FORBIDDEN') {
        return res.status(403).json({
          success: false,
          statusCode: 403,
          message: 'Unauthorized. You can only delete reports that you have authored.',
          error: { code: 'FORBIDDEN_RESOURCE' },
        });
      }
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Report deleted successfully',
        data: { deletedReportId: reportId },
      });
    } catch (err) {
      console.error('[ReportController.deleteReport] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const existing = memoryStore.getReportById(reportId);
  if (!existing) {
    return res.status(404).json({
      success: false,
      statusCode: 404,
      message: `Report #${reportId} not found.`,
      error: { code: 'RESOURCE_NOT_FOUND' },
    });
  }

  if (existing.user_id !== userId && !isStaff) {
    return res.status(403).json({
      success: false,
      statusCode: 403,
      message: 'Unauthorized. You can only delete reports that you have authored.',
      error: { code: 'FORBIDDEN_RESOURCE' },
    });
  }

  memoryStore.deleteReport(reportId);

  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: 'Report deleted successfully',
    data: { deletedReportId: reportId },
  });
}

/**
 * 8. GET /api/v1/reports/disruptions
 */
async function getDisruptions(req, res) {
  if (db.isLiveDb) {
    try {
      const disruptions = await reportRepository.getDisruptions();
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: `Retrieved ${disruptions.length} transit disruptions.`,
        data: disruptions,
      });
    } catch (err) {
      console.error('[ReportController.getDisruptions] Error:', err);
      return res.status(500).json({ success: false, statusCode: 500, message: 'Database error' });
    }
  }

  db.assertFallbackAllowed();
  const disruptionReports = memoryStore.getReports({ categoryId: 4 });
  const disruptions = disruptionReports.map((r) => ({
    id: r.id + 100,
    originatingReportId: r.id,
    routeId: r.route_id || 1,
    routeNumber: r.route_number || '138',
    routeName: r.route_number ? `Route ${r.route_number}` : 'Colombo Transit Line',
    affectedStopId: r.stop_id,
    affectedStopName: r.stop_name || 'En-route stop',
    disruptionType: r.disruption_reason || 'Vehicle Breakdown',
    severity: r.category_id === 4 ? 'high' : 'medium',
    headline: r.title,
    details: r.description,
    status: r.status === 'resolved' ? 'cleared' : 'active',
    startedAt: r.created_at,
    estimatedClearedAt: r.resolved_at || new Date(Date.now() + 45 * 60 * 1000).toISOString(),
    clearedAt: r.resolved_at,
  }));

  return res.status(200).json({
    success: true,
    statusCode: 200,
    message: `Retrieved ${disruptions.length} transit disruptions.`,
    data: disruptions,
  });
}

module.exports = {
  getCategories,
  getPublicReports,
  getReportById,
  getMyReports,
  getDisruptions,
  createReport,
  updateReport,
  deleteReport,
  sanitizeReportForPublic,
};
