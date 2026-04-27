var HOMEY_SPREADSHEET_ID = "1byV_pv5NMI8fMY4v0m74qdNDtdybXvX-KXA2e_0ra0w";

// Column layout for the Responses sheet — kept here so Daily/Weekly emails
// and the admin dashboard read from the same canonical positions.
// The Department column was added in v2; ensureResponsesSchema_() backfills
// the header on the live sheet if it isn't there yet.
var RESPONSES_HEADERS = [
  "Timestamp",
  "Score",
  "Feedback",
  "Version",
  "Source",
  "OS",
  "Department"
];
var DEPARTMENT_COL_INDEX = 7; // 1-based, used by Daily/Weekly readers

function doPost(e) {
  try {
    var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
    var payload = parseRequestPayload_(e);
    enforceWebhookAuth_(payload);
    var nowIso = new Date().toISOString();
    var type = String(payload.type || "").toLowerCase();

    if (type === "happiness") {
      ensureResponsesSchema_(ss);
      // Older clients (pre-v2) won't send `department`. Accept the row anyway
      // and write an empty string — never error on missing department.
      var department = sanitiseDepartment_(payload.department);
      appendToSheet_(ss, "Responses", [
        payload.timestamp || nowIso,
        payload.score,
        payload.feedback || "",
        payload.version || "unknown",
        payload.source || "unknown",
        payload.os_version || "unknown",
        department
      ]);
    } else if (type === "registration") {
      appendToSheet_(ss, "Registrations", [
        payload.timestamp || nowIso,
        payload.name || "unknown",
        payload.version || "unknown",
        payload.arch || "unknown",
        payload.os || "unknown"
      ]);
    } else if (type === "install" || type === "update" || type === "uninstall") {
      appendToSheet_(ss, "Installs", [
        payload.timestamp || nowIso,
        payload.username || "unknown",
        payload.source || type,
        payload.arch || "unknown",
        payload.os || "unknown"
      ]);
    } else {
      return jsonResponse_({
        status: "ignored",
        message: "Unsupported payload type"
      });
    }

    return jsonResponse_({ status: "ok" });
  } catch (err) {
    return jsonResponse_({
      status: "error",
      message: err && err.toString ? err.toString() : "Unknown error"
    });
  }
}

function doGet() {
  return jsonResponse_({
    status: "running",
    version: "2.0"
  });
}

/**
 * Whitelist of acceptable department values. Anything else (including null,
 * undefined, blanks, or typos) gets stored as empty so it folds into the
 * "no department" bucket in reports.
 */
function sanitiseDepartment_(value) {
  var allowed = ["Operations", "Revenue", "Service", "Technology"];
  if (typeof value !== "string") return "";
  var trimmed = value.trim();
  for (var i = 0; i < allowed.length; i++) {
    if (allowed[i].toLowerCase() === trimmed.toLowerCase()) {
      return allowed[i];
    }
  }
  return "";
}

/**
 * Idempotent: ensures the Responses sheet header row matches RESPONSES_HEADERS.
 * If the Department column is missing (sheet existed before v2), it appends
 * the header so future reads find it. Old rows simply have a blank in the new
 * column, which the Daily/Weekly readers treat as "no department".
 */
function ensureResponsesSchema_(ss) {
  var sheet = ss.getSheetByName("Responses");
  if (!sheet) throw new Error('Missing sheet: "Responses"');
  var lastCol = sheet.getLastColumn();
  if (lastCol >= RESPONSES_HEADERS.length) return; // already up-to-date
  var headerRange = sheet.getRange(1, 1, 1, RESPONSES_HEADERS.length);
  var existingHeader = lastCol > 0
    ? sheet.getRange(1, 1, 1, lastCol).getValues()[0]
    : [];
  var nextHeader = RESPONSES_HEADERS.slice();
  // Preserve any custom header text that was already in earlier columns —
  // only overwrite cells where there's nothing there yet.
  for (var i = 0; i < existingHeader.length; i++) {
    if (existingHeader[i]) nextHeader[i] = existingHeader[i];
  }
  headerRange.setValues([nextHeader]);
}

function enforceWebhookAuth_(payload) {
  var configuredSecret = PropertiesService.getScriptProperties().getProperty("WEBHOOK_SHARED_SECRET");
  if (!configuredSecret) {
    return;
  }
  var provided = payload && payload.secret ? String(payload.secret) : "";
  if (provided !== configuredSecret) {
    throw new Error("Unauthorized webhook request");
  }
}

function parseRequestPayload_(e) {
  if (!e || !e.postData || !e.postData.contents) {
    throw new Error("Missing post data");
  }
  return JSON.parse(e.postData.contents);
}

function appendToSheet_(ss, sheetName, values) {
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    throw new Error("Missing sheet: " + sheetName);
  }
  sheet.appendRow(values);
}

function jsonResponse_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
