import test from "node:test";
import assert from "node:assert/strict";
import { loadConfig } from "../src/config.mjs";

test("requires MCP_URL", async () => {
  await assert.rejects(() => loadConfig({}), /MCP_URL is required/);
});

test("accepts HTTPS URL and optional token", async () => {
  const config = await loadConfig({
    MCP_URL: "https://example.test:8443/mcp",
    MCP_BEARER_TOKEN: "secret"
  });
  assert.equal(config.url.href, "https://example.test:8443/mcp");
  assert.equal(config.token, "secret");
});

test("rejects unsupported URL schemes", async () => {
  await assert.rejects(
    () => loadConfig({ MCP_URL: "file:///tmp/mcp" }),
    /must use http or https/
  );
});
