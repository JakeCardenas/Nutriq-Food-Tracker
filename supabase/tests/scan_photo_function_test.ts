// Tests for the `scan-photo` Edge Function, run with Node's built-in runner.
// Every outside call (Supabase, Gemini, USDA FoodData Central) goes to a fake
// `fetch` — no network, no API keys, no real photos.
//
//   node --test supabase/tests/scan_photo_function_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { Buffer } from "node:buffer";

import {
  chooseFdcMatch,
  COMPARISON_MODEL,
  dailyLimitFrom,
  handle,
  MODEL,
  normalizeModelOutput,
  parseFdcFood,
  pickKey,
  stripJpegMetadata,
} from "../functions/scan-photo/index.ts";

// ── A tiny hand-built JPEG: SOI, JFIF, EXIF (with "GPS"), comment, tables, scan, EOI ──
const seg = (marker: number, payload: number[]) => [0xff, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xff, ...payload];
const ascii = (s: string) => [...s].map((c) => c.charCodeAt(0));
const JFIF = seg(0xe0, ascii("JFIF\0"));
const EXIF = seg(0xe1, ascii("Exif\0\0GPS 14.5995N 120.9842E"));
const XMP = seg(0xe1, ascii("http://ns.adobe.com/xap/1.0/\0<x:xmpmeta/>"));
const COMMENT = seg(0xfe, ascii("taken by Juan"));
const TABLES = seg(0xdb, [0, 1, 2, 3]);
const SCAN = [...seg(0xda, [1, 2, 3]), 0x11, 0x22, 0xff, 0x00, 0x33, 0xff, 0xd9];
const photo = new Uint8Array([0xff, 0xd8, ...JFIF, ...EXIF, ...XMP, ...COMMENT, ...TABLES, ...SCAN]);
const cleanPhoto = new Uint8Array([0xff, 0xd8, ...JFIF, ...TABLES, ...SCAN]);

const b64 = (bytes: Uint8Array) => Buffer.from(bytes).toString("base64");
const text = (bytes: Uint8Array) => String.fromCharCode(...bytes);

type Call = { url: string; init: RequestInit };

const modelOutput = {
  isFood: true,
  dish: "Tuna and rice",
  dishAlternatives: ["Tuna rice bowl"],
  components: [
    {
      name: "white rice, cooked",
      localName: "kanin",
      visibility: "visible",
      portionEstimable: true,
      gramsLow: 250,
      gramsHigh: 330,
      portionNote: "about 2 cups",
    },
    {
      name: "tuna, canned in oil, drained",
      localName: "",
      visibility: "visible",
      portionEstimable: false,
      gramsLow: 0,
      gramsHigh: 0,
      portionNote: "",
    },
  ],
  uncertainties: ["Oil from the can may be included"],
};

const fdcRice = {
  fdcId: 168878,
  description: "Rice, white, long-grain, regular, enriched, cooked",
  dataType: "SR Legacy",
  foodNutrients: [
    { nutrientId: 1003, nutrientNumber: "203", nutrientName: "Protein", unitName: "G", value: 2.69 },
    { nutrientId: 1004, nutrientNumber: "204", nutrientName: "Total lipid (fat)", unitName: "G", value: 0.28 },
    { nutrientId: 1005, nutrientNumber: "205", nutrientName: "Carbohydrate, by difference", unitName: "G", value: 28.17 },
    { nutrientId: 1062, nutrientNumber: "268", nutrientName: "Energy", unitName: "kJ", value: 544 },
    { nutrientId: 1008, nutrientNumber: "208", nutrientName: "Energy", unitName: "KCAL", value: 130 },
  ],
};

const usdaFood = (fdcId: number, description: string, kcal: number, protein: number, dataType = "SR Legacy") => ({
  fdcId,
  description,
  dataType,
  foodNutrients: [
    { nutrientId: 1008, nutrientNumber: "208", unitName: "KCAL", value: kcal },
    { nutrientId: 1003, nutrientNumber: "203", unitName: "G", value: protein },
  ],
});
const friedBreast = usdaFood(171477, "Chicken, broilers or fryers, breast, meat only, fried", 187, 33.44);
const friedWing = usdaFood(171482, "Chicken, broilers or fryers, wing, meat and skin, fried, flour", 321, 26.11);

