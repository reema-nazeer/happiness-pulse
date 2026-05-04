var HOMEY_SPREADSHEET_ID = "1byV_pv5NMI8fMY4v0m74qdNDtdybXvX-KXA2e_0ra0w";

// Per-department tabs. Submissions land in the matching sheet AND in the
// master "Responses" tab so existing reports / daily emails keep working
// without any change. If the dept is missing or unknown (older clients,
// or future changes), we fall back to "Responses" only.
var DEPARTMENT_TABS = {
  "Operations": "Operations",
  "Revenue": "Revenue",
  "Service": "Service",
  "Technology": "Technology"
};

// Header row written to any auto-created dept tab.
var HAPPINESS_HEADERS = [
  "Timestamp",
  "Score",
  "Feedback",
  "Department",
  "Sub-department",
  "Version",
  "Source",
  "OS"
];

function doPost(e) {
  try {
    var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
    var payload = parseRequestPayload_(e);
    enforceWebhookAuth_(payload);
    var nowIso = new Date().toISOString();
    var type = String(payload.type || "").toLowerCase();

    if (type === "happiness") {
      var department = sanitiseDepartment_(payload.department);
      var subDepartment = String(payload.sub_department || "").trim();

      // Row format used by both the master and the per-department tab.
      var row = [
        payload.timestamp || nowIso,
        payload.score,
        payload.feedback || "",
        department,
        subDepartment,
        payload.version || "unknown",
        payload.source || "unknown",
        payload.os_version || "unknown"
      ];

      // Always write to the master Responses tab — preserves the existing
      // daily email + admin reports. Backwards-compatible with older code
      // that only knew about Responses.
      ensureSheetWithHeaders_(ss, "Responses", HAPPINESS_HEADERS);
      appendToSheet_(ss, "Responses", row);

      // Then route to the per-department tab if we recognise the dept.
      if (department && DEPARTMENT_TABS[department]) {
        ensureSheetWithHeaders_(ss, DEPARTMENT_TABS[department], HAPPINESS_HEADERS);
        appendToSheet_(ss, DEPARTMENT_TABS[department], row);
      }
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
    version: "2.1.0"
  });
}

/**
 * Whitelist department values. Anything else (null, undefined, blanks,
 * unrecognised string) returns "" so the row still lands in Responses but
 * skips the per-department routing.
 */
function sanitiseDepartment_(value) {
  if (typeof value !== "string") return "";
  var trimmed = value.trim();
  for (var name in DEPARTMENT_TABS) {
    if (DEPARTMENT_TABS.hasOwnProperty(name) && name.toLowerCase() === trimmed.toLowerCase()) {
      return name;
    }
  }
  return "";
}

/**
 * Idempotently ensure a sheet exists with the given header row. If the
 * sheet doesn't exist, create it. If it exists but its header is wrong or
 * missing, write the header. If the existing header has more columns than
 * we're writing, leave the extra columns alone (preserves any custom
 * columns the team added by hand).
 */
function ensureSheetWithHeaders_(ss, name, headers) {
  var sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    return;
  }
  // If the sheet exists but is empty, write the headers.
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
  }
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
