// Weekly Happiness Pulse summary, sent Friday 5PM BST.
// Reuses constants and helpers from DailyEmail.gs (HOMEY_LONDON_TZ,
// HOMEY_EMAIL_*, COLOR_*, DEPT_MIN_RESPONSES, DEPARTMENTS, escapeHtml_,
// coerceToDate_, HOMEY_LOGO_URL).

function weeklySummary() {
  var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
  var sheet = ss.getSheetByName("Responses");
  if (!sheet) throw new Error('Missing sheet: "Responses"');

  var now = new Date();
  var thisWeek = weekRange_(now);                   // Mon..Fri of "now"
  var lastWeek = weekRange_(addDays_(now, -7));    // previous Mon..Fri

  var allRows = readAllResponses_(sheet);
  var thisRows = filterRowsInRange_(allRows, thisWeek.start, thisWeek.end);
  var lastRows = filterRowsInRange_(allRows, lastWeek.start, lastWeek.end);

  var thisSummary = summariseRowsForWeek_(thisRows);
  var lastSummary = summariseRowsForWeek_(lastRows);

  var subject = "Weekly Happiness Pulse — " +
    Utilities.formatDate(thisWeek.startDate, HOMEY_LONDON_TZ, "d MMM") + " to " +
    Utilities.formatDate(thisWeek.endDate, HOMEY_LONDON_TZ, "d MMM yyyy");

  MailApp.sendEmail({
    to: HOMEY_EMAIL_TO,
    cc: HOMEY_EMAIL_CC,
    subject: subject,
    name: HOMEY_EMAIL_SENDER_NAME,
    htmlBody: buildWeeklyHtml_(thisWeek, thisSummary, lastSummary)
  });
}

/**
 * Idempotently install the Friday-5PM-BST trigger. Run this once in the
 * Apps Script editor after deploying — it removes any existing trigger for
 * weeklySummary and creates a fresh one. Safe to re-run.
 */
function installWeeklyTrigger() {
  var existing = ScriptApp.getProjectTriggers();
  for (var i = 0; i < existing.length; i++) {
    if (existing[i].getHandlerFunction() === "weeklySummary") {
      ScriptApp.deleteTrigger(existing[i]);
    }
  }
  ScriptApp.newTrigger("weeklySummary")
    .timeBased()
    .everyWeeks(1)
    .onWeekDay(ScriptApp.WeekDay.FRIDAY)
    .atHour(17)
    .inTimezone(HOMEY_LONDON_TZ)
    .create();
}

// ---------- date helpers ----------

function addDays_(date, days) {
  var d = new Date(date.getTime());
  d.setDate(d.getDate() + days);
  return d;
}

/**
 * Mon..Fri inclusive containing the given date (interpreted in London time).
 * Returns { start, end, startDate, endDate } where start/end are
 * "yyyy-MM-dd" keys for filtering and startDate/endDate are Date objects
 * for display formatting.
 */
function weekRange_(anchor) {
  var anchorKey = Utilities.formatDate(anchor, HOMEY_LONDON_TZ, "yyyy-MM-dd");
  // Day-of-week 1=Mon..7=Sun in ISO terms; Apps Script returns 0=Sun..6=Sat,
  // so we adjust manually using formatDate.
  var dowName = Utilities.formatDate(anchor, HOMEY_LONDON_TZ, "EEEE");
  var offsets = { Monday: 0, Tuesday: -1, Wednesday: -2, Thursday: -3, Friday: -4, Saturday: -5, Sunday: -6 };
  var fromMonday = offsets[dowName] !== undefined ? offsets[dowName] : 0;
  var monday = addDays_(anchor, fromMonday);
  var friday = addDays_(monday, 4);
  return {
    startDate: monday,
    endDate: friday,
    start: Utilities.formatDate(monday, HOMEY_LONDON_TZ, "yyyy-MM-dd"),
    end: Utilities.formatDate(friday, HOMEY_LONDON_TZ, "yyyy-MM-dd")
  };
}

// ---------- data ----------

