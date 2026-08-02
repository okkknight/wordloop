// The VPS routes `/wordloop/api/*` to `server/index.mjs`, not to Vinext.
// This compatibility module exists only so the dormant Cloudflare route files
// can be bundled by the Node production server without Miniflare's virtual
// `cloudflare:workers` module.  It intentionally exposes process environment
// values only; it does not emulate D1.
export const env: Record<string, unknown> = process.env;
