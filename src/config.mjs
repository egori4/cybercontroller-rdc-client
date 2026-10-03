import fs from "node:fs/promises";

export async function loadConfig(env = process.env) {
  const url = env.MCP_URL?.trim();
  if (!url) {
    throw new Error("MCP_URL is required");
  }

  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error("MCP_URL must be a valid URL");
  }

  if (!["https:", "http:"].includes(parsed.protocol)) {
    throw new Error("MCP_URL must use http or https");
  }

  let token = env.MCP_BEARER_TOKEN?.trim() || "";
  const tokenFile = env.MCP_BEARER_TOKEN_FILE?.trim();

  if (!token && tokenFile) {
    try {
      token = (await fs.readFile(tokenFile, "utf8")).trim();
    } catch (error) {
      throw new Error(`Unable to read MCP bearer token file: ${error.message}`);
    }
  }

  return { url: parsed, token };
}
