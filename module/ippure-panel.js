/**
 * Surge Information Panel Script (CN)
 * Returns {title, content, style} via $done()
 * style: good / info / alert / error
 */

const API = "https://my.ippure.com/v1/info";
const CACHE_KEY = "ippure_cache_json";
const CACHE_TS_KEY = "ippure_cache_ts";
const CACHE_TTL_MS = 10 * 1000;

function parseArgs(raw) {
  if (!raw) return {};
  raw = String(raw).trim();
  const out = {};
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
  const now = Date.now();
  const ts = Number($persistentStore.read(CACHE_TS_KEY) || "0");
  const cached = $persistentStore.read(CACHE_KEY);

  if (cached && ts && (now - ts) < CACHE_TTL_MS) {
    try { return JSON.parse(cached); } catch (_) {}
  }

  const { error, data } = await httpGet(API);
  if (error || !data) throw new Error("网络请求失败");

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
  const mode = (args.mode || "fraud").toLowerCase();

  try {
    const json = await fetchInfoJson();

    if (mode === "fraud") {
      const score = json.fraudScore;
      if (score === undefined || score === null) {
        return $done({ title: "IPPure 风险评分", content: "未返回评分", style: "error" });
      }

      // 评分分级（沿用你原脚本逻辑的阈值观感：低/中/高）
      let level = "低风险";
      let style = "good";
      if (score >= 40 && score < 70) { level = "中风险"; style = "alert"; }
      if (score >= 70) { level = "高风险"; style = "error"; }

      return $done({
        title: "IPPure 风险评分",
        content: `风险评分：${score}\n风险等级：${level}`,
        style,
      });
    }

    if (mode === "native") {
      const isRes = Boolean(json.isResidential);
      const isBrd = Boolean(json.isBroadcast);

      const line1 = `网络类型：${isRes ? "住宅 IP" : "机房/IDC IP"}`;
      const line2 = `原生判断：${isBrd ? "广播/宣告 IP（Announced）" : "原生 IP（Native）"}`;

      // 显示样式：越“干净”越绿
      let style = "good";         // 住宅 + 原生
      if ((isRes && isBrd) || (!isRes && !isBrd)) style = "alert"; // 介于中间
      if (!isRes && isBrd) style = "error";      // 机房 + 广播（最不理想）

      return $done({
        title: "IPPure 原生/住宅判断",
        content: `${line1}\n${line2}`,
        style,
      });
    }

    return $done({ title: "IPPure", content: "未知模式参数", style: "error" });

  } catch (e) {
    return doneError("IPPure", e && e.message ? e.message : "脚本错误");
  }
})();
