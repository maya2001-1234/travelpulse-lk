/**
 * TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine
 * Sub-Engine: Crowd Density Aggregation Engine (Suneth)
 * ---------------------------------------------------------------------------
 * Aggregates commuter crowd observations for transit routes and stops over
 * sliding time intervals (15 - 30 minutes).
 * Features:
 *  - Deduplication: latest submission from the same commuter supersedes earlier ones
 *  - Freshness weighting: recent observations carry higher statistical weight
 *  - Commuter reputation weighting: high-trust commuters contribute higher weight
 *  - Dual nullable foreign key formatting for Table 16: `crowd_aggregations`
 */

const { calculateFreshnessWeight, getTimeElapsedMinutes } = require('./freshnessEngine');

const CROWD_LEVEL_VALUES = {
  empty: 1,
  moderate: 2,
  crowded: 3,
  very_crowded: 4,
};

const VALUE_TO_CROWD_LEVEL = [
  { max: 1.5, level: 'empty' },
  { max: 2.5, level: 'moderate' },
  { max: 3.5, level: 'crowded' },
  { max: 4.0, level: 'very_crowded' },
];

/**
 * Resolves numerical value to discrete crowd level string
 */
function resolveCrowdLevel(numericValue) {
  for (const threshold of VALUE_TO_CROWD_LEVEL) {
    if (numericValue <= threshold.max) {
      return threshold.level;
    }
  }
  return 'very_crowded';
}

/**
 * Ingests a collection of raw crowd estimates and computes a statistical aggregation
 * @param {object} params
 * @param {number|null} params.routeId
 * @param {number|null} params.stopId
 * @param {Array<object>} params.estimates - Array of crowd estimate records
 * @param {object} params.userReputations - Map of userId -> reputationScore
 * @param {number} params.windowMinutes - Sliding window duration (default 30 mins)
 */
function aggregateCrowdEstimates({
  routeId = null,
  stopId = null,
  estimates = [],
  userReputations = {},
  windowMinutes = 30,
}) {
  // Validate dual-nullable constraint: exactly one must be provided
  const hasRoute = routeId !== null && routeId !== undefined;
  const hasStop = stopId !== null && stopId !== undefined;

  if ((hasRoute && hasStop) || (!hasRoute && !hasStop)) {
    throw new Error('Aggregation target must specify EXACTLY ONE of routeId or stopId (chk_crowd_agg_target).');
  }

  // 1. Filter estimates matching the target route or stop
  const targetEstimates = estimates.filter((e) => {
    if (hasRoute) {
      const eRoute = e.routeId || e.route_id;
      return Number(eRoute) === Number(routeId);
    } else {
      const eStop = e.stopId || e.stop_id;
      return Number(eStop) === Number(stopId);
    }
  });

  // 2. Filter by sliding window
  const activeEstimates = targetEstimates.filter((e) => {
    const elapsed = getTimeElapsedMinutes(e.reportedAt || e.reported_at);
    return elapsed <= windowMinutes;
  });

  if (activeEstimates.length === 0) {
    return {
      route_id: hasRoute ? Number(routeId) : null,
      stop_id: hasStop ? Number(stopId) : null,
      time_slot: new Date().toISOString(),
      aggregated_crowd_level: 'moderate', // Baseline default
      sample_count: 0,
      confidence_score: 30.0,
      average_wait_time_minutes: null,
      is_baseline: true,
    };
  }

  // 3. Deduplicate by user: keep only the newest observation from each user
  const latestByUser = new Map();
  for (const est of activeEstimates) {
    const userId = est.userId || est.user_id;
    const existing = latestByUser.get(userId);
    const estTime = new Date(est.reportedAt || est.reported_at).getTime();

    if (!existing || estTime > new Date(existing.reportedAt || existing.reported_at).getTime()) {
      latestByUser.set(userId, est);
    }
  }

  const dedupedEstimates = Array.from(latestByUser.values());

  // 4. Calculate weighted crowd sum and wait time
  let totalWeight = 0;
  let weightedSum = 0;
  let waitTimeSum = 0;
  let waitTimeSamples = 0;

  for (const est of dedupedEstimates) {
    const levelStr = (est.crowdLevel || est.crowd_level || 'moderate').toLowerCase();
    const numericLevel = CROWD_LEVEL_VALUES[levelStr] || 2;

    const reportedAt = est.reportedAt || est.reported_at;
    const freshness = calculateFreshnessWeight(reportedAt, 'CROWD');

    const userId = est.userId || est.user_id;
    const repScore = userReputations[userId] || 50.0;
    const repWeight = 0.7 + (repScore / 100) * 0.6; // 0.7 to 1.3 multiplier

    const sampleWeight = freshness * repWeight;

    weightedSum += numericLevel * sampleWeight;
    totalWeight += sampleWeight;

    const waitMins = est.passengerWaitTimeMinutes || est.passenger_wait_time_minutes;
    if (waitMins !== null && waitMins !== undefined && !isNaN(waitMins)) {
      waitTimeSum += Number(waitMins);
      waitTimeSamples += 1;
    }
  }

  const finalNumeric = totalWeight > 0 ? weightedSum / totalWeight : 2.0;
  const aggregatedLevel = resolveCrowdLevel(finalNumeric);

  // 5. Confidence Score Calculation
  // 1 sample: ~55%, 3 samples: ~75%, 5+ samples: ~90%+
  const sampleFactor = Math.min(1.0, dedupedEstimates.length / 5);
  const confidenceScore = Math.min(
    95.0,
    Math.round((45.0 + sampleFactor * 45.0 + (totalWeight / dedupedEstimates.length) * 5.0) * 10) / 10
  );

  const avgWaitTime = waitTimeSamples > 0 ? Math.round(waitTimeSum / waitTimeSamples) : null;

  return {
    route_id: hasRoute ? Number(routeId) : null,
    stop_id: hasStop ? Number(stopId) : null,
    routeId: hasRoute ? Number(routeId) : null,
    stopId: hasStop ? Number(stopId) : null,
    time_slot: new Date().toISOString(),
    timeSlot: new Date().toISOString(),
    aggregated_crowd_level: aggregatedLevel,
    aggregatedCrowdLevel: aggregatedLevel,
    sample_count: dedupedEstimates.length,
    sampleCount: dedupedEstimates.length,
    confidence_score: confidenceScore,
    confidenceScore: confidenceScore,
    average_wait_time_minutes: avgWaitTime,
    averageWaitTimeMinutes: avgWaitTime,
    is_baseline: false,
    isBaseline: false,
  };
}

module.exports = {
  CROWD_LEVEL_VALUES,
  resolveCrowdLevel,
  aggregateCrowdEstimates,
};
