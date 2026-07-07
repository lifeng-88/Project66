#!/usr/bin/env node
/**
 * Validates bridge-test runtime-config path (privacyURL AES decrypt)
 * and bridge-test static server availability.
 */
const http = require("http");
const https = require("https");
const crypto = require("crypto");

const PRIVACY_URL = "https://funny-cupcake-5aba23.netlify.app/";
const BRIDGE_TEST_URL = "http://127.0.0.1:5188/";
const IV_HEX = "68164836720cf037b63c181eb9ffb255";
const AES_KEY = "secretkey0166755secretkey0166755";

function fetchText(url) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith("https") ? https : http;
    lib
      .get(url, { headers: { Accept: "text/html,application/json" } }, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve(body);
          } else {
            reject(new Error(`HTTP ${res.statusCode} for ${url}`));
          }
        });
      })
      .on("error", reject);
  });
}

function aes256CbcDecrypt(ciphertextBase64, keyStr, ivHex) {
  const iv = Buffer.from(ivHex, "hex");
  const key = Buffer.from(keyStr, "utf8");
  const ciphertext = Buffer.from(ciphertextBase64.trim(), "base64");
  const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString("utf8");
}

async function checkBridgeTestServer() {
  const html = await fetchText(BRIDGE_TEST_URL);
  if (!html.includes("Bridge 自动测试")) {
    throw new Error("bridge-test page missing expected title");
  }
  return "bridge-test server OK";
}

async function checkRuntimeConfigPath() {
  const html = await fetchText(PRIVACY_URL);
  const match = html.match(/<[^>]+style\s*=\s*"[^"]*#00000000[^"]*"[^>]*>([\s\S]*?)<\/\w+>/i);
  if (!match || !match[1]) {
    throw new Error("privacyURL missing #00000000 hidden tag");
  }
  const decryptedURL = aes256CbcDecrypt(match[1], AES_KEY, IV_HEX).trim();
  if (!/^https?:\/\//i.test(decryptedURL)) {
    throw new Error(`decrypted runtime config URL invalid: ${decryptedURL}`);
  }
  const jsonText = await fetchText(decryptedURL);
  const config = JSON.parse(jsonText);
  const api = config.apiBaseURL || config.api_base_url;
  if (!api) {
    throw new Error("runtime config JSON missing apiBaseURL");
  }
  return `runtime-config OK (api=${api})`;
}

async function main() {
  const results = [];
  for (const [name, fn] of [
    ["bridge-test-server", checkBridgeTestServer],
    ["runtime-config-path", checkRuntimeConfigPath],
  ]) {
    try {
      const message = await fn();
      results.push({ name, ok: true, message });
      console.log(`PASS  ${name}: ${message}`);
    } catch (error) {
      results.push({ name, ok: false, message: error.message });
      console.error(`FAIL  ${name}: ${error.message}`);
    }
  }
  const failed = results.filter((item) => !item.ok).length;
  process.exit(failed > 0 ? 1 : 0);
}

main();