function fakeBackend({
  userStatus = 200,
  remaining = 9 as number | "missing",
  gemini = { status: 200, body: { candidates: [{ content: { parts: [{ text: JSON.stringify(modelOutput) }] }, finishReason: "STOP" }] } } as
    | { status: number; body: unknown }
    | "hang",
  fdcFoods = { "white rice, cooked": [fdcRice] } as Record<string, unknown[]>,
  fdcStatus = 200,
  cachedQueries = {} as Record<string, unknown>,
} = {}) {
  const calls: Call[] = [];
  const cacheWrites: unknown[] = [];
  const fetch = async (input: string | URL | Request, init: RequestInit = {}) => {
    const url = String(input);
    calls.push({ url, init });
    const json = (body: unknown, status = 200) =>
      new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    if (url.endsWith("/auth/v1/user")) return json(userStatus === 200 ? { id: "user-1" } : { msg: "bad" }, userStatus);
    if (url.endsWith("/rest/v1/rpc/nutriq_scan_take_turn")) {
      if (remaining === "missing") return json({ code: "PGRST202" }, 404);
      return json(remaining);
    }
    if (url.includes("generativelanguage.googleapis.com")) {
      if (gemini === "hang") {
        return new Promise<Response>((_, reject) => {
          init.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
        });
      }
      return json(gemini.body, gemini.status);
    }
    if (url.includes("/rest/v1/fdc_query_cache") && (init.method ?? "GET") === "GET") {
      const q = decodeURIComponent(url.split("query=eq.")[1] ?? "");
      return json(q in cachedQueries ? [cachedQueries[q]] : []);
    }
    if (url.includes("/rest/v1/fdc_")) {
      cacheWrites.push({ url, body: JSON.parse(String(init.body)) });
      return new Response(null, { status: 201 });
    }
    if (url.startsWith("https://api.nal.usda.gov/fdc/v1/foods/search")) {
      if (fdcStatus !== 200) return json({ error: "x" }, fdcStatus);
      const q = init.body ? String(JSON.parse(String(init.body)).query) : new URL(url).searchParams.get("query") ?? "";
      return json({ foods: fdcFoods[q] ?? [] });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
  return { calls, cacheWrites, fetch: fetch as typeof globalThis.fetch };
}

const env = {
  supabaseUrl: "https://example.supabase.co",
  anonKey: "anon-key",
  serviceKey: "eyJ.service.key",
  geminiKey: "test-gemini-key",
  fdcKey: "test-fdc-key",
  dailyLimit: 10,
};

function request(body: unknown, { method = "POST", auth = "Bearer user-token" as string | null, raw = undefined as string | undefined } = {}) {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers.authorization = auth;
  return new Request("https://example.supabase.co/functions/v1/scan-photo", {
    method,
    headers,
    body: method === "POST" ? (raw ?? JSON.stringify(body)) : undefined,
  });
}

const scan = (extra: Record<string, unknown> = {}) => ({ consent: true, image: b64(photo), mimeType: "image/jpeg", ...extra });
const now = () => new Date("2026-10-07T09:30:00Z");
const run = (req: Request, b: ReturnType<typeof fakeBackend>, e: Record<string, unknown> = env, timeoutMs = 2000) =>
  handle(req, { env: e as typeof env, fetch: b.fetch, now, timeoutMs });
const geminiCalls = (b: ReturnType<typeof fakeBackend>) => b.calls.filter((c) => c.url.includes("generativelanguage"));
const turnCalls = (b: ReturnType<typeof fakeBackend>) => b.calls.filter((c) => c.url.includes("take_turn"));

// ── Request checks ──────────────────────────────────────────────────────────

test("only POST, and only for signed-in people", async () => {
  assert.equal((await run(request(null, { method: "GET" }), fakeBackend())).status, 405);
  const b = fakeBackend();
  assert.equal((await run(request(scan(), { auth: null }), b)).status, 401);
  assert.equal(b.calls.length, 0);
  const bad = fakeBackend({ userStatus: 401 });
  assert.equal((await run(request(scan()), bad)).status, 401);
  assert.equal(geminiCalls(bad).length, 0);
});

test("the sign-in is checked before the upload is read or parsed", async () => {
  const bad = fakeBackend({ userStatus: 401 });
  const req = request(null, { raw: "{ not even json" });
  assert.equal((await run(req, bad)).status, 401, "a bad token gets 401, not 400");
  assert.equal(req.bodyUsed, false, "the body was never read");
  assert.deepEqual(bad.calls.map((c) => c.url), ["https://example.supabase.co/auth/v1/user"]);

  const huge = request(null, { raw: "A".repeat(3_000_000) });
  assert.equal((await run(huge, fakeBackend({ userStatus: 401 }))).status, 401);
  assert.equal(huge.bodyUsed, false);
});

test("refuses uploads without the person's consent", async () => {
  const b = fakeBackend();
  const res = await run(request(scan({ consent: false })), b);
  assert.equal(res.status, 403);
  assert.deepEqual(await res.json(), { error: "consent_required" });
  assert.equal(turnCalls(b).length + geminiCalls(b).length, 0);
});

test("an upload declared too large is refused without reading it", async () => {
  const b = fakeBackend();
  const req = new Request("https://example.supabase.co/functions/v1/scan-photo", {
    method: "POST",
    headers: { authorization: "Bearer user-token", "content-type": "application/json", "content-length": "5000000" },
    body: "{}",
  });
  assert.equal((await run(req, b)).status, 413);
  assert.equal(req.bodyUsed, false);
  assert.equal(turnCalls(b).length + geminiCalls(b).length, 0);
});

test("an oversized upload is cut off at the limit, never buffered whole", async () => {
  const chunk = new Uint8Array(64 * 1024).fill(0x41);
  let pulled = 0;
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (pulled >= 8_000_000) return controller.close();
      pulled += chunk.length;
      controller.enqueue(chunk);
    },
    cancel() {
      cancelled = true;
    },
  });
  const b = fakeBackend();
  const req = new Request("https://example.supabase.co/functions/v1/scan-photo", {
    method: "POST",
    headers: { authorization: "Bearer user-token", "content-type": "application/json" },
    body,
    duplex: "half",
  } as RequestInit);
  assert.equal((await run(req, b)).status, 413);
  assert.ok(cancelled, "the rest of the upload is cancelled");
  assert.ok(pulled < 2_600_000, `read ${pulled} bytes`);
  assert.equal(turnCalls(b).length + geminiCalls(b).length, 0);
});

