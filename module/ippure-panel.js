/**
 * Surge Information Panel Script
 * - Returns {title, content, style} via $done()
 * - style: good / info / alert / error
 */

const API = "https://my.ippure.com/v1/info";
const CACHE_KEY = "ippure_cache_json";
const CACHE_TS_KEY = "ippure_cache_ts";
const CACHE_TTL_MS = 10 * 1000; // 10s: enough to cover 3 panels triggered close together

function parseArgs(raw) {
  if (!raw) return {};
  raw = String(raw).trim();
  // Surge supports $argument; usually "a=b&c=d"
  const out = {};
  // If someone passed JSON argument
  if (raw.startsWith("{") && raw.endsWith("}")) {
    try { return JSON.parse(raw); } catch (_) {}
  }
  raw.split("&").forEach(kv => {
    const i = kv.indexOf("=");
    if (i === -1) return;
    const k = decodeURIComponent(kv.slice(0, i).trim());
    const v = decodeURIComponent(kv.slice(i + 1).trim());
    out[k] = v;
  });
  return out;
}

function httpGet(url) {
  return new Promise((resolve) => {
    $httpClient.get({ url, timeout: 5 }, (error, response, data) => {
      resolve({ error, response, data });
    });
  });
}

async function fetchInfoJson() {
  // short cache to avoid 3 near-simultaneous calls
  const now = Date.now();
  const ts = Number($persistentStore.read(CACHE_TS_KEY) || "0");
  const cached = $persistentStore.read(CACHE_KEY);

  if (cached && ts && (now - ts) < CACHE_TTL_MS) {
    try { return JSON.parse(cached); } catch (_) {}
  }

  const { error, data } = await httpGet(API);
  if (error || !data) throw new Error("Network Error");

  const json = JSON.parse(data);
  $persistentStore.write(JSON.stringify(json), CACHE_KEY);
  $persistentStore.write(String(now), CACHE_TS_KEY);
  return json;
}

function doneError(title, msg) {
  $done({ title, content: msg, style: "error" });
}

(async () => {
  const args = parseArgs($argument);
  const mode = (args.mode || "info").toLowerCase();

  try {
    const json = await fetchInfoJson();

    if (mode === "fraud") {
      const score = json.fraudScore;
      if (score === undefined || score === null) {
        return $done({ title: "IPPure Fraud Score", content: "No Score", style: "error" });
      }

      let style = "good";            // 低风险
      if (score >= 40 && score < 70) style = "alert"; // 中风险
      if (score >= 70)               style = "error"; // 高风险

      return $done({
        title: "IPPure Fraud Score",
        content: `Fraud Score: ${score}`,
        style,
      });
    }

    if (mode === "native") {
      const isRes = Boolean(json.isResidential);
      const isBrd = Boolean(json.isBroadcast);

      const resText = isRes ? "Residential" : "DC";
      const brdText = isBrd ? "Broadcast" : "Native";

      // 绿优 / 黄中 / 红差 的逻辑，映射到 Surge style
      let style = "good";
      if ((isRes && isBrd) || (!isRes && !isBrd)) style = "alert";
      if (!isRes && isBrd) style = "error";

      return $done({
        title: "IPPure Native Check",
        content: `${resText} • ${brdText}`,
        style,
      });
    }

    // default: info
    const location = json.city || json.region || json.country || "Unknown";
    const org = json.asOrganization || "Unknown";

    return $done({
      title: "IPPure IP Info",
      content: `${location}\n${org}`,
      style: "info",
    });

  } catch (e) {
    return doneError("IPPure", e && e.message ? e.message : "Script Error");
  }
})();
