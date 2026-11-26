/**
 * TravelPulse LK — Community Report Repository (Module 2: Dumindi)
 * Handles database operations for report categories, community reports, and disruptions.
 */

const db = require('../config/db');
const { calculateReliability } = require('../engine/confidenceScorer');
const { findDuplicates } = require('../engine/duplicateDetector');

class ReportRepository {
  /**
   * Get all active report categories
   */
  async getCategories() {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        'SELECT id, code, name, description, default_severity AS defaultSeverity, is_active AS isActive FROM report_categories WHERE is_active = TRUE ORDER BY id ASC'
      );
      return rows;
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getCategories();
  }

  /**
   * Get category by ID
   */
  async getCategoryById(id) {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        'SELECT id, code, name, description, default_severity AS defaultSeverity, is_active AS isActive FROM report_categories WHERE id = ? LIMIT 1',
        [id]
      );
      return rows && rows.length > 0 ? rows[0] : null;
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getCategoryById(id);
  }

  /**
   * Create a new community report with transaction and reliability scoring
   */
  async createReport({
    userId,
    user,
    categoryId,
    routeId,
    stopId,
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
    mediaUrl,
    isAnonymous = false,
  }) {
    if (db.isLiveDb) {
      const connection = await db.getConnection();
      try {
        await connection.beginTransaction();

        const createdAt = new Date();

        // 1. Fetch reporter reputation
        const [repRows] = await connection.query(
          'SELECT reputation_score FROM user_reputations WHERE user_id = ?',
          [userId]
        );
        const parsedRep = repRows && repRows.length > 0 ? parseFloat(repRows[0].reputation_score) : 10.0;
        const baseReputation = Number.isFinite(parsedRep) ? parsedRep : 10.0;

        // 2. Fetch report category code for freshness decay calculation
        const [catRows] = await connection.query(
          'SELECT code FROM report_categories WHERE id = ? LIMIT 1',
          [categoryId]
        );
        const categoryCode = catRows && catRows.length > 0 && catRows[0].code ? catRows[0].code : 'OTHER';

        // 3. Fetch existing recent reports to evaluate corroboration/duplicates
        const [recentRows] = await connection.query(
          'SELECT id, user_id, category_id, stop_id, latitude, longitude, created_at FROM community_reports WHERE created_at >= DATE_SUB(NOW(), INTERVAL 2 HOUR)'
        );
        const dupResult = findDuplicates(
          {
            userId,
            categoryId: Number(categoryId),
            stopId: stopId ? Number(stopId) : null,
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
            createdAt,
          },
          recentRows.map((r) => ({
            id: r.id,
            userId: r.user_id,
            categoryId: r.category_id,
            stopId: r.stop_id,
            latitude: parseFloat(r.latitude),
            longitude: parseFloat(r.longitude),
            createdAt: r.created_at,
          }))
        );
        const corroborations = Number(dupResult && dupResult.corroborationCount ? dupResult.corroborationCount : 0);

        // 4. Compute initial reliability score using confidenceScorer parameter contract
        const reliability = calculateReliability({
          baseReputation,
          upvotes: 0,
          downvotes: 0,
          corroborations,
          createdAt,
          categoryCode,
          isModeratorVerified: false,
        });

        // Guard against any non-finite or null reliability values before SQL INSERT
        const reliabilityScore =
          reliability && Number.isFinite(Number(reliability.reliabilityScore))
            ? Number(reliability.reliabilityScore)
            : 0.0;
        const confidenceStatus =
          reliability && typeof reliability.confidenceStatus === 'string' && reliability.confidenceStatus.trim() !== ''
            ? reliability.confidenceStatus
            : 'unverified';

        // 5. Insert community report
        const [insertResult] = await connection.query(
          `INSERT INTO community_reports (
            user_id, is_anonymous, category_id, route_id, stop_id,
            latitude, longitude, location_description, title, description,
            disruption_reason, transport_type, bus_route_number, destination,
            bus_registration_number, train_name_or_number, starting_station, crowd_level,
            media_url, status, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', NOW())`,
          [
            userId,
            Boolean(isAnonymous),
            categoryId,
            routeId || null,
            stopId || null,
            latitude,
            longitude,
            locationDescription || null,
            title,
            description,
            disruptionReason || null,
            transportType || null,
            busRouteNumber || null,
            destination || null,
            busRegistrationNumber || null,
            trainNameOrNumber || null,
            startingStation || null,
            crowdLevel || null,
            mediaUrl || null,
          ]
        );
        const newReportId = insertResult.insertId;

        // 6. Insert reliability record
        await connection.query(
          `INSERT INTO report_reliability (
            report_id, reliability_score, confidence_status, upvotes_count, downvotes_count, corroboration_count, last_calculated_at
          ) VALUES (?, ?, ?, 0, 0, ?, NOW())`,
          [newReportId, reliabilityScore, confidenceStatus, corroborations]
        );

        // 7. Update user's submitted reports counter
        await connection.query(
          'UPDATE user_reputations SET total_reports_submitted = total_reports_submitted + 1 WHERE user_id = ?',
          [userId]
        );

        await connection.commit();

        return this.findReportById(newReportId, userId);
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    }

    db.assertFallbackAllowed();
    return db.memoryStore.createReport({
      userId,
      user,
      categoryId,
      routeId,
      stopId,
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
      mediaUrl,
      isAnonymous,
    });
  }

  /**
   * Find single report by ID
   */
  async findReportById(id, requestingUserId = null) {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        `SELECT r.id, r.user_id, r.is_anonymous, r.category_id, r.route_id, r.stop_id,
                r.latitude, r.longitude, r.location_description, r.title, r.description,
                r.disruption_reason, r.transport_type, r.bus_route_number, r.destination,
                r.bus_registration_number, r.train_name_or_number, r.starting_station, r.crowd_level,
                r.media_url, r.status, r.created_at, r.resolved_at,
                u.name AS user_name, u.email AS user_email,
                c.name AS category_name, c.code AS category_code,
                tr.route_number, rs.name AS stop_name,
                COALESCE(rel.reliability_score, 0) AS reliability_score,
                COALESCE(rel.confidence_status, 'unverified') AS confidence_status,
                COALESCE(rel.upvotes_count, 0) AS upvotes_count,
                COALESCE(rel.downvotes_count, 0) AS downvotes_count
         FROM community_reports r
         LEFT JOIN users u ON r.user_id = u.id
         LEFT JOIN report_categories c ON r.category_id = c.id
         LEFT JOIN transport_routes tr ON r.route_id = tr.id
         LEFT JOIN route_stops rs ON r.stop_id = rs.id
         LEFT JOIN report_reliability rel ON r.id = rel.report_id
         WHERE r.id = ?`,
        [id]
      );
      if (!rows || rows.length === 0) return null;
      return this._formatReport(rows[0], requestingUserId);
    }

    db.assertFallbackAllowed();
    return db.memoryStore.findReportById(id);
  }

  /**
   * Get filtered reports list with anonymous identity protection
   */
  async getReports({ categoryId, status, routeId, search, requestingUserId = null } = {}) {
    if (db.isLiveDb) {
      let sql = `
        SELECT r.id, r.user_id, r.is_anonymous, r.category_id, r.route_id, r.stop_id,
               r.latitude, r.longitude, r.location_description, r.title, r.description,
               r.disruption_reason, r.transport_type, r.bus_route_number, r.destination,
               r.bus_registration_number, r.train_name_or_number, r.starting_station, r.crowd_level,
               r.media_url, r.status, r.created_at, r.resolved_at,
               u.name AS user_name, u.email AS user_email,
               c.name AS category_name, c.code AS category_code,
               tr.route_number, rs.name AS stop_name,
               COALESCE(rel.reliability_score, 0) AS reliability_score,
               COALESCE(rel.confidence_status, 'unverified') AS confidence_status,
               COALESCE(rel.upvotes_count, 0) AS upvotes_count,
               COALESCE(rel.downvotes_count, 0) AS downvotes_count
        FROM community_reports r
        LEFT JOIN users u ON r.user_id = u.id
        LEFT JOIN report_categories c ON r.category_id = c.id
        LEFT JOIN transport_routes tr ON r.route_id = tr.id
        LEFT JOIN route_stops rs ON r.stop_id = rs.id
        LEFT JOIN report_reliability rel ON r.id = rel.report_id
        WHERE 1=1
      `;
      const params = [];

      if (categoryId) {
        sql += ' AND r.category_id = ?';
        params.push(categoryId);
      }
      if (status) {
        sql += ' AND r.status = ?';
        params.push(status);
      }
      if (routeId) {
        sql += ' AND r.route_id = ?';
        params.push(routeId);
      }
      if (search) {
        sql += ' AND (r.title LIKE ? OR r.description LIKE ?)';
        params.push(`%${search}%`, `%${search}%`);
      }

      sql += ' ORDER BY r.created_at DESC';

      const [rows] = await db.query(sql, params);
      return rows.map((r) => this._formatReport(r, requestingUserId));
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getReports({ categoryId, status, routeId, search });
  }

  /**
   * Get reports authored by the requesting user
   */
  async getMyReports(userId) {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        `SELECT r.id, r.user_id, r.is_anonymous, r.category_id, r.route_id, r.stop_id,
                r.latitude, r.longitude, r.location_description, r.title, r.description,
                r.disruption_reason, r.transport_type, r.bus_route_number, r.destination,
                r.bus_registration_number, r.train_name_or_number, r.starting_station, r.crowd_level,
                r.media_url, r.status, r.created_at, r.resolved_at,
                u.name AS user_name, u.email AS user_email,
                c.name AS category_name, c.code AS category_code,
                tr.route_number, rs.name AS stop_name,
                COALESCE(rel.reliability_score, 0) AS reliability_score,
                COALESCE(rel.confidence_status, 'unverified') AS confidence_status,
                COALESCE(rel.upvotes_count, 0) AS upvotes_count,
                COALESCE(rel.downvotes_count, 0) AS downvotes_count
         FROM community_reports r
         LEFT JOIN users u ON r.user_id = u.id
         LEFT JOIN report_categories c ON r.category_id = c.id
         LEFT JOIN transport_routes tr ON r.route_id = tr.id
         LEFT JOIN route_stops rs ON r.stop_id = rs.id
         LEFT JOIN report_reliability rel ON r.id = rel.report_id
         WHERE r.user_id = ?
         ORDER BY r.created_at DESC`,
        [userId]
      );
      // Passing requestingUserId == userId ensures author unmasking
      return rows.map((r) => this._formatReport(r, userId));
    }

    db.assertFallbackAllowed();
    return db.memoryStore.getMyReports(userId);
  }

  /**
   * Update report fields (title, description, status, location_description)
   */
  async updateReport(id, updates = {}) {
    if (db.isLiveDb) {
      const setClauses = [];
      const params = [];

      if (updates.title) {
        setClauses.push('title = ?');
        params.push(updates.title);
      }
      if (updates.description) {
        setClauses.push('description = ?');
        params.push(updates.description);
      }
      if (updates.location_description !== undefined || updates.locationDescription !== undefined) {
        setClauses.push('location_description = ?');
        params.push(updates.location_description !== undefined ? updates.location_description : updates.locationDescription);
      }
      if (updates.status) {
        setClauses.push('status = ?');
        params.push(updates.status);
        if (updates.status === 'resolved') {
          setClauses.push('resolved_at = NOW()');
        }
      }

      if (setClauses.length > 0) {
        params.push(id);
        await db.query(`UPDATE community_reports SET ${setClauses.join(', ')} WHERE id = ?`, params);
      }

      return this.findReportById(id);
    }

    db.assertFallbackAllowed();
    return db.memoryStore.updateReport(id, updates);
  }

  /**
   * Update report status (e.g. 'verified', 'resolved')
   */
  async updateReportStatus(id, status) {
    return this.updateReport(id, { status });
  }

  /**
   * Delete report with ownership or moderator privilege check
   */
  async deleteReport(id, requestingUserId, isModerator = false) {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        'SELECT id, user_id FROM community_reports WHERE id = ?',
        [id]
      );
      if (!rows || rows.length === 0) {
        return { error: 'REPORT_NOT_FOUND', statusCode: 404 };
      }

      const report = rows[0];
      if (!isModerator && Number(report.user_id) !== Number(requestingUserId)) {
        return { error: 'FORBIDDEN', statusCode: 403 };
      }

      // Foreign key CASCADE deletes report_votes, report_reliability
      await db.query('DELETE FROM community_reports WHERE id = ?', [id]);
      return { success: true };
    }

    db.assertFallbackAllowed();
    return db.memoryStore.deleteReport(id, requestingUserId, isModerator);
  }

  /**
   * Get verified disruptions for mobile app consumption
   */
  async getDisruptions() {
    if (db.isLiveDb) {
      const [rows] = await db.query(
        `SELECT r.id, r.id AS report_id, r.route_id, tr.route_number,
                r.title, r.description, r.disruption_reason,
                r.latitude, r.longitude, r.location_description,
                r.status, r.created_at, 'critical' AS severity
         FROM community_reports r
         LEFT JOIN transport_routes tr ON r.route_id = tr.id
         WHERE r.category_id = 4 AND r.status IN ('verified', 'submitted')
         ORDER BY r.created_at DESC`
      );
      return rows;
    }

    db.assertFallbackAllowed();
    const reports = db.memoryStore.reports.filter(
      (r) => Number(r.category_id) === 4 && (r.status === 'verified' || r.status === 'submitted')
    );
    return reports.map((r) => ({
      id: r.id,
      report_id: r.id,
      route_id: r.route_id,
      route_number: r.route_number,
      title: r.title,
      description: r.description,
      disruption_reason: r.disruption_reason,
      latitude: r.latitude,
      longitude: r.longitude,
      location_description: r.location_description,
      status: r.status,
      created_at: r.created_at,
      severity: 'critical',
    }));
  }

  /**
   * Helper: format report and enforce anonymous masking rules
   */
  _formatReport(row, requestingUserId = null) {
    const isAnonymous = Boolean(row.is_anonymous);
    const isAuthor = requestingUserId && Number(row.user_id) === Number(requestingUserId);

    return {
      id: row.id,
      userId: isAnonymous && !isAuthor ? null : row.user_id,
      userName: isAnonymous && !isAuthor ? 'Anonymous Commuter' : row.user_name || 'Commuter',
      userEmail: isAnonymous && !isAuthor ? null : row.user_email || null,
      isAnonymous,
      categoryId: row.category_id,
      categoryName: row.category_name,
      categoryCode: row.category_code,
      routeId: row.route_id,
      routeNumber: row.route_number,
      stopId: row.stop_id,
      stopName: row.stop_name,
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
      locationDescription: row.location_description,
      title: row.title,
      description: row.description,
      disruptionReason: row.disruption_reason,
      transportType: row.transport_type || null,
      busRouteNumber: row.bus_route_number || null,
      destination: row.destination || null,
      busRegistrationNumber: row.bus_registration_number || null,
      trainNameOrNumber: row.train_name_or_number || null,
      startingStation: row.starting_station || null,
      crowdLevel: row.crowd_level || null,
      mediaUrl: row.media_url,
      status: row.status,
      reliabilityScore: parseFloat(row.reliability_score || 0),
      confidenceStatus: row.confidence_status || 'unverified',
      upvotesCount: Number(row.upvotes_count || 0),
      downvotesCount: Number(row.downvotes_count || 0),
      createdAt: row.created_at,
      resolvedAt: row.resolved_at,
    };
  }
}

module.exports = new ReportRepository();