test("refuses oversized bodies and images before any allowance or provider call", async () => {
  const b = fakeBackend();
  const huge = await run(request(null, { raw: JSON.stringify(scan({ image: "A".repeat(3_000_000) })) }), b);
  assert.equal(huge.status, 413);
  const big = new Uint8Array(1_600_000);
  big.set([0xff, 0xd8, 0xff, 0xe0]);
  const tooBig = await run(request(scan({ image: b64(big) })), b);
  assert.equal(tooBig.status, 413, "the 1.5 MB image limit still applies");
  assert.equal(turnCalls(b).length + geminiCalls(b).length, 0);
});

test("refuses anything that isn't a JPEG", async () => {
  for (const image of ["not base64 !!", b64(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4])), ""]) {
    const res = await run(request(scan({ image })), fakeBackend());
    assert.equal(res.status, 400, image.slice(0, 20));
  }
  assert.equal((await run(request(scan({ mimeType: "image/png" })), fakeBackend())).status, 400);
});

test("not set up: missing Gemini key or missing allowance function → 503, no provider call", async () => {
  const noKey = fakeBackend();
  const res = await run(request(scan()), noKey, { ...env, geminiKey: undefined });
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: "not_configured" });
  assert.equal(geminiCalls(noKey).length, 0);

  const noMigration = fakeBackend({ remaining: "missing" });
  assert.equal((await run(request(scan()), noMigration)).status, 503);
  assert.equal(geminiCalls(noMigration).length, 0);
});

