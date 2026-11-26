/**
 * TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine
 * Sub-Engine: Spatial-Temporal Duplicate Detector (Suneth)
 * ---------------------------------------------------------------------------
 * Identifies duplicate or corroborating reports using Haversine geographic
 * proximity, transit topology (stops/routes), and sliding time windows.
 */

const EARTH_RADIUS_METERS = 6371000;

/**
 * Calculates straight-line geographic distance between two points in meters
 */
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180.0;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const rLat1 = toRad(lat1);
  const rLat2 = toRad(lat2);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(rLat1) * Math.cos(rLat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(EARTH_RADIUS_METERS * c);
}

/**
 * Checks whether two reports are spatio-temporally equivalent
 */
function areReportsSpatioTemporallyRelated(
  repA,
  repB,
  maxDistanceMeters = 250,
  maxTimeMinutes = 30
) {
  // Category mismatch check
  const catA = repA.categoryId || repA.category_id;
  const catB = repB.categoryId || repB.category_id;
  if (catA && catB && Number(catA) !== Number(catB)) {
    return { isMatch: false, reason: 'DIFFERENT_CATEGORY' };
  }

  // Time delta check
  const timeA = new Date(repA.createdAt || repA.created_at || Date.now()).getTime();
  const timeB = new Date(repB.createdAt || repB.created_at || Date.now()).getTime();
  const timeDeltaMinutes = Math.abs(timeA - timeB) / (1000 * 60);

  if (timeDeltaMinutes > maxTimeMinutes) {
    return { isMatch: false, reason: 'TIME_EXCEEDED', timeDeltaMinutes };
  }

  // Transit topology match (same stop)
  const stopA = repA.stopId || repA.stop_id;
  const stopB = repB.stopId || repB.stop_id;
  if (stopA && stopB && Number(stopA) === Number(stopB)) {
    return {
      isMatch: true,
      reason: 'SAME_STOP',
      distanceMeters: 0,
      timeDeltaMinutes: Math.round(timeDeltaMinutes),
    };
  }

  // Coordinate distance check
  const latA = Number(repA.latitude);
  const lonA = Number(repA.longitude);
  const latB = Number(repB.latitude);
  const lonB = Number(repB.longitude);

  if (!isNaN(latA) && !isNaN(lonA) && !isNaN(latB) && !isNaN(lonB)) {
    const distanceMeters = calculateHaversineDistance(latA, lonA, latB, lonB);
    if (distanceMeters <= maxDistanceMeters) {
      return {
        isMatch: true,
        reason: 'GEO_PROXIMITY',
        distanceMeters,
        timeDeltaMinutes: Math.round(timeDeltaMinutes),
      };
    }
  }

  return { isMatch: false, reason: 'OUT_OF_BOUNDS' };
}

/**
 * Scans an array of existing reports to detect duplicates or corroborating reports
 * @param {object} newReport
 * @param {Array<object>} existingReports
 * @param {number} maxDistanceMeters - default 250m
 * @param {number} maxTimeMinutes - default 30 mins
 * @returns {object} { hasDuplicate, isSelfDuplicate, matches: [] }
 */
function findDuplicates(
  newReport,
  existingReports = [],
  maxDistanceMeters = 250,
  maxTimeMinutes = 30
) {
  const matches = [];
  let isSelfDuplicate = false;

  const newUserId = newReport.userId || newReport.user_id;

  for (const existing of existingReports) {
    if (existing.id && newReport.id && existing.id === newReport.id) {
      continue;
    }

    const check = areReportsSpatioTemporallyRelated(
      newReport,
      existing,
      maxDistanceMeters,
      maxTimeMinutes
    );

    if (check.isMatch) {
      const existingUserId = existing.userId || existing.user_id;
      const sameUser = Boolean(newUserId && existingUserId && Number(newUserId) === Number(existingUserId));
      if (sameUser) {
        isSelfDuplicate = true;
      }

      matches.push({
        reportId: existing.id,
        isSameUser: sameUser,
        reason: check.reason,
        distanceMeters: check.distanceMeters,
        timeDeltaMinutes: check.timeDeltaMinutes,
        existingReport: existing,
      });
    }
  }

  return {
    hasDuplicate: matches.length > 0,
    isSelfDuplicate,
    matches,
    corroborationCount: matches.filter((m) => !m.isSameUser).length,
  };
}

module.exports = {
  calculateHaversineDistance,
  areReportsSpatioTemporallyRelated,
  findDuplicates,
};

