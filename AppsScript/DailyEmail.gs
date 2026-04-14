var HOMEY_LONDON_TZ = "Europe/London";
var HOMEY_EMAIL_TO = "department-leads@homey.co.uk";
var HOMEY_EMAIL_CC = "say@homey.co.uk";
var HOMEY_EMAIL_SENDER_NAME = "Homey Happiness Pulse";

function dailySummary() {
  var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
  var sheet = ss.getSheetByName("Responses");
  if (!sheet) {
    throw new Error('Missing sheet: "Responses"');
  }

  var now = new Date();
  var todayKey = Utilities.formatDate(now, HOMEY_LONDON_TZ, "yyyy-MM-dd");
  var todayLabel = Utilities.formatDate(now, HOMEY_LONDON_TZ, "dd/MM/yyyy");
  var rows = readTodayResponses_(sheet, todayKey);

  var subject = "Happiness Pulse - " + todayLabel;
  if (rows.length === 0) {
    MailApp.sendEmail({
      to: HOMEY_EMAIL_TO,
      cc: HOMEY_EMAIL_CC,
      subject: subject,
      name: HOMEY_EMAIL_SENDER_NAME,
      htmlBody: buildNoResponsesHtml_()
    });
    return;
  }

  var metrics = computeMetrics_(rows);
  MailApp.sendEmail({
    to: HOMEY_EMAIL_TO,
    cc: HOMEY_EMAIL_CC,
    subject: subject,
    name: HOMEY_EMAIL_SENDER_NAME,
    htmlBody: buildSummaryHtml_(todayLabel, metrics)
  });
}

function readTodayResponses_(sheet, todayKey) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    return [];
  }

  var values = sheet.getRange(2, 1, lastRow - 1, 6).getValues();
  var rows = [];
  for (var i = 0; i < values.length; i++) {
    var row = values[i];
    var ts = row[0];
    var score = Number(row[1]);
    var feedback = row[2] || "";
    var date = coerceToDate_(ts);
    if (!date || isNaN(score)) {
      continue;
    }
    var key = Utilities.formatDate(date, HOMEY_LONDON_TZ, "yyyy-MM-dd");
    if (key === todayKey) {
      rows.push({
        score: score,
        feedback: String(feedback).trim()
      });
    }
  }
  return rows;
}

function coerceToDate_(value) {
  if (Object.prototype.toString.call(value) === "[object Date]") {
    return value;
  }
  var parsed = new Date(value);
  return isNaN(parsed.getTime()) ? null : parsed;
}

function computeMetrics_(rows) {
  var total = rows.length;
  var sum = 0;
  var highest = -Infinity;
  var lowest = Infinity;
  var distribution = {};
  var feedback = [];
  var i;

  for (i = 1; i <= 10; i++) {
    distribution[i] = 0;
  }

  for (i = 0; i < rows.length; i++) {
    var score = rows[i].score;
    sum += score;
    if (score > highest) highest = score;
    if (score < lowest) lowest = score;
    if (distribution[score] !== undefined) {
      distribution[score]++;
    }
    if (rows[i].feedback) {
      feedback.push(rows[i].feedback);
    }
  }

  var average = total === 0 ? 0 : sum / total;
  return {
    total: total,
    average: average,
    highest: highest,
    lowest: lowest,
    distribution: distribution,
    feedback: feedback
  };
}

