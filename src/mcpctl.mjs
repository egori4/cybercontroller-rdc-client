#!/usr/bin/env node
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { loadConfig } from "./config.mjs";

function usage() {
  console.error(`Usage:
  mcpctl health
  mcpctl tools
  mcpctl call <tool-name> [json-arguments]

Environment:
  MCP_URL                  Streamable HTTP MCP endpoint
  MCP_BEARER_TOKEN         Optional bearer token
  MCP_BEARER_TOKEN_FILE    Recommended bearer-token file path
  MCP_CA_CERT_FILE         Optional CA file; entrypoint maps this to NODE_EXTRA_CA_CERTS
`);
}

function parseArguments(text) {
  if (!text) return {};
  const value = JSON.parse(text);
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new Error("Tool arguments must be a JSON object");
  }
  return value;
}

async function main() {
  const [command, toolName, jsonArgs] = process.argv.slice(2);
  if (!command || !["health", "tools", "call"].includes(command)) {
    usage();
    process.exitCode = 2;
    return;
  }

  if (command === "call" && !toolName) {
    usage();
    process.exitCode = 2;
    return;
  }

  const { url, token } = await loadConfig();
  const headers = token ? { Authorization: `Bearer ${token}` } : {};

  const transport = new StreamableHTTPClientTransport(url, {
    requestInit: { headers }
  });

  const client = new Client(
    { name: "rdc-client-mcpctl", version: "0.1.0" },
    { capabilities: {} }
  );

  try {
    await client.connect(transport);

    if (command === "health") {
      const result = await client.listTools();
      console.log(JSON.stringify({
        ok: true,
        endpoint: url.origin + url.pathname,
        toolCount: result.tools.length
      }, null, 2));
      return;
    }

    if (command === "tools") {
      const result = await client.listTools();
      console.log(JSON.stringify(result, null, 2));
      return;
    }

    const args = parseArguments(jsonArgs);
    const result = await client.callTool({
      name: toolName,
      arguments: args
    });
    console.log(JSON.stringify(result, null, 2));
  } finally {
    await client.close().catch(() => {});
  }
}

main().catch((error) => {
  console.error(`mcpctl: ${error.message}`);
  process.exitCode = 1;
});
