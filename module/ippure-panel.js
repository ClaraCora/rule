/**
 * Surge Information Panel Script (All-in-One CN)
 * Returns {title, content, style} via $done()
 * style: good / info / alert / error
 */

const API = "https://my.ippure.com/v1/info";
const CACHE_KEY = "ippure_cache_json";
const CACHE_TS_KEY = "ippure_cache_ts";
const CACHE_TTL_MS = 10 * 1000;

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

function fraudLevel(score) {
  if (score >= 70) return { level: "高风险", style: "error" };
  if (score >= 40) return { level: "中风险", style: "alert" };
  return { level: "低风险", style: "good" };
}

function nativeStyle(isRes, isBrd) {
  // 住宅+原生 最好；机房+广播 最差
  if (!isRes && isBrd) return "error";
  if ((isRes && isBrd) || (!isRes && !isBrd)) return "alert";
  return "good";
}

function mergeStyle(a, b) {
  // error > alert > info > good
  const rank = { error: 3, alert: 2, info: 1, good: 0 };
  return rank[a] >= rank[b] ? a : b;
}

(async () => {
  try {
    const json = await fetchInfoJson();

    const score = json.fraudScore;
    const isRes = Boolean(json.isResidential);
    const isBrd = Boolean(json.isBroadcast);

    const scoreText = (score === undefined || score === null) ? "未返回" : String(score);
    const fraud = (score === undefined || score === null) ? { level: "未知", style: "info" } : fraudLevel(Number(score));
    const netType = isRes ? "住宅 IP" : "机房/IDC IP";
    const nativeType = isBrd ? "广播/宣告 IP（Announced）" : "原生 IP（Native）";

    const style = mergeStyle(fraud.style, nativeStyle(isRes, isBrd));

    const content =
      `风险评分：${scoreText}（${fraud.level}）\n` +
      `网络类型：${netType}\n` +
      `原生判断：${nativeType}`;

    $done({
      title: "IPPure IP 检测",
      content,
      style,
    });
  } catch (e) {
    return doneError("IPPure IP 检测", e && e.message ? e.message : "脚本错误");
  }
})();
