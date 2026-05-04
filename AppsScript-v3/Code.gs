// Homey Happiness Pulse — v3 webhook handler.
//
// Deploy this as a SEPARATE Apps Script project from the v2 webhook so the
// two systems run in parallel during rollout. Steps:
//
//   1. Create a new Google Sheet (any name; the Sheet ID goes into Script
//      Properties below).
//   2. Open script.google.com → New project. Paste this file as Code.gs.
//      (Optional: paste DailyEmail.gs alongside.)
//   3. Project Settings → Script Properties → add:
//          HOMEY_SPREADSHEET_ID_V3 = <the new sheet's ID>
//      (and optionally WEBHOOK_SHARED_SECRET if you want to enforce one).
//   4. Deploy → New deployment → Type: Web app
//          Execute as: Me
//          Who has access: Anyone
//      Copy the resulting "Web app URL" — that goes into the four
//      install-*.sh scripts in place of `__WEBHOOK_URL__`.
//
// Routing:
//   - Each happiness submission lands in TWO tabs:
//       a) "Responses" master tab (everyone, mixed)
//       b) The matching department tab (Operations / Revenue / Service /
//          Technology)
//   - "install" / "registration" submissions land in their own tabs.
//   - Tabs are auto-created on first write so the spreadsheet doesn't need
//     manual setup.

function _spreadsheetId_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty("HOMEY_SPREADSHEET_ID_V3");
  if (!id) {
    throw new Error(
      "HOMEY_SPREADSHEET_ID_V3 is not set. Open Project Settings → Script " +
      "Properties and add it."
    );
  }
  return id;
}

var DEPARTMENT_TABS = {
  "Operations": "Operations",
  "Revenue": "Revenue",
  "Service": "Service",
  "Technology": "Technology"
};

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

var INSTALL_HEADERS = [
  "Timestamp",
  "Username",
  "Source",
  "Department",
  "Arch",
  "OS"
];

var REGISTRATION_HEADERS = [
  "Timestamp",
  "Name",
  "Version",
  "Arch",
  "OS"
];

function doPost(e) {
  try {
    var ss = SpreadsheetApp.openById(_spreadsheetId_());
    var payload = parseRequestPayload_(e);
    enforceWebhookAuth_(payload);
    var nowIso = new Date().toISOString();
    var type = String(payload.type || "").toLowerCase();

    if (type === "happiness") {
      var department = sanitiseDepartment_(payload.department);
      var subDepartment = String(payload.sub_department || "").trim();
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

      // Master tab — always written so reports & emails read one place.
      ensureSheetWithHeaders_(ss, "Responses", HAPPINESS_HEADERS);
      appendToSheet_(ss, "Responses", row);

      // Per-department tab — written only when the dept is recognised.
      if (department && DEPARTMENT_TABS[department]) {
        ensureSheetWithHeaders_(ss, DEPARTMENT_TABS[department], HAPPINESS_HEADERS);
        appendToSheet_(ss, DEPARTMENT_TABS[department], row);
      }
    } else if (type === "install" || type === "update" || type === "uninstall") {
      ensureSheetWithHeaders_(ss, "Installs", INSTALL_HEADERS);
      appendToSheet_(ss, "Installs", [
        payload.timestamp || nowIso,
        payload.username || "unknown",
        payload.source || type,
        sanitiseDepartment_(payload.department),
        payload.arch || "unknown",
        payload.os || "unknown"
      ]);
    } else if (type === "registration") {
      ensureSheetWithHeaders_(ss, "Registrations", REGISTRATION_HEADERS);
      appendToSheet_(ss, "Registrations", [
        payload.timestamp || nowIso,
        payload.name || "unknown",
        payload.version || "unknown",
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
    version: "3.0.0"
  });
}

/**
 * Whitelist — anything not on it returns "" so the row still lands in the
 * Responses master tab but skips per-department routing.
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
 * Idempotently ensure a sheet with the given header row exists. Creates
 * the sheet if missing; writes the header if the sheet exists but is empty.
 * Doesn't touch existing data.
 */
function ensureSheetWithHeaders_(ss, name, headers) {
  var sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    return;
  }
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
