#!/usr/bin/env node
/**
 * pollinations-imagegen — a zero-dependency MCP stdio server that bridges
 * Pollinations.ai (a free, no-key, no-signup image API backed by Flux) into a
 * text-to-image tool for DeepSeek Harness.
 *
 * Wired into DSH via the built-in `@deepseek-ai/dsh-mcp-client` plugin (stdio
 * transport). The model then sees the tool:
 *   mcp__pollinations__generate_image
 *
 * No API key, no account, no GPU — just an outbound HTTPS call. Environment:
 *   IMAGE_OUTPUT_DIR base dir for saved PNGs (default D:\yyy\EE\art)
 *   IMAGE_TIMEOUT_MS generation timeout (default 180000)
 *
 * Endpoint: GET https://image.pollinations.ai/prompt/{prompt}?width=..&height=..&model=flux&nologo=true
 * Protocol: newline-delimited JSON-RPC 2.0 over stdin/stdout. Logs go to stderr.
 */
import { createInterface } from 'node:readline';
import { writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const NAME = 'pollinations-imagegen';
const VERSION = '1.0.0';
const PROTOCOL_VERSION = '2024-11-05';
const BASE = 'https://image.pollinations.ai';
const OUTPUT_DIR = process.env.IMAGE_OUTPUT_DIR || process.cwd();
const TIMEOUT_MS = Number(process.env.IMAGE_TIMEOUT_MS || 180000);

function clampInt(v, min, max) {
  let n = Math.round(Number(v));
  if (!Number.isFinite(n)) n = min;
  return Math.max(min, Math.min(max, n));
}

async function generateImage(args) {
  const prompt = String(args.prompt ?? '').trim();
  if (!prompt) throw new Error('"prompt" is required');

  const width = clampInt(args.width ?? 1024, 64, 4096);
  const height = clampInt(args.height ?? 1024, 64, 4096);
  const model = String(args.model ?? 'flux');

  const qs = new URLSearchParams({ width: String(width), height: String(height), model, nologo: 'true' });
  if (args.seed !== undefined && args.seed !== null) qs.set('seed', String(args.seed));
  if (args.enhance === true) qs.set('enhance', 'true');
  if (args.negative) qs.set('negative', String(args.negative));

  const url = `${BASE}/prompt/${encodeURIComponent(prompt)}?${qs.toString()}`;
  let res;
  try {
    res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (err) {
    throw new Error(`cannot reach Pollinations: ${err.message}`);
  }
  if (!res.ok) {
    const t = await res.text().catch(() => '');
    throw new Error(`Pollinations -> HTTP ${res.status}: ${t.slice(0, 400)}`);
  }

  const bytes = Buffer.from(await res.arrayBuffer());
  const ct = res.headers.get('content-type') || '';
  const ext = ct.includes('png') ? '.png' : ct.includes('webp') ? '.webp' : '.jpg';

  let out = args.output_path ? String(args.output_path) : '';
  if (!out) {
    const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    out = path.join(OUTPUT_DIR, `pollinations_${ts}${ext}`);
  } else if (!path.isAbsolute(out)) {
    out = path.join(OUTPUT_DIR, out);
  }
  mkdirSync(path.dirname(out), { recursive: true });
  writeFileSync(out, bytes);

  return { path: out, model, width, height, seed: args.seed ?? null, bytes: bytes.length, provider: 'pollinations' };
}

// ── Tool catalog ────────────────────────────────────────────────────────────

const TOOL_DEFS = [
  {
    name: 'generate_image',
    description:
      'Generate one image from a text prompt using the free Pollinations.ai API (Flux-backed). ' +
      'No API key is required. Saves the image to disk and returns its absolute path plus parameters used.',
    inputSchema: {
      type: 'object',
      properties: {
        prompt: { type: 'string', description: 'The positive prompt describing the image (supports Chinese).' },
        width: { type: 'integer', description: 'Image width in px. Default 1024.' },
        height: { type: 'integer', description: 'Image height in px. Default 1024.' },
        model: { type: 'string', description: 'Model name. Default flux (also supports turbo for faster/lower quality).' },
        seed: { type: 'integer', description: 'RNG seed for reproducibility; omit for random.' },
        enhance: { type: 'boolean', description: 'Ask Pollinations to auto-improve the prompt. Default false.' },
        negative: { type: 'string', description: 'Optional negative prompt.' },
        output_path: { type: 'string', description: 'Where to save the image (absolute, or relative to the output dir).' },
      },
      required: ['prompt'],
    },
  },
];

// ── Tool dispatch ───────────────────────────────────────────────────────────

function summarize(data) {
  return `Saved image to ${data.path} (model ${data.model}, ${data.width}x${data.height}, ` +
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
