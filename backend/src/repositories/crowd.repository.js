/**
 * TravelPulse LK — Crowd & Reliability Repository (Module 3: Suneth)
 * Handles database operations for crowd estimates, sliding-window aggregations,
 * report peer voting, and user reputation metrics.
 */

const db = require('../config/db');
const { calculateReliability } = require('../engine/confidenceScorer');
const { aggregateCrowdEstimates } = require('../engine/crowdEngine');

class CrowdRepository {
  /**
   * Submit crowd density estimate and update sliding-window aggregation within a transaction
   */
  async submitCrowdEstimate({ userId, routeId, stopId, crowdLevel, passengerWaitTimeMinutes }) {
    if (db.isLiveDb) {
      const connection = await db.getConnection();
      try {
        await connection.beginTransaction();

        // 1. Insert estimate into crowd_estimates
        const [insertResult] = await connection.query(
          `INSERT INTO crowd_estimates (user_id, route_id, stop_id, crowd_level, passenger_wait_time_minutes, reported_at)
           VALUES (?, ?, ?, ?, ?, NOW())`,
          [
            userId,
            routeId || null,
            stopId || null,
            crowdLevel,
            passengerWaitTimeMinutes !== undefined ? passengerWaitTimeMinutes : null,
          ]
        );
        const newEstimateId = insertResult.insertId;

        // 2. Query recent estimates within sliding window (past 60 minutes)
        let recentSql = 'SELECT * FROM crowd_estimates WHERE reported_at >= DATE_SUB(NOW(), INTERVAL 60 MINUTE)';
        const recentParams = [];
        if (routeId) {
          recentSql += ' AND route_id = ?';
          recentParams.push(routeId);
        } else if (stopId) {
          recentSql += ' AND stop_id = ?';
          recentParams.push(stopId);
        }

        const [recentEstimates] = await connection.query(recentSql, recentParams);

        // 3. Compute sliding-window aggregation using crowdEngine
        const engineEstimates = recentEstimates.map((e) => ({
          userId: e.user_id,
          routeId: e.route_id,
          stopId: e.stop_id,
          crowdLevel: e.crowd_level,
          passengerWaitTimeMinutes: e.passenger_wait_time_minutes,
          reportedAt: e.reported_at,
        }));
        const aggResult = aggregateCrowdEstimates({
          routeId: routeId || null,
          stopId: stopId || null,
          estimates: engineEstimates,
        });

        // 4. Upsert into crowd_aggregations respecting chk_crowd_agg_target
        // Check if an existing aggregation row exists for this target
        let findAggSql = 'SELECT id FROM crowd_aggregations WHERE ';
        const findAggParams = [];
        if (routeId) {
          findAggSql += 'route_id = ? AND stop_id IS NULL';
          findAggParams.push(routeId);
        } else {
          findAggSql += 'stop_id = ? AND route_id IS NULL';
          findAggParams.push(stopId);
        }

        const [existingAgg] = await connection.query(findAggSql, findAggParams);

        let aggregationRow = null;
        if (existingAgg && existingAgg.length > 0) {
          await connection.query(
            `UPDATE crowd_aggregations
             SET aggregated_crowd_level = ?, sample_count = ?, confidence_score = ?, time_slot = NOW(), last_updated_at = NOW()
             WHERE id = ?`,
            [aggResult.crowdLevel, aggResult.sampleCount, aggResult.confidenceScore, existingAgg[0].id]
          );
          aggregationRow = {
            id: existingAgg[0].id,
            routeId: routeId || null,
            stopId: stopId || null,
            timeSlot: new Date().toISOString(),
            aggregatedCrowdLevel: aggResult.crowdLevel,
            sampleCount: aggResult.sampleCount,
            confidenceScore: aggResult.confidenceScore,
          };
        } else {
          const [insertAgg] = await connection.query(
            `INSERT INTO crowd_aggregations (route_id, stop_id, time_slot, aggregated_crowd_level, sample_count, confidence_score)
             VALUES (?, ?, NOW(), ?, ?, ?)`,
            [routeId || null, stopId || null, aggResult.crowdLevel, aggResult.sampleCount, aggResult.confidenceScore]
          );
          aggregationRow = {
            id: insertAgg.insertId,
            routeId: routeId || null,
            stopId: stopId || null,
            timeSlot: new Date().toISOString(),
            aggregatedCrowdLevel: aggResult.crowdLevel,
            sampleCount: aggResult.sampleCount,
            confidenceScore: aggResult.confidenceScore,
          };
        }

        await connection.commit();

        return {
          estimate: {
            id: newEstimateId,
            userId,
            routeId: routeId || null,
            stopId: stopId || null,
            crowdLevel,
            passengerWaitTimeMinutes,
            reportedAt: new Date().toISOString(),
          },
          aggregation: aggregationRow,
        };
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    }

    db.assertFallbackAllowed();
    return db.memoryStore.submitCrowdEstimate({ userId, routeId, stopId, crowdLevel, passengerWaitTimeMinutes });
  }

  /**
   * Get crowd estimates for a target route or stop
   */
  async getCrowdEstimates(routeId, stopId) {
    if (db.isLiveDb) {
      let sql = 'SELECT * FROM crowd_estimates WHERE 1=1';
      const params = [];
      if (routeId) {
        sql += ' AND route_id = ?';
        params.push(routeId);
      }
      if (stopId) {
        sql += ' AND stop_id = ?';
        params.push(stopId);
      }
      sql += ' ORDER BY reported_at DESC LIMIT 50';

      const [rows] = await db.query(sql, params);
      return rows.map((r) => ({
        id: r.id,
        userId: r.user_id,
        routeId: r.route_id,
        stopId: r.stop_id,
        crowdLevel: r.crowd_level,
        passengerWaitTimeMinutes: r.passenger_wait_time_minutes,
        reportedAt: r.reported_at,
      }));
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getCrowdEstimates(routeId, stopId);
  }

  /**
   * Get active crowd aggregation for route or stop
   */
  async getCrowdAggregation(routeId, stopId) {
    if (db.isLiveDb) {
      let sql = 'SELECT * FROM crowd_aggregations WHERE ';
      const params = [];
      if (routeId) {
        sql += 'route_id = ? AND stop_id IS NULL';
        params.push(routeId);
      } else {
        sql += 'stop_id = ? AND route_id IS NULL';
        params.push(stopId);
      }
      sql += ' ORDER BY last_updated_at DESC LIMIT 1';

      const [rows] = await db.query(sql, params);
      if (!rows || rows.length === 0) return null;
      const r = rows[0];
      return {
        id: r.id,
        routeId: r.route_id,
        stopId: r.stop_id,
        timeSlot: r.time_slot,
        aggregatedCrowdLevel: r.aggregated_crowd_level,
        sampleCount: r.sample_count,
        confidenceScore: parseFloat(r.confidence_score),
        lastUpdatedAt: r.last_updated_at,
      };
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getCrowdAggregation(routeId, stopId);
  }

  /**
   * Peer vote on community report with transactional recalculation of reliability score
   */
  async voteOnReport(reportId, userId, voteType) {
    if (db.isLiveDb) {
      const connection = await db.getConnection();
      try {
        await connection.beginTransaction();

        // 1. Fetch report details
        const [reportRows] = await connection.query(
          `SELECT r.*, rel.reliability_score, rel.confidence_status, rel.corroboration_count
           FROM community_reports r
           LEFT JOIN report_reliability rel ON r.id = rel.report_id
           WHERE r.id = ?`,
          [reportId]
        );
        if (!reportRows || reportRows.length === 0) {
          await connection.rollback();
          return { error: 'REPORT_NOT_FOUND', statusCode: 404 };
        }
        const report = reportRows[0];

        // 2. Prevent self-voting
        if (Number(report.user_id) === Number(userId)) {
          await connection.rollback();
          return { error: 'SELF_VOTING_FORBIDDEN', message: 'You cannot vote on your own report.', statusCode: 400 };
        }

        // 3. Upsert into report_votes
        await connection.query(
          `INSERT INTO report_votes (report_id, user_id, vote_type, created_at)
           VALUES (?, ?, ?, NOW())
           ON DUPLICATE KEY UPDATE vote_type = VALUES(vote_type), created_at = NOW()`,
          [reportId, userId, voteType]
        );

        // 4. Recount upvotes and downvotes
        const [voteCounts] = await connection.query(
          `SELECT
             SUM(CASE WHEN vote_type = 'upvote' THEN 1 ELSE 0 END) AS upvotes,
             SUM(CASE WHEN vote_type = 'downvote' THEN 1 ELSE 0 END) AS downvotes
           FROM report_votes
           WHERE report_id = ?`,
          [reportId]
        );
        const upvotes = Number(voteCounts[0].upvotes || 0);
        const downvotes = Number(voteCounts[0].downvotes || 0);

        // 5. Fetch reporter reputation
        const [repRows] = await connection.query(
          'SELECT reputation_score FROM user_reputations WHERE user_id = ?',
          [report.user_id]
        );
        const reporterRep = repRows && repRows.length > 0 ? parseFloat(repRows[0].reputation_score) : 10.0;

        // 6. Recalculate reliability score
        const newScore = calculateReliability({
          upvotes,
          downvotes,
          reporterReputation: reporterRep,
          corroboratingReportsCount: report.corroboration_count || 0,
          isAnonymous: Boolean(report.is_anonymous),
          mediaUrl: report.media_url,
        });

        // 7. Update report_reliability
        await connection.query(
          `UPDATE report_reliability
           SET reliability_score = ?, confidence_status = ?, upvotes_count = ?, downvotes_count = ?, last_calculated_at = NOW()
           WHERE report_id = ?`,
          [newScore.score, newScore.status, upvotes, downvotes, reportId]
        );

        // 8. If verified score reached, elevate community_reports status
        if (newScore.status === 'verified' && report.status === 'submitted') {
          await connection.query(
            "UPDATE community_reports SET status = 'verified' WHERE id = ?",
            [reportId]
          );
        }

        // 9. Increment voter's total_votes_cast
        await connection.query(
          'UPDATE user_reputations SET total_votes_cast = total_votes_cast + 1 WHERE user_id = ?',
          [userId]
        );

        await connection.commit();

        // 10. Return complete updated report object matching contract
        const [fullUpdated] = await db.query(
          `SELECT r.id, r.user_id, r.is_anonymous, r.category_id, r.route_id, r.stop_id,
                  r.latitude, r.longitude, r.location_description, r.title, r.description,
                  r.disruption_reason, r.media_url, r.status, r.created_at, r.resolved_at,
                  u.name AS user_name, u.email AS user_email,
                  c.name AS category_name, c.code AS category_code,
                  tr.route_number, rs.name AS stop_name,
                  rel.reliability_score, rel.confidence_status, rel.upvotes_count, rel.downvotes_count
           FROM community_reports r
           LEFT JOIN users u ON r.user_id = u.id
           LEFT JOIN report_categories c ON r.category_id = c.id
           LEFT JOIN transport_routes tr ON r.route_id = tr.id
           LEFT JOIN route_stops rs ON r.stop_id = rs.id
           LEFT JOIN report_reliability rel ON r.id = rel.report_id
           WHERE r.id = ?`,
          [reportId]
        );

        const r = fullUpdated[0];
        return {
          id: r.id,
          userId: r.is_anonymous ? null : r.user_id,
          userName: r.is_anonymous ? 'Anonymous Commuter' : r.user_name || 'Commuter',
          userEmail: r.is_anonymous ? null : r.user_email,
          isAnonymous: Boolean(r.is_anonymous),
          categoryId: r.category_id,
          categoryName: r.category_name,
          categoryCode: r.category_code,
          routeId: r.route_id,
          routeNumber: r.route_number,
          stopId: r.stop_id,
          stopName: r.stop_name,
          latitude: parseFloat(r.latitude),
          longitude: parseFloat(r.longitude),
          locationDescription: r.location_description,
          title: r.title,
          description: r.description,
          disruptionReason: r.disruption_reason,
          mediaUrl: r.media_url,
          status: r.status,
          reliabilityScore: parseFloat(r.reliability_score || 0),
          confidenceStatus: r.confidence_status || 'unverified',
          upvotesCount: Number(r.upvotes_count || 0),
          downvotesCount: Number(r.downvotes_count || 0),
          createdAt: r.created_at,
          resolvedAt: r.resolved_at,
        };
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    }

    db.assertFallbackAllowed();
    return db.memoryStore.voteOnReport(reportId, userId, voteType);
  }

  /**
   * Get user reputation
   */
  async getUserReputation(userId) {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        'SELECT user_id, reputation_score, total_reports_submitted, verified_reports_count, rejected_reports_count, total_votes_cast, updated_at FROM user_reputations WHERE user_id = ?',
        [userId]
      );
      if (rows && rows.length > 0) return rows[0];
      return {
        user_id: Number(userId),
        reputation_score: 10.0,
        total_reports_submitted: 0,
        verified_reports_count: 0,
        rejected_reports_count: 0,
        total_votes_cast: 0,
      };
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getUserReputation(userId);
  }
}

module.exports = new CrowdRepository();

