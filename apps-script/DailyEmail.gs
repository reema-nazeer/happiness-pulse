var HOMEY_LONDON_TZ = "Europe/London";
var HOMEY_EMAIL_TO = "department-leads@homey.co.uk";
var HOMEY_EMAIL_CC = "say@homey.co.uk";
var HOMEY_EMAIL_SENDER_NAME = "Homey Happiness Pulse";

// Hosted brand asset. Once the v2 PR is merged, this will resolve from main.
// Until then it 404s — most clients just hide a missing image and the rest
// of the email renders fine.
var HOMEY_LOGO_URL =
  "https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/assets/homey-logo.png";

// Brand
var COLOR_PURPLE = "#7C57FC";
var COLOR_YELLOW = "#DBFF00";
var COLOR_BLACK = "#040406";
var COLOR_WHITE = "#FFFFFF";

// Anonymity threshold: any department with fewer than this many responses
// for the period is excluded from the breakdown table — its rows still feed
// the overall total and average so the data isn't lost, just not attributed.
var DEPT_MIN_RESPONSES = 2;
var DEPARTMENTS = ["Operations", "Revenue", "Service", "Technology"];

function dailySummary() {
  var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
  var sheet = ss.getSheetByName("Responses");
  if (!sheet) {
    throw new Error('Missing sheet: "Responses"');
  }

  var now = new Date();
  var todayKey = Utilities.formatDate(now, HOMEY_LONDON_TZ, "yyyy-MM-dd");
  var todayLabel = Utilities.formatDate(now, HOMEY_LONDON_TZ, "EEEE d MMMM yyyy");
  var rows = readResponsesForDate_(sheet, todayKey);

  var subject = "Happiness Pulse — " + Utilities.formatDate(now, HOMEY_LONDON_TZ, "dd/MM/yyyy");
  if (rows.length === 0) {
    MailApp.sendEmail({
      to: HOMEY_EMAIL_TO,
      cc: HOMEY_EMAIL_CC,
      subject: subject,
      name: HOMEY_EMAIL_SENDER_NAME,
      htmlBody: buildNoResponsesHtml_(todayLabel)
    });
    return;
  }

  var summary = summariseRows_(rows);
  MailApp.sendEmail({
    to: HOMEY_EMAIL_TO,
    cc: HOMEY_EMAIL_CC,
    subject: subject,
    name: HOMEY_EMAIL_SENDER_NAME,
    htmlBody: buildDailyHtml_(todayLabel, summary)
  });
}

/**
 * Read every Responses row and keep just the ones for the given local date
 * (Europe/London). Returns objects so downstream code doesn't have to
 * remember column indices.
 */
function readResponsesForDate_(sheet, targetKey) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];

  var lastCol = Math.max(sheet.getLastColumn(), 6);
  var values = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    var row = values[i];
    var ts = row[0];
    var score = Number(row[1]);
    var feedback = row[2] || "";
    var department = row[6] != null ? String(row[6]).trim() : "";
    var date = coerceToDate_(ts);
    if (!date || isNaN(score)) continue;
    var key = Utilities.formatDate(date, HOMEY_LONDON_TZ, "yyyy-MM-dd");
    if (key !== targetKey) continue;
    out.push({
      score: score,
      feedback: String(feedback).trim(),
      department: department
    });
  }
  return out;
}

