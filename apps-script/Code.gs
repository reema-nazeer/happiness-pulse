var HOMEY_SPREADSHEET_ID = "1byV_pv5NMI8fMY4v0m74qdNDtdybXvX-KXA2e_0ra0w";

function doPost(e) {
  try {
    var ss = SpreadsheetApp.openById(HOMEY_SPREADSHEET_ID);
    var payload = parseRequestPayload_(e);
    enforceWebhookAuth_(payload);
    var nowIso = new Date().toISOString();
    var type = String(payload.type || "").toLowerCase();

    if (type === "happiness") {
      appendToSheet_(ss, "Responses", [
        payload.timestamp || nowIso,
        payload.score,
        payload.feedback || "",
        payload.version || "unknown",
        payload.source || "unknown",
        payload.os_version || "unknown"
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
