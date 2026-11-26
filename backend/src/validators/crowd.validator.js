/**
 * TravelPulse LK — Crowd Intelligence Input Validators
 * Module 3: Crowd Intelligence & Report Reliability Engine (Suneth)
 */

const ALLOWED_CROWD_LEVELS = ['empty', 'moderate', 'crowded', 'very_crowded'];
const ALLOWED_VOTE_TYPES = ['upvote', 'downvote', 'confirm_resolved'];

function validateCrowdEstimate(req, res, next) {
  const { routeId, stopId, crowdLevel, passengerWaitTimeMinutes } = req.body;
  const errors = [];

  const hasRoute = routeId !== undefined && routeId !== null && routeId !== '';
  const hasStop = stopId !== undefined && stopId !== null && stopId !== '';

  if ((hasRoute && hasStop) || (!hasRoute && !hasStop)) {
    errors.push({
      field: 'target',
      message: 'Crowd estimate must specify EXACTLY ONE of routeId or stopId (chk_crowd_agg_target).',
    });
  }

  if (hasRoute && isNaN(Number(routeId))) {
    errors.push({ field: 'routeId', message: 'routeId must be a valid number.' });
  }

  if (hasStop && isNaN(Number(stopId))) {
    errors.push({ field: 'stopId', message: 'stopId must be a valid number.' });
  }

  if (!crowdLevel || !ALLOWED_CROWD_LEVELS.includes(String(crowdLevel).toLowerCase())) {
    errors.push({
      field: 'crowdLevel',
      message: `crowdLevel must be one of: ${ALLOWED_CROWD_LEVELS.join(', ')}.`,
    });
  }

  if (passengerWaitTimeMinutes !== undefined && passengerWaitTimeMinutes !== null) {
    const mins = Number(passengerWaitTimeMinutes);
    if (isNaN(mins) || mins < 0 || mins > 300) {
      errors.push({
        field: 'passengerWaitTimeMinutes',
        message: 'passengerWaitTimeMinutes must be an integer between 0 and 300.',
      });
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Validation failed for crowd estimate.',
      error: {
        code: 'VALIDATION_ERROR',
        details: errors,
      },
    });
  }

  next();
}

function validateReportVote(req, res, next) {
  const { voteType } = req.body;
  const errors = [];

  if (!voteType || !ALLOWED_VOTE_TYPES.includes(String(voteType).toLowerCase())) {
    errors.push({
      field: 'voteType',
      message: `voteType must be one of: ${ALLOWED_VOTE_TYPES.join(', ')}.`,
    });
  }

  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Validation failed for report vote.',
      error: {
        code: 'VALIDATION_ERROR',
        details: errors,
      },
    });
  }

  next();
}

module.exports = {
  validateCrowdEstimate,
  validateReportVote,
  ALLOWED_CROWD_LEVELS,
  ALLOWED_VOTE_TYPES,
};