function coerceToDate_(value) {
  if (Object.prototype.toString.call(value) === "[object Date]") return value;
  var parsed = new Date(value);
  return isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * Aggregate a list of response rows into:
 *   total   — number of responses
 *   average — overall average (across everyone, including those without a dept)
 *   feedback — list of {score, comment} for every non-empty comment
 *               (no department attached — anonymity)
 *   departments — only those meeting DEPT_MIN_RESPONSES
 *   hiddenDepartments — count of departments excluded for being below threshold
 */
function summariseRows_(rows) {
  var total = rows.length;
  var sum = 0;
  var feedback = [];
  var byDept = {};

  for (var i = 0; i < DEPARTMENTS.length; i++) {
    byDept[DEPARTMENTS[i]] = { total: 0, sum: 0 };
  }

  for (i = 0; i < rows.length; i++) {
    var r = rows[i];
    sum += r.score;
    if (r.feedback) {
      feedback.push({ score: r.score, comment: r.feedback });
    }
    if (byDept.hasOwnProperty(r.department)) {
      byDept[r.department].total++;
      byDept[r.department].sum += r.score;
    }
  }

  var visibleDepts = [];
  var hiddenDepartments = 0;
  for (i = 0; i < DEPARTMENTS.length; i++) {
    var d = DEPARTMENTS[i];
    var stats = byDept[d];
    if (stats.total >= DEPT_MIN_RESPONSES) {
      visibleDepts.push({
        name: d,
        total: stats.total,
        average: stats.sum / stats.total
      });
    } else if (stats.total > 0) {
      hiddenDepartments++;
    }
  }

  return {
    total: total,
    average: total === 0 ? 0 : sum / total,
    feedback: feedback,
    departments: visibleDepts,
    hiddenDepartments: hiddenDepartments
  };
}

// ---------- HTML rendering ----------

function buildDailyHtml_(label, summary) {
  return wrap_(label, [
    overallSection_(summary),
    departmentSection_(summary),
    feedbackSection_(summary.feedback)
  ].join(""));
}

function buildNoResponsesHtml_(label) {
  return wrap_(label,
    '<p style="margin:0;color:' + COLOR_BLACK + ';font-size:14px;line-height:1.6;">' +
      'No responses today — consider checking if the pulse is installed on all devices.' +
    '</p>'
  );
}

function wrap_(label, innerHtml) {
  return (
    '<div style="background:#F5F4FB;padding:24px 12px;font-family:Inter,-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif;">' +
      '<div style="max-width:600px;margin:0 auto;background:' + COLOR_WHITE + ';border-radius:16px;border:1px solid #ECECEE;overflow:hidden;">' +

        // Header — Midnight Black with the brand logo
        '<div style="background:' + COLOR_BLACK + ';padding:24px 24px 22px;text-align:center;">' +
          '<img src="' + HOMEY_LOGO_URL + '" alt="Homey" height="40" style="display:block;margin:0 auto 14px;height:40px;width:auto;" />' +
          '<div style="font-size:11px;letter-spacing:1.4px;text-transform:uppercase;color:' + COLOR_YELLOW + ';font-weight:600;margin-bottom:6px;">Daily Happiness Pulse</div>' +
          '<div style="color:' + COLOR_WHITE + ';font-size:14px;font-weight:500;opacity:0.85;">' + escapeHtml_(label) + '</div>' +
        '</div>' +

        '<div style="padding:24px;">' + innerHtml + '</div>' +

        '<div style="padding:14px 24px 18px;border-top:1px solid #ECECEE;color:#9aa0a6;font-size:11px;line-height:1.6;">' +
          'Departments with fewer than ' + DEPT_MIN_RESPONSES + ' responses are not shown to protect anonymity. Their data still feeds the overall total and average.' +
        '</div>' +
      '</div>' +
    '</div>'
  );
}

function overallSection_(summary) {
  var avgWidth = Math.max(6, Math.round((summary.average / 10) * 100));
  return (
    '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;letter-spacing:-0.1px;">Overall today</h2>' +
    '<div style="background:#FAFAFC;border:1px solid #ECECEE;border-radius:12px;padding:16px;margin-bottom:20px;">' +
      '<table style="width:100%;border-collapse:collapse;margin-bottom:12px;"><tr>' +
        metricCell_("Responses", String(summary.total)) +
        metricCell_("Average score", summary.average.toFixed(1) + " / 10") +
      '</tr></table>' +
      '<div style="height:10px;background:#ECECEE;border-radius:5px;overflow:hidden;">' +
        '<div style="height:100%;width:' + avgWidth + '%;background:' + COLOR_PURPLE + ';border-radius:5px;"></div>' +
      '</div>' +
    '</div>'
  );
}

function departmentSection_(summary) {
  if (summary.departments.length === 0) {
    return (
      '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">By department</h2>' +
      '<p style="margin:0 0 20px;color:#9aa0a6;font-size:13px;line-height:1.6;">' +
        'No department reached the ' + DEPT_MIN_RESPONSES + '-response anonymity threshold today.' +
      '</p>'
    );
  }
  var rows = summary.departments.map(function (d) {
    var w = Math.max(6, Math.round((d.average / 10) * 100));
    return (
      '<tr>' +
        '<td style="padding:10px 0;color:' + COLOR_BLACK + ';font-size:13px;font-weight:500;width:120px;">' + escapeHtml_(d.name) + '</td>' +
        '<td style="padding:10px 0;color:#9aa0a6;font-size:12px;width:60px;">' + d.total + '</td>' +
        '<td style="padding:10px 0;">' +
          '<div style="display:flex;align-items:center;gap:10px;">' +
            '<div style="flex:1;height:8px;background:#ECECEE;border-radius:4px;overflow:hidden;">' +
              '<div style="height:100%;width:' + w + '%;background:' + COLOR_PURPLE + ';border-radius:4px;"></div>' +
            '</div>' +
            '<div style="color:' + COLOR_BLACK + ';font-size:13px;font-weight:600;min-width:36px;text-align:right;">' + d.average.toFixed(1) + '</div>' +
          '</div>' +
        '</td>' +
      '</tr>'
    );
  }).join("");
  return (
    '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">By department</h2>' +
    '<table style="width:100%;border-collapse:collapse;margin-bottom:20px;">' +
      '<thead><tr>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Department</th>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Responses</th>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Average</th>' +
      '</tr></thead>' +
      '<tbody>' + rows + '</tbody>' +
    '</table>'
  );
}

function feedbackSection_(feedback) {
  if (!feedback.length) {
    return (
      '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">Anonymous feedback</h2>' +
      '<p style="margin:0;color:#9aa0a6;font-size:13px;">No written feedback today.</p>'
    );
  }
  var items = feedback.map(function (f) {
    return (
      '<li style="margin:0 0 12px;padding:12px 14px;background:#FAFAFC;border-left:3px solid ' + COLOR_PURPLE + ';border-radius:6px;list-style:none;">' +
        '<div style="color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.4px;text-transform:uppercase;margin-bottom:4px;">Score ' + f.score + '/10</div>' +
        '<div style="color:' + COLOR_BLACK + ';font-size:13px;line-height:1.6;">' + escapeHtml_(f.comment) + '</div>' +
      '</li>'
    );
  }).join("");
  return (
    '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">Anonymous feedback</h2>' +
    '<ul style="padding:0;margin:0;">' + items + '</ul>'
  );
}

function metricCell_(label, value) {
  return (
    '<td style="padding:0 8px 0 0;vertical-align:top;width:50%;">' +
      '<div style="color:#9aa0a6;font-size:11px;text-transform:uppercase;letter-spacing:0.6px;font-weight:600;">' + label + '</div>' +
      '<div style="color:' + COLOR_BLACK + ';font-size:22px;font-weight:700;margin-top:4px;letter-spacing:-0.3px;">' + value + '</div>' +
    '</td>'
  );
}

function escapeHtml_(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
