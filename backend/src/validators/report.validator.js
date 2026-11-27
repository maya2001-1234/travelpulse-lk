/**
 * TravelPulse LK — Community Report Request Validators
 * Module 2: Community Reporting & Transport Disruption Management (Dumindi)
 */

function validateCreateReport(req, res, next) {
  const {
    title,
    description,
    categoryId,
    latitude,
    longitude,
    disruptionReason,
    severity,
  } = req.body;

  const issues = [];

  // 1. Title validation
  if (!title || typeof title !== 'string' || title.trim().length < 5) {
    issues.push({ field: 'title', issue: 'Title is required and must be at least 5 characters long.' });
  } else if (title.trim().length > 150) {
    issues.push({ field: 'title', issue: 'Title cannot exceed 150 characters.' });
  }

  // 2. Description validation
  if (!description || typeof description !== 'string' || description.trim().length < 10) {
    issues.push({ field: 'description', issue: 'Description is required and must be at least 10 characters long.' });
  }

  // 3. Category ID validation (1: Crowd, 2: Road Condition, 3: Transport Tracking, 4: Service Disruption, 5: Accident, 6: Other)
  const catId = Number(categoryId);
  if (!catId || catId < 1 || catId > 6) {
    issues.push({ field: 'categoryId', issue: 'A valid category ID (1 to 6) is required.' });
  }

  // 4. Service Disruption Specific Rules (Category 4)
  // MUST capture specific reason. No invented severity allowed!
  if (catId === 4) {
    const reason = disruptionReason || req.body.disruption_reason;
    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
      issues.push({
        field: 'disruptionReason',
        issue: 'Service disruption reports require a specific disruption reason (e.g. Vehicle Breakdown, Signal Failure, Power Outage).',
      });
    }

    if (severity) {
      issues.push({
        field: 'severity',
        issue: 'Severity levels must not be submitted for service disruptions. Capture the specific disruption reason instead.',
      });
    }
  }

  // 5. Crowd Report Specific Rules (Category 1)
  if (catId === 1) {
    const transportType = req.body.transportType || req.body.transport_type;
    const busRouteNumber = req.body.busRouteNumber || req.body.bus_route_number;
    const destination = req.body.destination;
    const busRegistrationNumber = req.body.busRegistrationNumber || req.body.bus_registration_number;
    const trainNameOrNumber = req.body.trainNameOrNumber || req.body.train_name_or_number;
    const startingStation = req.body.startingStation || req.body.starting_station;
    const crowdLevel = req.body.crowdLevel || req.body.crowd_level;

    const validTransportTypes = ['bus', 'train'];
    if (!transportType || typeof transportType !== 'string' || !validTransportTypes.includes(transportType.trim().toLowerCase())) {
      issues.push({
        field: 'transportType',
        issue: "Transport type is required for crowd reports and must be either 'bus' or 'train'.",
      });
    } else {
      const type = transportType.trim().toLowerCase();
      if (type === 'bus') {
        if (!busRouteNumber || typeof busRouteNumber !== 'string' || busRouteNumber.trim().length === 0) {
          issues.push({
            field: 'busRouteNumber',
            issue: 'Bus route number is required for bus crowd reports.',
          });
        }
        if (!destination || typeof destination !== 'string' || destination.trim().length === 0) {
          issues.push({
            field: 'destination',
            issue: 'Destination is required for bus crowd reports.',
          });
        }
        if (busRegistrationNumber !== undefined && busRegistrationNumber !== null && typeof busRegistrationNumber !== 'string') {
          issues.push({
            field: 'busRegistrationNumber',
            issue: 'Bus registration number must be a valid string if provided.',
          });
        }
      } else if (type === 'train') {
        if (!trainNameOrNumber || typeof trainNameOrNumber !== 'string' || trainNameOrNumber.trim().length === 0) {
          issues.push({
            field: 'trainNameOrNumber',
            issue: 'Train name or number is required for train crowd reports.',
          });
        }
        if (!startingStation || typeof startingStation !== 'string' || startingStation.trim().length === 0) {
          issues.push({
            field: 'startingStation',
            issue: 'Starting station is required for train crowd reports.',
          });
        }
        if (!destination || typeof destination !== 'string' || destination.trim().length === 0) {
          issues.push({
            field: 'destination',
            issue: 'Destination is required for train crowd reports.',
          });
        }
      }
    }

    const validCrowdLevels = ['light', 'moderate', 'heavy', 'packed'];
    if (!crowdLevel || typeof crowdLevel !== 'string' || !validCrowdLevels.includes(crowdLevel.trim().toLowerCase())) {
      issues.push({
        field: 'crowdLevel',
        issue: "Crowd density level is required for crowd reports and must be one of: 'light', 'moderate', 'heavy', 'packed'.",
      });
    }
  }

  // 6. Geographic coordinates validation
  const lat = Number(latitude);
  const lng = Number(longitude);

  if (latitude === undefined || latitude === null || isNaN(lat) || lat < -90 || lat > 90) {
    issues.push({ field: 'latitude', issue: 'Valid latitude between -90.0 and 90.0 is required.' });
  }

  if (longitude === undefined || longitude === null || isNaN(lng) || lng < -180 || lng > 180) {
    issues.push({ field: 'longitude', issue: 'Valid longitude between -180.0 and 180.0 is required.' });
  }

  if (issues.length > 0) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Validation failed on the submitted report data.',
      error: {
        code: 'VALIDATION_ERROR',
        details: issues,
      },
    });
  }

  next();
}

function validateUpdateReport(req, res, next) {
  const { title, description, status } = req.body;
  const issues = [];

  if (title !== undefined && (typeof title !== 'string' || title.trim().length < 5)) {
    issues.push({ field: 'title', issue: 'Title must be at least 5 characters long.' });
  }

  if (description !== undefined && (typeof description !== 'string' || description.trim().length < 10)) {
    issues.push({ field: 'description', issue: 'Description must be at least 10 characters long.' });
  }

  const validStatuses = ['submitted', 'verified', 'disputed', 'resolved', 'rejected', 'expired'];
  if (status !== undefined && !validStatuses.includes(status)) {
    issues.push({ field: 'status', issue: `Status must be one of: ${validStatuses.join(', ')}.` });
  }

  if (issues.length > 0) {
    return res.status(400).json({
      success: false,
      statusCode: 400,
      message: 'Validation failed on the report update data.',
      error: {
        code: 'VALIDATION_ERROR',
        details: issues,
      },
    });
  }

  next();
}

module.exports = {
  validateCreateReport,
  validateUpdateReport,
};

