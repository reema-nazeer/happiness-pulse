// Admin dashboard backend.
//
// Deploy as a SEPARATE Apps Script web app from the existing webhook so the
// URLs don't collide. (Same script project — different deployment.) When
// deploying:
//   - Execute as: Me
//   - Who has access: Anyone with the link (or Anyone within Homey)
//   - Set Script Property `ADMIN_PASSWORD` to the admin gate password
//
// The HTML page calls `getDashboardData(password)` over google.script.run
// and renders everything client-side. Auth check is server-side; the HTML
// just stops being useful without a valid password since none of the data
// arrives.

function doGet() {
  return HtmlService
    .createHtmlOutputFromFile("admin")
    .setTitle("Homey Pulse — Admin")
    .addMetaTag("viewport", "width=device-width, initial-scale=1")
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/**
 * One-shot data fetch for the dashboard. Returns everything the client
 * needs (overall, per-dept, 30-day series, last 50 anonymous feedback
 * comments, 14-day volume) in a single round-trip so the dashboard
 * renders fast.
 */
function getDashboardData(password) {
  if (!_checkAdminPassword(password)) {
    throw new Error("Invalid password");
  }

  var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
  var sheet = ss.getSheetByName("Responses");
  if (!sheet) throw new Error('Missing sheet: "Responses"');

  var rows = readAllResponses_(sheet); // from WeeklyEmail.gs

  var todayKey = Utilities.formatDate(new Date(), HOMEY_LONDON_TZ, "yyyy-MM-dd");
  var thisWeek = weekRange_(new Date()); // from WeeklyEmail.gs

  var overall = _aggregate(rows);
  var todayRows = _byDate(rows, todayKey);
  var weekRows = filterRowsInRange_(rows, thisWeek.start, thisWeek.end); // from WeeklyEmail.gs

  // Per-department breakdown for all-time, this-week, today.
  var perDept = DEPARTMENTS.map(function (name) {
    return {
      name: name,
      total: _filterDept(rows, name).length,
      averageAllTime: _avgScore(_filterDept(rows, name)),
      thisWeek: _filterDept(weekRows, name).length,
      averageThisWeek: _avgScore(_filterDept(weekRows, name)),
      today: _filterDept(todayRows, name).length,
      averageToday: _avgScore(_filterDept(todayRows, name))
    };
  });

  // Last 30 days (UTC dates), one entry per day, with a per-dept average +
  // overall average. Days with no responses for a department return null
  // so Chart.js skips that point on the line rather than dropping to 0.
  var trendDays = _last30Days();
  var trend = trendDays.map(function (key) {
    var dayRows = _byDate(rows, key);
    var entry = { date: key, overall: dayRows.length > 0 ? _avgScore(dayRows) : null };
    DEPARTMENTS.forEach(function (d) {
      var deptRows = _filterDept(dayRows, d);
      entry[d] = deptRows.length > 0 ? _avgScore(deptRows) : null;
    });
    return entry;
  });

  // 14-day volume — one bar per day, total responses across all departments.
  var volumeDays = _last14Days();
  var volume = volumeDays.map(function (key) {
    return { date: key, count: _byDate(rows, key).length };
  });

  // Last 50 feedback comments, with score + date but NO department label.
  // Anonymity: small teams could be triangulated even from admins.
  var feedback = rows
    .filter(function (r) { return r.feedback; })
    .sort(function (a, b) { return b.date.getTime() - a.date.getTime(); })
    .slice(0, 50)
    .map(function (r) {
      return {
        score: r.score,
        comment: r.feedback,
        date: Utilities.formatDate(r.date, HOMEY_LONDON_TZ, "d MMM yyyy")
      };
    });

  return {
    overall: {
      total: overall.total,
      averageAllTime: overall.average,
      thisWeekTotal: weekRows.length,
      thisWeekAverage: _avgScore(weekRows),
      todayTotal: todayRows.length,
      todayAverage: _avgScore(todayRows)
    },
    departments: perDept,
    trend: trend,
    volume: volume,
    feedback: feedback,
    config: {
      departments: DEPARTMENTS,
      anonymityThreshold: DEPT_MIN_RESPONSES
    }
  };
}

// ---------- helpers ----------

function _checkAdminPassword(password) {
  var configured = PropertiesService.getScriptProperties().getProperty("ADMIN_PASSWORD");
  if (!configured) {
    // Fail closed — if nobody has set the password yet, refuse access rather
    // than letting anyone in.
    return false;
  }
  return String(password || "") === configured;
}

function _aggregate(rows) {
  if (!rows.length) return { total: 0, average: 0 };
  var sum = 0;
  for (var i = 0; i < rows.length; i++) sum += rows[i].score;
  return { total: rows.length, average: sum / rows.length };
}

function _avgScore(rows) {
  if (!rows.length) return 0;
  var sum = 0;
  for (var i = 0; i < rows.length; i++) sum += rows[i].score;
  return sum / rows.length;
}

function _filterDept(rows, name) {
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].department === name) out.push(rows[i]);
  }
  return out;
}

function _byDate(rows, key) {
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].key === key) out.push(rows[i]);
  }
  return out;
}

function _last30Days() {
  var keys = [];
  var now = new Date();
  for (var i = 29; i >= 0; i--) {
    var d = new Date(now.getTime());
    d.setDate(d.getDate() - i);
    keys.push(Utilities.formatDate(d, HOMEY_LONDON_TZ, "yyyy-MM-dd"));
  }
  return keys;
}

function _last14Days() {
  var keys = [];
  var now = new Date();
  for (var i = 13; i >= 0; i--) {
    var d = new Date(now.getTime());
    d.setDate(d.getDate() - i);
    keys.push(Utilities.formatDate(d, HOMEY_LONDON_TZ, "yyyy-MM-dd"));
  }
  return keys;
}