test("daily scan limit → 429 with the limit and reset time; Gemini not called", async () => {
  const b = fakeBackend({ remaining: -1 });
  const res = await run(request(scan()), b, { ...env, dailyLimit: 5 });
  assert.equal(res.status, 429);
  assert.deepEqual(await res.json(), { error: "daily_limit", limit: 5, resetsAt: "2026-10-08T00:00:00.000Z" });
  assert.equal(geminiCalls(b).length, 0);
  const body = JSON.parse(String(turnCalls(b)[0].init.body));
  assert.deepEqual(body, { p_limit: 5 });
});

// ── The Gemini request ──────────────────────────────────────────────────────

test("sends one metadata-free JPEG to the configured Gemini model and asks for candidates, not nutrition", async () => {
  const b = fakeBackend();
  await (await run(request(scan()), b)).json();
  const [call] = geminiCalls(b);
  assert.equal(MODEL, "gemini-3.5-flash-lite");
  assert.equal(call.url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent");
  assert.equal((call.init.headers as Record<string, string>)["x-goog-api-key"], "test-gemini-key");
  assert.ok(!call.url.includes("test-gemini-key"), "the key is never in the URL");
  const body = JSON.parse(String(call.init.body));
  const inline = body.contents[0].parts.find((p: { inlineData?: unknown }) => p.inlineData).inlineData;
  assert.equal(inline.mimeType, "image/jpeg");
  assert.equal(inline.data, b64(cleanPhoto), "EXIF, XMP and comments are removed before upload");
  assert.equal(body.generationConfig.responseMimeType, "application/json");
  const schemaText = JSON.stringify(body.generationConfig.responseJsonSchema);
  for (const banned of ["calorie", "kcal", "protein", "confidence", "probability"]) {
    assert.ok(!schemaText.toLowerCase().includes(banned), `schema must not ask for ${banned}`);
  }
  const system = body.systemInstruction.parts[0].text;
  assert.match(system, /never estimate calories/i);
  assert.match(system, /alternatives/i, "asks for alternatives instead of a forced precise name");
  assert.match(system, /exact weight/i, "doesn't claim exact weights from a photo");
  assert.equal(body.generationConfig.maxOutputTokens, 4096);
  assert.equal(body.generationConfig.thinkingConfig, undefined, "the production model keeps its default thinking");
  const item = body.generationConfig.responseJsonSchema.properties.components.items;
  assert.deepEqual(item.properties.alternatives, { type: "array", items: { type: "string" }, maxItems: 2 });
  assert.ok(item.required.includes("alternatives"));
});

test("the comparison model runs only when configured, with low thinking; unknown models fail closed", async () => {
  const b = fakeBackend();
  await (await run(request(scan()), b, { ...env, geminiModel: COMPARISON_MODEL })).json();
  const [call] = geminiCalls(b);
  assert.ok(call.url.includes(`/models/${COMPARISON_MODEL}:generateContent`));
  assert.deepEqual(JSON.parse(String(call.init.body)).generationConfig.thinkingConfig, { thinkingLevel: "low" });

  const unknown = fakeBackend();
  assert.equal((await run(request(scan()), unknown, { ...env, geminiModel: "some-other-model" })).status, 503);
  assert.equal(geminiCalls(unknown).length, 0);
});

test("returns validated candidates with USDA nutrition per 100 g and the allowance left", async () => {
  const b = fakeBackend({ remaining: 7 });
  const res = await run(request(scan()), b);
  assert.equal(res.status, 200);
  const out = await res.json();
  assert.equal(out.isFood, true);
  assert.equal(out.dish, "Tuna and rice");
  assert.deepEqual(out.dishAlternatives, ["Tuna rice bowl"]);
  assert.equal(out.remaining, 7);
  assert.equal(out.nutritionLookup, "fdc");
  assert.deepEqual(out.foods[0], {
    name: "white rice, cooked",
    localName: "kanin",
    visibility: "visible",
    alternatives: [],
    grams: { low: 250, high: 330, note: "about 2 cups" },
    fdcOptions: [],
    fdc: {
      fdcId: 168878,
      description: "Rice, white, long-grain, regular, enriched, cooked",
      dataType: "SR Legacy",
      kcal: 130,
      protein: 2.69,
      carbs: 28.17,
      fat: 0.28,
    },
  });
  assert.deepEqual(out.foods[0].fdcOptions, [], "a clear match needs no choosing");
  assert.equal(out.foods[1].grams, null, "no portion when the model can't estimate one");
  assert.equal(out.foods[1].fdc, null, "no USDA match → no nutrition, not a guess");
  assert.deepEqual(out.foods[1].fdcOptions, []);
  assert.deepEqual(out.uncertainties, ["Oil from the can may be included"]);
  assert.ok(!JSON.stringify(out).includes("candidates"), "the raw provider response is never passed on");
});

test("USDA search: a POST with the data types as an array; the key only in a header", async () => {
  const b = fakeBackend();
  await run(request(scan()), b);
  const usda = b.calls.filter((c) => c.url.includes("api.nal.usda.gov"));
  assert.ok(usda.length > 0);
  for (const c of usda) {
    assert.equal(c.url, "https://api.nal.usda.gov/fdc/v1/foods/search");
    assert.equal(c.init.method, "POST");
    assert.equal(new Headers(c.init.headers).get("x-api-key"), env.fdcKey);
    assert.equal(new Headers(c.init.headers).get("content-type"), "application/json");
    const body = JSON.parse(String(c.init.body));
    assert.deepEqual(body.dataType, ["Foundation", "SR Legacy", "Survey (FNDDS)"], "the FDC guide asks for an array");
    assert.equal(body.pageSize, 5);
    assert.ok(!JSON.stringify(body).includes(env.fdcKey), "no key in the body");
  }
  assert.deepEqual(usda.map((c) => JSON.parse(String(c.init.body)).query).sort(), [
    "tuna, canned in oil, drained",
    "white rice, cooked",
  ]);
});

test("successful USDA lookups are cached by food id; cached queries skip USDA", async () => {
  const b = fakeBackend();
  await (await run(request(scan()), b)).json();
  const food = b.cacheWrites.find((w) => (w as { url: string }).url.includes("fdc_food_cache")) as { body: Record<string, unknown> };
  assert.equal(food.body.fdc_id, 168878);
  assert.equal(food.body.kcal_100g, 130);

  const cached = fakeBackend({
    fdcFoods: {},
    cachedQueries: {
      "white rice, cooked": {
        fdc_id: 1,
        fetched_at: "2026-10-01T00:00:00Z",
        fdc_food_cache: { fdc_id: 1, description: "Cached rice", data_type: "SR Legacy", kcal_100g: 129, protein_100g: 2.7, carbs_100g: 28, fat_100g: 0.3 },
      },
    },
  });
  const out = await (await run(request(scan()), cached)).json();
  assert.equal(out.foods[0].fdc.description, "Cached rice");
  assert.equal(
    cached.calls.filter((c) => c.url.includes("foods/search") && c.url.includes("white%20rice")).length,
    0,
  );
});

test("when USDA entries disagree, the person gets the options — and the guess isn't cached", async () => {
  const chicken = {
    ...modelOutput,
    components: [{ ...modelOutput.components[0], name: "chicken, fried", localName: "" }],
  };
  const b = fakeBackend({
    gemini: { status: 200, body: { candidates: [{ content: { parts: [{ text: JSON.stringify(chicken) }] } }] } },
    fdcFoods: { "chicken, fried": [friedBreast, friedWing] },
  });
  const out = await (await run(request(scan()), b)).json();
  assert.equal(out.foods[0].fdc, null, "no macros from a food that may be the wrong one");
  assert.deepEqual(out.foods[0].fdcOptions, [
    {
      fdcId: 171477,
      description: "Chicken, broilers or fryers, breast, meat only, fried",
      dataType: "SR Legacy",
      kcal: 187,
      protein: 33.44,
      carbs: null,
      fat: null,
    },
    {
      fdcId: 171482,
      description: "Chicken, broilers or fryers, wing, meat and skin, fried, flour",
      dataType: "SR Legacy",
      kcal: 321,
      protein: 26.11,
      carbs: null,
      fat: null,
    },
  ]);
  assert.equal(b.cacheWrites.length, 0, "an ambiguous answer is looked up again next time");
});

test("without an FDC key the scan still works and says nutrition lookup isn't set up", async () => {
  const b = fakeBackend();
  const out = await (await run(request(scan()), b, { ...env, fdcKey: undefined })).json();
  assert.equal(out.nutritionLookup, "not_configured");
  assert.equal(out.foods[0].fdc, null);
  assert.equal(b.calls.filter((c) => c.url.includes("api.nal.usda.gov")).length, 0);
});

test("USDA rate limits don't break the scan", async () => {
  const out = await (await run(request(scan()), fakeBackend({ fdcStatus: 429 }))).json();
  assert.equal(out.foods[0].fdc, null);
  assert.equal(out.nutritionLookup, "unavailable");
});

// ── Provider failures ───────────────────────────────────────────────────────

test("provider quota, errors, junk and timeouts are told apart", async () => {
  const quota = await run(request(scan()), fakeBackend({ gemini: { status: 429, body: { error: { status: "RESOURCE_EXHAUSTED" } } } }));
  assert.equal(quota.status, 503);
  assert.deepEqual(await quota.json(), { error: "provider_quota" });

  const down = await run(request(scan()), fakeBackend({ gemini: { status: 500, body: {} } }));
  assert.equal(down.status, 502);
  assert.deepEqual(await down.json(), { error: "provider_error" });

  const junk = await run(request(scan()), fakeBackend({ gemini: { status: 200, body: { candidates: [{ content: { parts: [{ text: "not json" }] } }] } } }));
  assert.equal(junk.status, 502);

  const blocked = await run(request(scan()), fakeBackend({ gemini: { status: 200, body: { promptFeedback: { blockReason: "SAFETY" } } } }));
  assert.equal(blocked.status, 502);

  const slow = await run(request(scan()), fakeBackend({ gemini: "hang" }), env, 50);
  assert.equal(slow.status, 504);
  assert.deepEqual(await slow.json(), { error: "timeout" });
});

test("never logs the photo, the prompt or the provider's answer", async () => {
  const logged: string[] = [];
  const original = { log: console.log, error: console.error, warn: console.warn, info: console.info };
  for (const k of ["log", "error", "warn", "info"] as const) console[k] = (...a: unknown[]) => logged.push(a.map(String).join(" "));
  try {
    await run(request(scan()), fakeBackend({ gemini: { status: 500, body: { error: { message: "secret detail" } } } }));
    await run(request(scan()), fakeBackend());
    await run(request(scan()), fakeBackend({ fdcStatus: 500 }));
  } finally {
    Object.assign(console, original);
  }
  const all = logged.join("\n");
  assert.ok(!all.includes(b64(photo).slice(0, 40)));
  assert.ok(!all.includes("Tuna and rice"));
  assert.ok(!all.includes("secret detail"));
  assert.ok(!all.toLowerCase().includes("do not estimate calories"));
  assert.ok(!all.includes("test-gemini-key") && !all.includes("test-fdc-key"));
});

// ── Helpers ─────────────────────────────────────────────────────────────────

test("stripJpegMetadata keeps the picture, drops EXIF/XMP/comments, rejects non-JPEGs", () => {
  const stripped = stripJpegMetadata(photo)!;
  assert.deepEqual([...stripped], [...cleanPhoto]);
  assert.ok(!text(stripped).includes("Exif") && !text(stripped).includes("GPS") && !text(stripped).includes("Juan"));
  assert.equal(stripJpegMetadata(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), null);
  assert.equal(stripJpegMetadata(photo.slice(0, 12)), null, "truncated segment");
});

test("normalizeModelOutput: 8 visible + 4 hidden at most, deduped, nothing nutrition-like", () => {
  const visible = (i: number) => ({
    name: `food ${i}`,
    localName: "",
    visibility: "visible",
    alternatives: [],
    portionEstimable: true,
    gramsLow: i === 1 ? 300 : 100,
    gramsHigh: i === 1 ? 100 : 5000,
    portionNote: "x".repeat(200),
    calories: 300,
    confidence: 0.99,
  });
  const hidden = (i: number) => ({
    name: `hidden ${i}`,
    localName: "",
    visibility: "inferred",
    portionEstimable: true,
    gramsLow: 10,
    gramsHigh: 20,
    portionNote: "",
  });
  const out = normalizeModelOutput({
    isFood: true,
    dish: "  Adobo  ",
    dishAlternatives: ["Adobo", "Menudo", "Afritada", "Kaldereta", "Mechado"],
    calories: 900,
    components: [
      ...Array.from({ length: 10 }, (_, i) => visible(i)),
      { ...visible(0) },
      { name: "   ", localName: "", visibility: "visible", portionEstimable: false, gramsLow: 0, gramsHigh: 0, portionNote: "" },
    ],
    inferredIngredients: Array.from({ length: 6 }, (_, i) => hidden(i)),
    uncertainties: ["a", "b", "c", "d", "e", "f", "g"],
  })!;
  assert.equal(out.dish, "Adobo");
  assert.deepEqual(out.dishAlternatives, ["Menudo", "Afritada", "Kaldereta"]);
  const seen = out.components.filter((c) => c.visibility === "visible");
  const hiddenOut = out.components.filter((c) => c.visibility === "inferred");
  assert.equal(seen.length, 8, "at most 8 visible foods");
  assert.equal(hiddenOut.length, 4, "at most 4 hidden ingredients, kept apart from visible foods");
  assert.equal(new Set(seen.map((c) => c.name)).size, 8, "the duplicate is dropped");
  assert.deepEqual(seen[0].grams, { low: 100, high: 1500, note: "x".repeat(60) });
  assert.deepEqual(seen[1].grams, { low: 100, high: 300, note: "x".repeat(60) }, "swapped range is fixed");
  assert.ok(hiddenOut.every((c) => c.grams === null), "hidden ingredients get no portion");
  assert.equal(out.uncertainties.length, 5);
  const json = JSON.stringify(out);
  assert.ok(!json.includes("calories") && !json.includes("confidence"));

  const unsure = normalizeModelOutput({ isFood: true, components: [{ ...visible(0), visibility: "seen?" }] })!;
  assert.equal(unsure.components[0].visibility, "inferred", "unknown visibility is treated as not seen");

  assert.deepEqual(normalizeModelOutput({ isFood: false, dish: "Cat", components: [{ name: "cat" }] })!.components, []);
  assert.equal(normalizeModelOutput("nope"), null);
});

test("normalizeModelOutput: per-food alternatives, cleaned and capped", () => {
  const out = normalizeModelOutput({
    isFood: true,
    components: [{
      name: "chicken adobo",
      localName: "adobong manok",
      visibility: "visible",
      alternatives: ["Pork adobo", "CHICKEN ADOBO", "  ", "pork adobo", "Humba", "Pares"],
      portionEstimable: false,
      gramsLow: 0,
      gramsHigh: 0,
      portionNote: "",
    }],
    inferredIngredients: [{ name: "cooking oil", localName: "", alternatives: ["butter"], portionEstimable: false }],
  })!;
  assert.deepEqual(out.components[0].alternatives, ["Pork adobo", "Humba"], "≤ 2, no repeats, not the name itself");
  assert.deepEqual(out.components[1].alternatives, [], "hidden ingredients have no alternatives");
});

test("normalizeModelOutput: a photo can't give an exact weight, so tight ranges are widened", () => {
  const range = (low: number, high: number) =>
    normalizeModelOutput({
      isFood: true,
      components: [{
        name: "rice",
        localName: "",
        visibility: "visible",
        alternatives: [],
        portionEstimable: true,
        gramsLow: low,
        gramsHigh: high,
        portionNote: "",
      }],
    })!.components[0].grams;
  assert.deepEqual(range(250, 250), { low: 225, high: 275, note: "" }, "same middle, ±10 %");
  assert.deepEqual(range(240, 260), { low: 225, high: 275, note: "" });
  assert.deepEqual(range(250, 330), { low: 250, high: 330, note: "" }, "honest ranges are kept");
});

test("parseFdcFood reads kcal, else Atwater energy; needs energy and protein", () => {
  assert.equal(parseFdcFood(fdcRice)!.kcal, 130);
  const foundation = {
    fdcId: 2,
    description: "Eggs, whole, raw",
    dataType: "Foundation",
    foodNutrients: [
      { nutrientId: 2048, nutrientNumber: "958", unitName: "KCAL", value: 148 },
      { nutrientId: 1003, nutrientNumber: "203", unitName: "G", value: 12.4 },
    ],
  };
  assert.equal(parseFdcFood(foundation)!.kcal, 148);
  assert.equal(parseFdcFood({ ...foundation, foodNutrients: [foundation.foodNutrients[0]] }), null, "no protein");
  assert.equal(
    parseFdcFood({ fdcId: 3, description: "x", dataType: "SR Legacy", foodNutrients: [{ number: 208, amount: 50, unitName: "kcal" }, { number: 203, amount: 1, unitName: "g" }] })!.kcal,
    50,
    "abridged field names",
  );
});

test("chooseFdcMatch: a USDA entry is used only when it's clearly the same food", () => {
  const rice = chooseFdcMatch("white rice, cooked", [
    fdcRice,
    usdaFood(169756, "Rice, white, short-grain, enriched, cooked", 130, 2.36),
  ]);
  assert.equal(rice.food?.fdcId, 168878, "every word matches and the entries agree");
  assert.deepEqual(rice.options, []);

  assert.equal(
    chooseFdcMatch("potatoes, boiled", [usdaFood(170438, "Potatoes, boiled, cooked in skin, flesh, without salt", 87, 1.87)])
      .food?.fdcId,
    170438,
    "plurals match",
  );
  assert.equal(
    chooseFdcMatch("jalapeño peppers", [usdaFood(168576, "Peppers, jalapeno, raw", 29, 0.91)]).food?.fdcId,
    168576,
    "accents match",
  );
});

test("chooseFdcMatch: entries that would change the numbers are offered, not picked", () => {
  const m = chooseFdcMatch("chicken, fried", [friedBreast, friedWing]);
  assert.equal(m.food, null);
  assert.deepEqual(m.options.map((o) => o.fdcId), [171477, 171482]);

  const five = [friedBreast, friedWing, friedBreast, friedWing, friedBreast].map((f, i) => ({ ...f, fdcId: i + 1 }));
  assert.equal(chooseFdcMatch("chicken, fried", five).options.length, 4, "at most 4 to choose from");
});

test("chooseFdcMatch: a partial match is only offered; unrelated results give nothing", () => {
  const steamed = chooseFdcMatch("steamed white rice", [fdcRice]);
  assert.equal(steamed.food, null, "the entry doesn't say steamed");
  assert.deepEqual(steamed.options.map((o) => o.fdcId), [168878]);

  const sauce = chooseFdcMatch("brown sauce", [usdaFood(169704, "Rice, brown, long-grain, cooked", 123, 2.74)]);
  assert.equal(sauce.food, null);
  assert.deepEqual(sauce.options, [], "brown rice is not a kind of sauce");

  assert.deepEqual(chooseFdcMatch("white rice, cooked", [{ fdcId: 9, description: "Rice, white, cooked" }]), {
    food: null,
    options: [],
  }, "entries without calories and protein are skipped");
});

test("SCAN_DAILY_LIMIT is read safely and keys prefer the new key system", () => {
  assert.equal(dailyLimitFrom("25"), 25);
  assert.equal(dailyLimitFrom(undefined), 10);
  assert.equal(dailyLimitFrom("abc"), 10);
  assert.equal(dailyLimitFrom("0"), 1);
  assert.equal(dailyLimitFrom("999"), 200);
  assert.equal(pickKey('{"default":"sb_secret_x"}', "legacy"), "sb_secret_x");
  assert.equal(pickKey(undefined, "legacy"), "legacy");
  assert.equal(pickKey("{}", undefined), "");
});