function buildSummaryHtml_(todayLabel, metrics) {
  var banner = sentimentBanner_(metrics.average);
  var maxCount = 1;
  for (var s = 1; s <= 10; s++) {
    if (metrics.distribution[s] > maxCount) {
      maxCount = metrics.distribution[s];
    }
  }

  var distributionHtml = "";
  for (var score = 1; score <= 10; score++) {
    var count = metrics.distribution[score] || 0;
    var widthPct = Math.max(6, Math.round((count / maxCount) * 100));
    distributionHtml +=
      '<tr>' +
        '<td style="padding:6px 8px 6px 0;color:#AAAAAA;font-size:12px;width:24px;">' + score + "</td>" +
        '<td style="padding:6px 0;">' +
          '<div style="height:12px;border-radius:6px;background:' + scoreColor_(score) + ";width:" + widthPct + '%;"></div>' +
        "</td>" +
        '<td style="padding:6px 0 6px 8px;color:#CCCCCC;font-size:12px;width:30px;text-align:right;">' + count + "</td>" +
      "</tr>";
  }

  var feedbackHtml = metrics.feedback.length
    ? "<ul style=\"padding-left:18px;margin:0;\">" +
        metrics.feedback.map(function(item) {
          return '<li style="margin-bottom:8px;color:#E5E5E5;line-height:1.5;">' + escapeHtml_(item) + "</li>";
        }).join("") +
      "</ul>"
    : '<p style="margin:0;color:#888888;">No written feedback today.</p>';

  return (
    '<div style="background:#0A0A0A;padding:24px 12px;font-family:Arial,Helvetica,sans-serif;">' +
      '<div style="max-width:600px;margin:0 auto;background:#040406;border-radius:16px;border:1px solid #1A1A1A;overflow:hidden;">' +
        '<div style="padding:20px 24px;border-bottom:1px solid #1A1A1A;">' +
          '<div style="font-size:12px;letter-spacing:0.8px;text-transform:uppercase;color:#DBFF00;margin-bottom:6px;">Homey</div>' +
          '<h1 style="margin:0;color:#FFFFFF;font-size:24px;line-height:1.2;">Daily Happiness Pulse</h1>' +
          '<p style="margin:8px 0 0;color:#AAAAAA;font-size:13px;">' + todayLabel + "</p>" +
        "</div>" +
        '<div style="padding:20px 24px;">' +
          '<div style="background:#0F0F12;border:1px solid #222222;border-radius:12px;padding:16px;margin-bottom:16px;">' +
            '<table style="width:100%;border-collapse:collapse;">' +
              '<tr>' +
                metricCell_("Total responses", metrics.total) +
                metricCell_("Average score", metrics.average.toFixed(1)) +
              "</tr>" +
              '<tr>' +
                metricCell_("Highest score", metrics.highest) +
                metricCell_("Lowest score", metrics.lowest) +
              "</tr>" +
            "</table>" +
          "</div>" +
          '<div style="background:' + banner.bg + ";color:" + banner.fg + ';padding:12px 14px;border-radius:10px;font-weight:bold;font-size:13px;margin-bottom:16px;">' +
            banner.text +
          "</div>" +
          '<h2 style="margin:0 0 10px;color:#FFFFFF;font-size:16px;">Score distribution</h2>' +
          '<table style="width:100%;border-collapse:collapse;margin-bottom:18px;">' + distributionHtml + "</table>" +
          '<h2 style="margin:0 0 10px;color:#FFFFFF;font-size:16px;">Anonymous feedback</h2>' +
          feedbackHtml +
        "</div>" +
        '<div style="padding:14px 24px;border-top:1px solid #1A1A1A;color:#777777;font-size:12px;">This is an automated summary from Homey Happiness Pulse v2</div>' +
      "</div>" +
    "</div>"
  );
}

function buildNoResponsesHtml_() {
  return (
    '<div style="background:#0A0A0A;padding:24px 12px;font-family:Arial,Helvetica,sans-serif;">' +
      '<div style="max-width:600px;margin:0 auto;background:#040406;border-radius:16px;border:1px solid #1A1A1A;overflow:hidden;">' +
        '<div style="padding:22px 24px;">' +
          '<h1 style="margin:0 0 8px;color:#FFFFFF;font-size:22px;">Daily Happiness Pulse</h1>' +
          '<p style="margin:0;color:#AAAAAA;line-height:1.6;">No responses today - consider checking if the pulse is installed on all devices.</p>' +
        "</div>" +
        '<div style="padding:14px 24px;border-top:1px solid #1A1A1A;color:#777777;font-size:12px;">This is an automated summary from Homey Happiness Pulse v2</div>' +
      "</div>" +
    "</div>"
  );
}

function metricCell_(label, value) {
  return (
    '<td style="padding:8px;vertical-align:top;">' +
      '<div style="color:#888888;font-size:11px;text-transform:uppercase;letter-spacing:0.6px;">' + label + "</div>" +
      '<div style="color:#FFFFFF;font-size:20px;font-weight:bold;margin-top:4px;">' + value + "</div>" +
    "</td>"
  );
}

function sentimentBanner_(avg) {
  if (avg >= 7) {
    return { text: "The team is feeling great today!", bg: "#0E2A1A", fg: "#8CFFB3" };
  }
  if (avg >= 5) {
    return { text: "Room for improvement", bg: "#2A260A", fg: "#FFE680" };
  }
  return { text: "The team needs support today", bg: "#2A0E0E", fg: "#FF9A9A" };
}

function scoreColor_(score) {
  if (score <= 3) return "#FF4444";
  if (score <= 5) return "#FF8C00";
  if (score <= 7) return "#DBFF00";
  return "#00CC66";
}

function escapeHtml_(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
