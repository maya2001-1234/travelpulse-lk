/**
 * TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine
 * Sub-Engine: Freshness Decay Calculator (Suneth)
 * ---------------------------------------------------------------------------
 * Calculates time-decay weights for transit observations and community reports.
 * Crowd observations decay quickly (half-life ~20 mins, expired at 60 mins).
 * Physical disruptions and road conditions persist longer with gradual decay.


const CROWD_EXPIRATION_MINUTES = 60;
const INCIDENT_EXPIRATION_MINUTES = 24 * 60; // 24 hours

/**
 * Returns elapsed minutes between given timestamp and now
 */
function getTimeElapsedMinutes(timestamp) {
  if (!timestamp) return Infinity;
  const time = new Date(timestamp).getTime();
  if (isNaN(time)) return Infinity;
  const now = Date.now();
  const diffMs = Math.max(0, now - time);
  return diffMs / (1000 * 60);
}

/**
 * Calculates a freshness multiplier between 0.0 (expired) and 1.0 (brand new)
 * @param {string|Date} timestamp - The time the report/estimate was recorded
 * @param {string} categoryCode - Category type ('CROWD', 'ROAD_CONDITION', etc.)
 * @returns {number} Float between 0.0 and 1.0
 */
function calculateFreshnessWeight(timestamp, categoryCode = 'CROWD') {
  const elapsedMinutes = getTimeElapsedMinutes(timestamp);

  const isCrowd = categoryCode.toUpperCase() === 'CROWD';

  if (isCrowd) {
    if (elapsedMinutes <= 15) {
      return 1.0; // 100% fresh
    } else if (elapsedMinutes <= 30) {
      // Linear decay from 1.0 to 0.70
      return 1.0 - ((elapsedMinutes - 15) / 15) * 0.30;
    } else if (elapsedMinutes <= 45) {
      // Linear decay from 0.70 to 0.40
      return 0.70 - ((elapsedMinutes - 30) / 15) * 0.30;
    } else if (elapsedMinutes <= CROWD_EXPIRATION_MINUTES) {
      // Linear decay from 0.40 to 0.05
      return 0.40 - ((elapsedMinutes - 45) / 15) * 0.35;
    } else {
      return 0.0; // Expired
    }
  } else {
    // Road hazards, service disruptions, accident incidents
    if (elapsedMinutes <= 30) {
      return 1.0;
    } else if (elapsedMinutes <= 120) { // 2 hours
      return 0.90 - ((elapsedMinutes - 30) / 90) * 0.20; // 0.90 -> 0.70
    } else if (elapsedMinutes <= 360) { // 6 hours
      return 0.70 - ((elapsedMinutes - 120) / 240) * 0.30; // 0.70 -> 0.40
    } else if (elapsedMinutes <= INCIDENT_EXPIRATION_MINUTES) { // 24 hours
      return 0.40 - ((elapsedMinutes - 360) / (INCIDENT_EXPIRATION_MINUTES - 360)) * 0.35;
    } else {
      return 0.05; // Lingering historical context until archived
    }
  }
}

/**
 * Checks whether an observation is deemed expired for active real-time aggregation
 */
function isExpired(timestamp, categoryCode = 'CROWD') {
  const elapsedMinutes = getTimeElapsedMinutes(timestamp);
  const maxMinutes = categoryCode.toUpperCase() === 'CROWD' ? CROWD_EXPIRATION_MINUTES : INCIDENT_EXPIRATION_MINUTES;
  return elapsedMinutes > maxMinutes;
}

module.exports = {
  getTimeElapsedMinutes,
  calculateFreshnessWeight,
  isExpired,
  CROWD_EXPIRATION_MINUTES,
  INCIDENT_EXPIRATION_MINUTES,
};