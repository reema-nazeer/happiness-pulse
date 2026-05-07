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

function doGet(e) {
  var params = e && e.parameter ? e.parameter : {};
  if (params.action === "subdepts") {
    return getSubDepartmentsResponse_(params.department);
  }
  return jsonResponse_({ status: "running", version: "3.0.0" });
}

/**
 * Reads the Config sheet and returns the sub-department list for the
 * requested department as JSON.
 * Config sheet layout (row 1 = header):
 *   Column A: Department name
 *   Column B: Sub-departments, comma-separated
 */
function getSubDepartmentsResponse_(department) {
  var ss = SpreadsheetApp.openById(_spreadsheetId_());
  ensureConfigSheet_(ss);
  var sheet = ss.getSheetByName("Config");
  var data  = sheet.getDataRange().getValues();
  var dept  = String(department || "").trim().toLowerCase();

  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0] || "").trim().toLowerCase() === dept) {
      var raw     = String(data[i][1] || "");
      var subdepts = raw.split(",")
        .map(function(s) { return s.trim(); })
        .filter(function(s) { return s.length > 0; });
      return jsonResponse_({ status: "ok", sub_departments: subdepts });
    }
  }
  return jsonResponse_({ status: "ok", sub_departments: [] });
}

/**
 * Creates the Config sheet with the four department rows if it doesn't
 * already exist. Existing data is never touched.
 */
function ensureConfigSheet_(ss) {
  if (ss.getSheetByName("Config")) return;
  var sheet = ss.insertSheet("Config");
  sheet.getRange(1, 1, 1, 2).setValues([["Department", "Sub-departments (comma separated)"]]);
  sheet.setFrozenRows(1);
  sheet.getRange(2, 1, 4, 1).setValues([
    ["Operations"],
    ["Revenue"],
    ["Service"],
    ["Technology"]
  ]);
  // Bold the header and auto-resize columns so it's easy to read.
  sheet.getRange(1, 1, 1, 2).setFontWeight("bold");
  sheet.autoResizeColumns(1, 2);
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

// ─── Email Reporting ─────────────────────────────────────────────────────────

var DAILY_EMAIL_RECIPIENT  = "department-leads@homey.co.uk";
var WEEKLY_EMAIL_RECIPIENT = "Sujan@homey.co.uk";

/**
 * Run this ONCE in the Apps Script editor (Run → setupEmailTriggers) to
 * register the daily and weekly email triggers. Safe to re-run — it
 * removes old copies first.
 */
function setupEmailTriggers() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    var fn = t.getHandlerFunction();
    if (fn === "sendDailyEmail" || fn === "sendWeeklyEmail") {
      ScriptApp.deleteTrigger(t);
    }
  });

  // Daily at 18:00 — covers responses submitted that day.
  ScriptApp.newTrigger("sendDailyEmail")
    .timeBased()
    .everyDays(1)
    .atHour(18)
    .create();

  // Weekly — runs every Monday at 08:00 and covers the previous Mon–Fri.
  ScriptApp.newTrigger("sendWeeklyEmail")
    .timeBased()
    .onWeekDay(ScriptApp.WeekDay.MONDAY)
    .atHour(8)
    .create();
}

function sendDailyEmail() {
  var ss    = SpreadsheetApp.openById(_spreadsheetId_());
  var sheet = ss.getSheetByName("Responses");
  if (!sheet || sheet.getLastRow() < 2) return;

  var today = new Date();
  var start = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0);
  var end   = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59);

  var rows = getRowsInRange_(sheet, start, end);
  if (rows.length === 0) return;

  var overall = calcOverallAverage_(rows);
  var byDept  = calcDeptAverages_(rows);

  var depts = Object.keys(byDept).filter(function(d) { return byDept[d].count > 0; });
  depts.sort(function(a, b) { return byDept[b].avg - byDept[a].avg; });

  var happiest   = depts[0];
  var unhappiest = depts[depts.length - 1];

  var tz      = Session.getScriptTimeZone();
  var dateStr = Utilities.formatDate(today, tz, "d MMMM yyyy");

  MailApp.sendEmail(
    DAILY_EMAIL_RECIPIENT,
    "Happiness Pulse — Daily Summary " + dateStr,
    buildDailyBody_(dateStr, overall, rows.length, happiest, unhappiest, byDept)
  );
}

