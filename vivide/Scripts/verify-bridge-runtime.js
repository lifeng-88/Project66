#!/usr/bin/env node
/**
 * Validates bridge-test assets, vividshe runtime-config path, and optional local server.
 */
const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const BRIDGE_TEST_FILE = path.resolve(__dirname, "../Web/bridge-test/index.html");
const BRIDGE_TEST_URL = "http://127.0.0.1:5188/";
const PRIVACY_URL = "https://funny-cupcake-5aba23.netlify.app/";
const VIVIDE_RUNTIME_CONFIG_URL = "https://res.vividshe.xin/config/IOS10066.json";
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

async function checkBridgeTestAsset() {
  const html = fs.readFileSync(BRIDGE_TEST_FILE, "utf8");
  if (!html.includes("Bridge 自动测试")) {
    throw new Error("bridge-test page missing expected title");
  }
  if (!html.includes("syncAppInfo")) {
    throw new Error("bridge-test page missing syncAppInfo client");
  }
  return "bridge-test asset OK";
}

async function checkBridgeTestServer() {
  const html = await fetchText(BRIDGE_TEST_URL);
  if (!html.includes("Bridge 自动测试")) {
    throw new Error("bridge-test page missing expected title");
  }
  return "bridge-test server OK";
}

async function checkVividsheRuntimeConfig() {
  const jsonText = await fetchText(VIVIDE_RUNTIME_CONFIG_URL);
  const config = JSON.parse(jsonText);
  const api = config.apiBaseURL || config.api_base_url;
  if (!api) {
    throw new Error("vividshe runtime config JSON missing apiBaseURL");
  }
  return `vividshe runtime-config OK (api=${api})`;
}

async function checkPrivacyRuntimeConfigPath() {
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
    throw new Error("privacy runtime config JSON missing apiBaseURL");
  }
  return `privacy runtime-config OK (api=${api})`;
}

async function main() {
  const checks = [
    ["bridge-test-asset", checkBridgeTestAsset, true],
    ["bridge-test-server", checkBridgeTestServer, false],
    ["vividshe-runtime-config", checkVividsheRuntimeConfig, false],
    ["privacy-runtime-config-path", checkPrivacyRuntimeConfigPath, false],
  ];

  const results = [];
  for (const [name, fn, required] of checks) {
    try {
      const message = await fn();
      results.push({ name, ok: true, required, message });
      console.log(`PASS  ${name}: ${message}`);
    } catch (error) {
      results.push({ name, ok: false, required, message: error.message });
      const label = required ? "FAIL" : "WARN";
      console.error(`${label}  ${name}: ${error.message}`);
    }
  }

  const failedRequired = results.filter((item) => item.required && !item.ok).length;
  process.exit(failedRequired > 0 ? 1 : 0);
}

main();
