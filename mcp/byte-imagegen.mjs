#!/usr/bin/env node
/**
 * byte-imagegen — a zero-dependency MCP stdio server that bridges ByteDance's
 * Volcano Ark (Seedream / 豆包·即梦) image-generation API into a text-to-image
 * tool for DeepSeek Harness.
 *
 * Wired into DSH via the built-in `@deepseek-ai/dsh-mcp-client` plugin (stdio
 * transport). The model then sees the tool:
 *   mcp__byteimg__generate_image
 *
 * Configuration comes from environment variables (set in cordis.patch.yml):
 *   ARK_API_KEY      required — Volcano Ark API key (Bearer token)
 *   ARK_MODEL        default 'doubao-seedream-4-0-250828'
 *   ARK_BASE_URL     default 'https://ark.cn-beijing.volces.com/api/v3'
 *   IMAGE_OUTPUT_DIR base dir for saved PNGs (default D:\yyy\EE\art)
 *   IMAGE_TIMEOUT_MS generation timeout (default 120000)
 *
 * Endpoint: POST {ARK_BASE_URL}/images/generations  (OpenAI-compatible).
 * Protocol: newline-delimited JSON-RPC 2.0 over stdin/stdout. Logs go to stderr.
 */
import { createInterface } from 'node:readline';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const NAME = 'byte-imagegen';
const VERSION = '1.0.0';
const PROTOCOL_VERSION = '2024-11-05';
const BASE_URL = (process.env.ARK_BASE_URL || 'https://ark.cn-beijing.volces.com/api/v3').replace(/\/+$/, '');
const API_KEY = process.env.ARK_API_KEY || '';
const DEFAULT_MODEL = process.env.ARK_MODEL || 'doubao-seedream-4-0-250828';
const OUTPUT_DIR = process.env.IMAGE_OUTPUT_DIR || process.cwd();
const TIMEOUT_MS = Number(process.env.IMAGE_TIMEOUT_MS || 120000);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function guessMime(p) {
  const e = path.extname(p).toLowerCase();
  return { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' }[e] || 'image/png';
}

function extractArkError(data) {
  if (data?.error?.message) return `${data.error.code ?? 'error'}: ${data.error.message}`;
  if (data?.message) return data.message;
  return '';
}

async function download(url) {
  const r = await fetch(url, { signal: AbortSignal.timeout(60000) });
  if (!r.ok) throw new Error(`downloading image URL -> HTTP ${r.status}`);
  return Buffer.from(await r.arrayBuffer());
}

async function generateImage(args) {
  if (!API_KEY) {
    throw new Error('ARK_API_KEY is not set — export it in the environment before launching dsh (e.g. $env:ARK_API_KEY="...")');
  }
  const prompt = String(args.prompt ?? '').trim();
  if (!prompt) throw new Error('"prompt" is required');

  const model = String(args.model ?? DEFAULT_MODEL);
  const size = String(args.size ?? '1024x1024');

  const body = { model, prompt, size, n: 1, watermark: args.watermark === true };
  if (args.seed !== undefined && args.seed !== null) body.seed = Number(args.seed);
  if (args.guidance_scale !== undefined && args.guidance_scale !== null) body.guidance_scale = Number(args.guidance_scale);

  // Optional style/reference image (img2img): local path -> base64 data URL.
  const refPath = args.reference_image ? String(args.reference_image) : '';
  if (refPath) {
    const buf = readFileSync(refPath);
    body.image = `data:${guessMime(refPath)};base64,${buf.toString('base64')}`;
  }

  let res;
  try {
    res = await fetch(`${BASE_URL}/images/generations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${API_KEY}` },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (err) {
    throw new Error(`cannot reach Ark API at ${BASE_URL}: ${err.message}`);
  }

  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!res.ok) {
    throw new Error(`Ark images API -> HTTP ${res.status}: ${extractArkError(data) || text.slice(0, 500)}`);
  }

  const item = Array.isArray(data.data) ? data.data[0] : null;
  let bytes;
  if (item?.b64_json) bytes = Buffer.from(item.b64_json, 'base64');
  else if (item?.url) bytes = await download(item.url);
  else throw new Error(`Ark images API returned no image data: ${JSON.stringify(data).slice(0, 400)}`);

  let out = args.output_path ? String(args.output_path) : '';
  if (!out) {
    const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    out = path.join(OUTPUT_DIR, `seedream_${ts}.png`);
  } else if (!path.isAbsolute(out)) {
    out = path.join(OUTPUT_DIR, out);
  }
  mkdirSync(path.dirname(out), { recursive: true });
  writeFileSync(out, bytes);

  return {
    path: out,
    model, size,
    seed: body.seed ?? null,
    bytes: bytes.length,
    provider: 'bytedance-seedream',
  };
}

// ── Tool catalog ────────────────────────────────────────────────────────────

const TOOL_DEFS = [
  {
    name: 'generate_image',
    description:
      'Generate one image from a text prompt using ByteDance Seedream (Volcano Ark) API. ' +
      'Saves the PNG to disk and returns its absolute path plus the parameters used. ' +
      'Optionally pass reference_image (a local image path) to guide style via img2img.',
    inputSchema: {
      type: 'object',
      properties: {
        prompt: { type: 'string', description: 'The positive prompt describing the image (supports Chinese).' },
        size: { type: 'string', description: 'Image size string, e.g. 1024x1024, 2048x2048, 1280x720. Default 1024x1024.' },
        model: { type: 'string', description: 'Override the Seedream model ID (default from ARK_MODEL env).' },
        seed: { type: 'integer', description: 'RNG seed for reproducibility; omit for random.' },
        guidance_scale: { type: 'number', description: 'Optional guidance scale.' },
        watermark: { type: 'boolean', description: 'Whether to add a watermark. Default false.' },
        reference_image: { type: 'string', description: 'Local path to a style/reference image (img2img, base64-sent).' },
        output_path: { type: 'string', description: 'Where to save the PNG (absolute, or relative to the output dir).' },
      },
      required: ['prompt'],
    },
  },
];

// ── Tool dispatch ───────────────────────────────────────────────────────────

function summarize(data) {
  return `Saved image to ${data.path} (model ${data.model}, size ${data.size}, ` +
    `seed ${data.seed ?? 'random'}, ${data.bytes} bytes)`;
}

async function handleCall(params) {
  const name = params?.name;
  const args = params?.arguments ?? {};
  try {
    if (name === 'generate_image') {
      const data = await generateImage(args);
      return { content: [{ type: 'text', text: summarize(data) }], structuredContent: data };
    }
    throw new Error(`unknown tool: ${name}`);
  } catch (err) {
    return { content: [{ type: 'text', text: `[${name} failed] ${err.message}` }], isError: true };
  }
}

// ── JSON-RPC stdio loop ─────────────────────────────────────────────────────

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
rl.on('line', async (line) => {
  line = line.trim();
  if (!line) return;
  let msg;
  try { msg = JSON.parse(line); } catch { return; }

  const method = msg.method;
  if (method === 'notifications/initialized') return;
  if (method === 'notifications/cancelled') return;
  if (method === 'notifications/tools/list_changed') return;

  if (method === 'initialize') {
    const requested = typeof msg.params?.protocolVersion === 'string' ? msg.params.protocolVersion : PROTOCOL_VERSION;
    send({ jsonrpc: '2.0', id: msg.id, result: { protocolVersion: requested, capabilities: { tools: {} }, serverInfo: { name: NAME, version: VERSION } } });
    return;
  }

  if (msg.id === undefined) return;

  try {
    if (method === 'ping') {
      send({ jsonrpc: '2.0', id: msg.id, result: {} });
    } else if (method === 'tools/list') {
      send({ jsonrpc: '2.0', id: msg.id, result: { tools: TOOL_DEFS } });
    } else if (method === 'tools/call') {
      const result = await handleCall(msg.params);
      send({ jsonrpc: '2.0', id: msg.id, result });
    } else {
      send({ jsonrpc: '2.0', id: msg.id, error: { code: -32601, message: `Method not found: ${method}` } });
    }
  } catch (err) {
    send({ jsonrpc: '2.0', id: msg.id, error: { code: -32000, message: String(err.message || err) } });
  }
});

rl.on('close', () => process.exit(0));
