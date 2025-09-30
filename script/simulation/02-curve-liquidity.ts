const fs = require("fs");
const { mainnet } = require("viem/chains");
const { createPublicClient, http, parseAbi, decodeEventLog } = require("viem");
require("dotenv").config();

const RPC_URLS = process.env.RPC_URLS ? process.env.RPC_URLS.split(",").map((url) => url.trim()) : [];

const FROM_BLOCK = 23153779n;
// const TO_BLOCK = 23203779n;

// const FROM_BLOCK = 23203779n;
const TO_BLOCK = 23253779n;
const CHUNKS = 10;

// Curve ABI
const curveAbi = parseAbi([
  "event AddLiquidity(address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 invariant, uint256 token_supply)",
  "event RemoveLiquidity(address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 token_supply)",
  "event RemoveLiquidityOne(address indexed provider, int128 token_id, uint256 token_amount, uint256 coin_amount, uint256 token_supply)",
  "event RemoveLiquidityImbalance(address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 invariant, uint256 token_supply)",
]);

// Pools
const pools = [{ address: "0x4f493B7dE8aAC7d55F71853688b1F7C8F0243C85", name: "usdc-usdt" }];

const clients = RPC_URLS.map((url) =>
  createPublicClient({ chain: mainnet, transport: http(url, { timeout: 600_000 }) }),
);

function splitBlockRange(from: bigint, to: bigint, chunks: number): { from: bigint; to: bigint }[] {
  const size: bigint = (to - from + 1n) / BigInt(chunks);
  const ranges: { from: bigint; to: bigint }[] = [];
  let start: bigint = from;

  for (let i = 0; i < chunks; i++) {
    const end: bigint = i === chunks - 1 ? to : start + size - 1n;
    ranges.push({ from: start, to: end });
    start = end + 1n;
  }

  return ranges;
}

async function analyzePoolRange(pool, client, fromBlock, toBlock) {
  const allEvents = [];

  const eventsToFetch = ["AddLiquidity", "RemoveLiquidity", "RemoveLiquidityOne", "RemoveLiquidityImbalance"];

  for (const evName of eventsToFetch) {
    const logs = await client.getLogs({
      address: pool.address,
      fromBlock,
      toBlock,
      event: curveAbi.find((x) => x.type === "event" && x.name === evName),
    });

    for (const log of logs) {
      try {
        const decoded = decodeEventLog({ abi: curveAbi, data: log.data, topics: log.topics });

        const tx = await client.getTransaction({ hash: log.transactionHash });
        const receipt = await client.getTransactionReceipt({ hash: log.transactionHash });

        const gasUsed = receipt.gasUsed;
        const gasPrice = tx.gasPrice;
        const gasCostWei = gasUsed * gasPrice;

        let tokensFormatted: string[] = [];

        if (evName === "AddLiquidity" || evName === "RemoveLiquidity" || evName === "RemoveLiquidityImbalance") {
          const tokenAmounts = decoded.args.token_amounts as bigint[];
          tokensFormatted = tokenAmounts.map((a, i) => `${Number(a) / 1e6} ${i === 0 ? "USDC" : "USDT"}`);
        } else if (evName === "RemoveLiquidityOne") {
          const tokenId = Number(decoded.args.token_id);
          const coinAmount = BigInt(decoded.args.coin_amount);
          const symbol = tokenId === 0 ? "USDC" : "USDT";
          tokensFormatted = [`${Number(coinAmount) / 1e6} ${symbol}`];
        }

        const entry = {
          txHash: log.transactionHash,
          blockNumber: log.blockNumber.toString(),
          event: evName,
          args: decoded.args,
          tokens: tokensFormatted,
          gasUsed: gasUsed.toString(),
          gasPrice: gasPrice.toString(),
          gasCostWei: gasCostWei.toString(),
        };

        if (evName === "AddLiquidity") allEvents.push({ type: "add", entry });
        else allEvents.push({ type: "remove", entry });
      } catch (err) {
        console.error("decode error", err);
      }
    }
  }

  console.log(`Processed ${pool.name} from ${fromBlock} to ${toBlock} — events: ${allEvents.length}`);
  return { events: allEvents };
}

async function main() {
  for (const pool of pools) {
    const ranges = splitBlockRange(FROM_BLOCK, TO_BLOCK, CHUNKS);

    const tasks = ranges.map((range, i) => {
      const client = clients[i % clients.length];
      return analyzePoolRange(pool, client, range.from, range.to);
    });

    const resultsPerChunk = await Promise.all(tasks);

    const merged = { pool: pool.name, address: pool.address, events: [] };
    for (const chunk of resultsPerChunk) merged.events.push(...chunk.events);

    fs.writeFileSync(
      `script/simulation/output/${pool.name}-curve-liquidity.json`,
      JSON.stringify(merged, (k, v) => (typeof v === "bigint" ? v.toString() : v), 2),
    );
    console.log(`\nSaved results to ${pool.name}-curve-liquidity.json — total events: ${merged.events.length}`);
  }
}

main().catch(console.error);