function sendWeeklyEmail() {
  var ss    = SpreadsheetApp.openById(_spreadsheetId_());
  var sheet = ss.getSheetByName("Responses");
  if (!sheet || sheet.getLastRow() < 2) return;

  // Runs on Monday — calculate last Monday → last Friday.
  var today          = new Date();
  var dayOfWeek      = today.getDay();                          // 0=Sun … 6=Sat
  var daysBack       = (dayOfWeek === 1) ? 7 : (dayOfWeek === 0 ? 6 : dayOfWeek - 1);
  var lastMonday     = new Date(today);
  lastMonday.setDate(today.getDate() - daysBack);
  lastMonday.setHours(0, 0, 0, 0);
  var lastFriday     = new Date(lastMonday);
  lastFriday.setDate(lastMonday.getDate() + 4);
  lastFriday.setHours(23, 59, 59, 999);

  var rows = getRowsInRange_(sheet, lastMonday, lastFriday);
  if (rows.length === 0) return;

  var overall = calcOverallAverage_(rows);
  var byDept  = calcDeptAverages_(rows);

  var tz      = Session.getScriptTimeZone();
  var weekStr = Utilities.formatDate(lastMonday, tz, "d MMM") +
                " – " +
                Utilities.formatDate(lastFriday, tz, "d MMM yyyy");

  MailApp.sendEmail(
    WEEKLY_EMAIL_RECIPIENT,
    "Happiness Pulse — Weekly Summary " + weekStr,
    buildWeeklyBody_(weekStr, overall, rows.length, byDept)
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

function getRowsInRange_(sheet, start, end) {
  var data   = sheet.getDataRange().getValues();
  var result = [];
  for (var i = 1; i < data.length; i++) {
    var ts = data[i][0];
    if (!ts) continue;
    var d = ts instanceof Date ? ts : new Date(ts);
    if (!isNaN(d.getTime()) && d >= start && d <= end) result.push(data[i]);
  }
  return result;
}

function calcOverallAverage_(rows) {
  if (!rows.length) return 0;
  var sum = 0;
  rows.forEach(function(r) { sum += Number(r[1]) || 0; });
  return Math.round((sum / rows.length) * 10) / 10;
}

function calcDeptAverages_(rows) {
  var buckets = {};
  rows.forEach(function(r) {
    var dept = r[3] || "Unknown";
    if (!buckets[dept]) buckets[dept] = { sum: 0, count: 0 };
    buckets[dept].sum   += Number(r[1]) || 0;
    buckets[dept].count += 1;
  });
  var result = {};
  Object.keys(buckets).forEach(function(d) {
    result[d] = {
      avg:   Math.round((buckets[d].sum / buckets[d].count) * 10) / 10,
      count: buckets[d].count
    };
  });
  return result;
}

function plural_(n) { return n === 1 ? "response" : "responses"; }

function buildDailyBody_(dateStr, overall, total, happiest, unhappiest, byDept) {
  var lines = [
    "Happiness Pulse — Daily Summary",
    dateStr,
    "",
    "Overall average:       " + overall + " / 5   (" + total + " " + plural_(total) + ")",
    "",
    "Happiest department:   " + happiest   + " — " + byDept[happiest].avg   + " / 5  (" + byDept[happiest].count   + " " + plural_(byDept[happiest].count)   + ")",
    "Unhappiest department: " + unhappiest + " — " + byDept[unhappiest].avg + " / 5  (" + byDept[unhappiest].count + " " + plural_(byDept[unhappiest].count) + ")",
    "",
    "— Homey Happiness Pulse"
  ];
  return lines.join("\n");
}

function buildWeeklyBody_(weekStr, overall, total, byDept) {
  var lines = [
    "Happiness Pulse — Weekly Summary",
    weekStr,
    "",
    "Overall average:   " + overall + " / 5   (" + total + " " + plural_(total) + ")",
    "",
    "Department breakdown:"
  ];
  var depts = Object.keys(byDept).sort(function(a, b) { return byDept[b].avg - byDept[a].avg; });
  depts.forEach(function(d) {
    lines.push("  " + d + ":   " + byDept[d].avg + " / 5  (" + byDept[d].count + " " + plural_(byDept[d].count) + ")");
  });
  lines.push("");
  lines.push("— Homey Happiness Pulse");
  return lines.join("\n");
}