function readAllResponses_(sheet) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];
  var lastCol = Math.max(sheet.getLastColumn(), 6);
  var values = sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    var row = values[i];
    var date = coerceToDate_(row[0]);
    var score = Number(row[1]);
    if (!date || isNaN(score)) continue;
    out.push({
      date: date,
      key: Utilities.formatDate(date, HOMEY_LONDON_TZ, "yyyy-MM-dd"),
      score: score,
      feedback: row[2] ? String(row[2]).trim() : "",
      department: row[6] != null ? String(row[6]).trim() : ""
    });
  }
  return out;
}

function filterRowsInRange_(rows, startKey, endKey) {
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].key >= startKey && rows[i].key <= endKey) out.push(rows[i]);
  }
  return out;
}

/**
 * Like summariseRows_ from DailyEmail.gs but always returns a per-department
 * stats map keyed by department name (even for departments below threshold,
 * so we can compute trend deltas on totals & averages independently of
 * whether the row will be displayed).
 */
function summariseRowsForWeek_(rows) {
  var total = rows.length;
  var sum = 0;
  var feedback = [];
  var byDept = {};
  for (var i = 0; i < DEPARTMENTS.length; i++) {
    byDept[DEPARTMENTS[i]] = { total: 0, sum: 0, average: 0 };
  }
  for (i = 0; i < rows.length; i++) {
    var r = rows[i];
    sum += r.score;
    if (r.feedback) feedback.push({ score: r.score, comment: r.feedback });
    if (byDept.hasOwnProperty(r.department)) {
      byDept[r.department].total++;
      byDept[r.department].sum += r.score;
    }
  }
  for (i = 0; i < DEPARTMENTS.length; i++) {
    var s = byDept[DEPARTMENTS[i]];
    s.average = s.total > 0 ? s.sum / s.total : 0;
  }
  return {
    total: total,
    average: total === 0 ? 0 : sum / total,
    feedback: feedback,
    byDept: byDept
  };
}

// ---------- HTML ----------

function buildWeeklyHtml_(weekRange, summary, lastWeek) {
  var label = Utilities.formatDate(weekRange.startDate, HOMEY_LONDON_TZ, "d MMM") +
    " — " + Utilities.formatDate(weekRange.endDate, HOMEY_LONDON_TZ, "d MMM yyyy");

  var inner = [
    weeklyOverallSection_(summary, lastWeek),
    weeklyDepartmentSection_(summary, lastWeek),
    feedbackSection_(summary.feedback)
  ].join("");

  // Reuse the daily wrap_ but swap the eyebrow text
  return wrapWeekly_(label, inner);
}

