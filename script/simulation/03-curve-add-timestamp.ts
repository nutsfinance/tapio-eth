import fs from "fs";
import path from "path";
import { mainnet } from "viem/chains";
import { createPublicClient, http } from "viem";
require("dotenv").config();

const RPC_URLS = process.env.RPC_URLS ? process.env.RPC_URLS.split(",").map((url) => url.trim()) : [];

const clients = RPC_URLS.map((url) =>
  createPublicClient({ chain: mainnet, transport: http(url, { timeout: 300_000 }) }),
);

const FILES = [
  "script/simulation/output/usdc-usdt-curve-swaps.json",
  "script/simulation/output/usdc-usdt-curve-liquidity.json",
];

type Swap = { blockNumber: string | number; timestamp?: number; [key: string]: any };
type Event = { entry: { blockNumber: string | number; timestamp?: number; [key: string]: any } };
type DataFile = { swaps?: Swap[]; events?: Event[] };

async function runWithConcurrency<T>(items: T[], limit: number, fn: (item: T, idx: number) => Promise<void>) {
  let idx = 0;
  async function worker() {
    while (idx < items.length) {
      const current = idx++;
      await fn(items[current], current);
    }
  }
  await Promise.all(Array.from({ length: limit }, worker));
}

async function processFile(filename: string) {
  console.log(`\n Processing file: ${filename}`);
  const raw = fs.readFileSync(filename, "utf8");
  const data: DataFile = JSON.parse(raw);

  const swaps = data.swaps || [];
  const events = data.events || [];

  if (swaps.length) {
    console.log(` Found ${swaps.length} swaps...`);
    await runWithConcurrency(swaps, 10, async (swap, i) => {
      const client = clients[i % clients.length];
      const block = await client.getBlock({ blockNumber: BigInt(swap.blockNumber) });
      swap.timestamp = Number(block.timestamp);
      console.log(`swap ${i} → block ${swap.blockNumber} → ts ${swap.timestamp}`);
    });
  }

  if (events.length) {
    console.log(` Found ${events.length} liquidity events...`);
    await runWithConcurrency(events, 10, async (ev, i) => {
      const client = clients[i % clients.length];
      const block = await client.getBlock({ blockNumber: BigInt(ev.entry.blockNumber) });
      ev.entry.timestamp = Number(block.timestamp);
      console.log(`event ${i} → block ${ev.entry.blockNumber} → ts ${ev.entry.timestamp}`);
    });
  }

  const outFile = filename.replace(".json", "-with-timestamps.json");
  fs.writeFileSync(outFile, JSON.stringify(data, null, 2));
  console.log(` Done! Saved with timestamps → ${outFile}`);
}

async function main() {
  for (const file of FILES) {
    await processFile(path.resolve(file));
  }
}

main().catch(console.error);
