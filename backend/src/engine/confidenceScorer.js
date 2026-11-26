/**
 * TravelPulse LK — Module 3: Crowd Intelligence & Report Reliability Engine
 * Sub-Engine: Confidence & Reliability Scorer (Suneth)
 * ---------------------------------------------------------------------------
 * Computes algorithmic trust score (0.00 - 100.00) and confidence status:
 *   - 'unverified': Initial state, insufficient peer corroboration
 *   - 'plausible': Emerging consensus from community votes or reports
 *   - 'verified': High-confidence report backed by high reputation & votes
 *   - 'disputed': Active disagreement or high downvote proportion
 *   - 'rejected': Marked false or heavily contradicted
 */

const { calculateFreshnessWeight } = require('./freshnessEngine');

/**
 * Calculates reliability score and status for a report
 */
function calculateReliability({
  baseReputation = 10.0,
  upvotes = 0,
  downvotes = 0,
  corroborations = 0,
  createdAt = new Date(),
  categoryCode = 'OTHER',
  isModeratorVerified = false,
}) {
  if (isModeratorVerified) {
    return {
      reliabilityScore: 98.0,
      confidenceStatus: 'verified',
      freshnessWeight: 1.0,
      breakdown: {
        baseReputationContribution: 40.0,
        peerVoteScore: 40.0,
        corroborationScore: 20.0,
        moderatorOverride: true,
      },
    };
  }

  // 1. Base reputation contribution (Max 40 points)
  const rep = Math.min(100, Math.max(0, Number(baseReputation) || 10.0));
  const baseReputationContribution = Math.round((rep * 0.40) * 10) / 10;

  // 2. Peer votes component
  // Each upvote adds 6 points (capped at 55)
  // Each downvote subtracts 10 points
  const upvotePoints = Math.min(55, (Number(upvotes) || 0) * 6.0);
  const downvotePenalty = (Number(downvotes) || 0) * 10.0;
  const peerVoteScore = Math.max(-30, upvotePoints - downvotePenalty);

  // 3. Independent spatio-temporal corroboration (Max 25 points)
  const corroborationScore = Math.min(25, (Number(corroborations) || 0) * 10.0);

  // 4. Combined raw score (0 - 100)
  let rawScore = baseReputationContribution + peerVoteScore + corroborationScore;
  rawScore = Math.max(0, Math.min(100, rawScore));

  // 5. Freshness factor
  const freshness = calculateFreshnessWeight(createdAt, categoryCode);

  // Time decay applies gently to reliability score (floor 0.70 for verified credibility retention)
  const effectiveFreshnessMultiplier = 0.70 + (freshness * 0.30);
  const finalScore = Math.round(rawScore * effectiveFreshnessMultiplier * 10) / 10;

  // 6. Determine confidence status
  let confidenceStatus = 'unverified';

  if (downvotes >= 3 && downvotes > upvotes) {
    confidenceStatus = 'disputed';
  } else if (downvotes >= 5 && downvotes > upvotes * 2) {
    confidenceStatus = 'rejected';
  } else if (finalScore >= 70.0 && upvotes >= 2) {
    confidenceStatus = 'verified';
  } else if (finalScore >= 35.0 || (upvotes >= 1 && downvotes === 0)) {
    confidenceStatus = 'plausible';
  } else {
    confidenceStatus = 'unverified';
  }

  return {
    reliabilityScore: finalScore,
    confidenceStatus,
    freshnessWeight: Math.round(freshness * 100) / 100,
    breakdown: {
      baseReputationContribution,
      peerVoteScore,
      corroborationScore,
      rawScore,
      freshness,
    },
  };
}

module.exports = {
  calculateReliability,
};