function wrapWeekly_(label, innerHtml) {
  return (
    '<div style="background:#F5F4FB;padding:24px 12px;font-family:Inter,-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif;">' +
      '<div style="max-width:600px;margin:0 auto;background:' + COLOR_WHITE + ';border-radius:16px;border:1px solid #ECECEE;overflow:hidden;">' +
        '<div style="background:' + COLOR_BLACK + ';padding:24px 24px 22px;text-align:center;">' +
          '<img src="' + HOMEY_LOGO_URL + '" alt="Homey" height="40" style="display:block;margin:0 auto 14px;height:40px;width:auto;" />' +
          '<div style="font-size:11px;letter-spacing:1.4px;text-transform:uppercase;color:' + COLOR_YELLOW + ';font-weight:600;margin-bottom:6px;">Weekly Happiness Pulse</div>' +
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

function weeklyOverallSection_(summary, lastWeek) {
  var avgWidth = Math.max(6, Math.round((summary.average / 10) * 100));
  var trend = trendIndicator_(summary.average, lastWeek.average);
  return (
    '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">This week</h2>' +
    '<div style="background:#FAFAFC;border:1px solid #ECECEE;border-radius:12px;padding:16px;margin-bottom:20px;">' +
      '<table style="width:100%;border-collapse:collapse;margin-bottom:12px;"><tr>' +
        metricCell_("Responses", String(summary.total)) +
        metricCell_("Average", summary.average.toFixed(1) + " / 10") +
        '<td style="padding:0;vertical-align:top;width:25%;text-align:right;">' +
          '<div style="color:#9aa0a6;font-size:11px;text-transform:uppercase;letter-spacing:0.6px;font-weight:600;">vs last week</div>' +
          '<div style="margin-top:4px;font-size:18px;font-weight:700;color:' + trend.color + ';letter-spacing:-0.2px;">' +
            trend.symbol + ' ' + trend.text +
          '</div>' +
        '</td>' +
      '</tr></table>' +
      '<div style="height:10px;background:#ECECEE;border-radius:5px;overflow:hidden;">' +
        '<div style="height:100%;width:' + avgWidth + '%;background:' + COLOR_PURPLE + ';border-radius:5px;"></div>' +
      '</div>' +
    '</div>'
  );
}

function weeklyDepartmentSection_(summary, lastWeek) {
  // Apply 2+ threshold here, just like daily
  var visible = [];
  for (var i = 0; i < DEPARTMENTS.length; i++) {
    var name = DEPARTMENTS[i];
    var stats = summary.byDept[name];
    if (stats.total >= DEPT_MIN_RESPONSES) {
      visible.push({
        name: name,
        total: stats.total,
        average: stats.average,
        prevAvg: lastWeek.byDept[name] ? lastWeek.byDept[name].average : 0,
        prevTotal: lastWeek.byDept[name] ? lastWeek.byDept[name].total : 0
      });
    }
  }
  if (visible.length === 0) {
    return (
      '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">By department</h2>' +
      '<p style="margin:0 0 20px;color:#9aa0a6;font-size:13px;line-height:1.6;">' +
        'No department reached the ' + DEPT_MIN_RESPONSES + '-response anonymity threshold this week.' +
      '</p>'
    );
  }
  var rows = visible.map(function (d) {
    var w = Math.max(6, Math.round((d.average / 10) * 100));
    // Trend only meaningful if last week also had >= threshold responses
    var hadPrev = d.prevTotal >= DEPT_MIN_RESPONSES;
    var t = hadPrev ? trendIndicator_(d.average, d.prevAvg) : { symbol: "—", text: "", color: "#9aa0a6" };
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
        '<td style="padding:10px 0 10px 12px;text-align:right;width:50px;">' +
          '<span style="color:' + t.color + ';font-weight:700;font-size:14px;">' + t.symbol + '</span>' +
        '</td>' +
      '</tr>'
    );
  }).join("");

  return (
    '<h2 style="margin:0 0 12px;color:' + COLOR_BLACK + ';font-size:14px;font-weight:600;">By department</h2>' +
    '<table style="width:100%;border-collapse:collapse;margin-bottom:20px;">' +
      '<thead><tr>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Department</th>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Resp.</th>' +
        '<th style="text-align:left;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Average</th>' +
        '<th style="text-align:right;padding:0 0 8px;color:#9aa0a6;font-size:11px;font-weight:600;letter-spacing:0.6px;text-transform:uppercase;">Trend</th>' +
      '</tr></thead>' +
      '<tbody>' + rows + '</tbody>' +
    '</table>' +
    '<p style="margin:-10px 0 18px;color:#9aa0a6;font-size:11px;line-height:1.6;">Trend is vs. last week. An em dash means the previous week did not have enough responses to compare against.</p>'
  );
}

/**
 * Tiny up/down/flat arrow with a colour, comparing two averages.
 * Up uses Strike Yellow per brief; down a muted red; flat an em dash.
 * The "flat" band is intentionally narrow (±0.05) so a meaningful change
 * isn't called flat.
 */
function trendIndicator_(current, previous) {
  if (previous === 0) return { symbol: "—", text: "no prior", color: "#9aa0a6" };
  var delta = current - previous;
  if (Math.abs(delta) < 0.05) return { symbol: "—", text: "flat", color: "#9aa0a6" };
  if (delta > 0) {
    return {
      symbol: "▲",
      text: "+" + delta.toFixed(1),
      color: COLOR_PURPLE  // up uses purple in chrome where yellow on white is illegible
    };
  }
  return {
    symbol: "▼",
    text: delta.toFixed(1),
    color: "#C13B3B"
  };
}
