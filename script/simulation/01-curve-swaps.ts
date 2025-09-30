const fs = require("fs");
const { mainnet } = require("viem/chains");
const { createPublicClient, http, parseAbi, decodeEventLog, decodeFunctionData } = require("viem");
require("dotenv").config();

const RPC_URLS = process.env.RPC_URLS ? process.env.RPC_URLS.split(",").map((url) => url.trim()) : [];

// const FROM_BLOCK = 23153779n;
// const TO_BLOCK = 23203779n;

const FROM_BLOCK = 23203779n;
const TO_BLOCK = 23253779n;
const CHUNKS = 10;

// Curve ABI
const curveAbi = parseAbi([
  "function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) returns (uint256)",
  "function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) returns (uint256)",
  "function exchange_received(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) returns (uint256)",
  "function get_dy(int128 i, int128 j, uint256 dx) view returns (uint256)",
  "function coins(uint256) view returns (address)",
  "function fee() view returns (uint256)",
  "event TokenExchange(address indexed buyer, int128 sold_id, uint256 tokens_sold, int128 bought_id, uint256 tokens_bought)",
]);

const erc20Abi = parseAbi(["function decimals() view returns (uint8)", "function symbol() view returns (string)"]);

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

async function readCoinAddress(client, pool, idx, blockNumber) {
  return client.readContract({
    address: pool,
    abi: curveAbi,
    functionName: "coins",
    args: [BigInt(idx)],
    blockNumber,
  });
}

async function readTokenMeta(client, token, blockNumber) {
  const [decimals, symbol] = await Promise.all([
    client.readContract({ address: token, abi: erc20Abi, functionName: "decimals", blockNumber }),
    client.readContract({ address: token, abi: erc20Abi, functionName: "symbol", blockNumber }).catch(() => ""),
  ]);
  return { decimals: Number(decimals), symbol };
}

function formatAmount(x, decimals) {
  const d = BigInt(decimals);
  const base = 10n ** d;
  const whole = x / base;
  const frac = x % base;
  const fracStr = frac.toString().padStart(Number(d), "0").slice(0, 6).replace(/0+$/, "");
  return fracStr ? `${whole}.${fracStr}` : whole.toString();
}

async function analyzePoolRange(pool, client, fromBlock, toBlock) {
  const logs = await client.getLogs({
    address: pool.address,
    fromBlock,
    toBlock,
    event: curveAbi.find((x) => x.type === "event" && x.name === "TokenExchange"),
  });

  console.log(`Processing ${pool.name} from ${fromBlock} to ${toBlock} — swaps: ${logs.length}`);

  const swaps = [];

  for (const log of logs) {
    const receipt = await client.getTransactionReceipt({ hash: log.transactionHash });
    const gasUsed = receipt.gasUsed;
    const gasPrice = receipt.effectiveGasPrice || receipt.gasPrice;
    const gasCostWei = gasUsed * gasPrice;

    const ev = decodeEventLog({ abi: curveAbi, data: log.data, topics: log.topics });
    const { buyer, sold_id, tokens_sold, bought_id, tokens_bought } = ev.args;

    let decodedInput = { functionName: "not found", args: [] };
    try {
      const trace = await client.request({ method: "trace_transaction", params: [log.transactionHash] });
      for (const c of trace || []) {
        try {
          const d = decodeFunctionData({ abi: curveAbi, data: c.action.input });
          if (d.functionName.startsWith("exchange")) {
            decodedInput = d;
            break;
          }
        } catch {}
      }
    } catch {}

    const prevBlock = log.blockNumber > 0n ? log.blockNumber - 1n : log.blockNumber;

    let coinI, coinJ, metaI, metaJ;
    try {
      [coinI, coinJ] = await Promise.all([
        readCoinAddress(client, pool.address, Number(sold_id), prevBlock),
        readCoinAddress(client, pool.address, Number(bought_id), prevBlock),
      ]);
      [metaI, metaJ] = await Promise.all([
        readTokenMeta(client, coinI, prevBlock),
        readTokenMeta(client, coinJ, prevBlock),
      ]);
    } catch {}

    let expectedDy = null;
    try {
      expectedDy = await client.readContract({
        address: pool.address,
        abi: curveAbi,
        functionName: "get_dy",
        args: [sold_id, bought_id, tokens_sold],
        blockNumber: prevBlock,
      });
    } catch {}

    let slippagePct = "n/a";
    if (expectedDy && expectedDy > 0n) {
      const slip = (Number(expectedDy - tokens_bought) / Number(expectedDy)) * 100;
      slippagePct = `${slip.toFixed(4)}%`;
    }

    swaps.push({
      txHash: log.transactionHash,
      buyer,
      tokens_sold: metaI ? formatAmount(tokens_sold, metaI.decimals) + " " + metaI.symbol : tokens_sold.toString(),
      tokens_bought: metaJ
        ? formatAmount(tokens_bought, metaJ.decimals) + " " + metaJ.symbol
        : tokens_bought.toString(),
      decodedInput,
      expectedQuote: expectedDy && metaJ ? formatAmount(expectedDy, metaJ.decimals) + " " + metaJ.symbol : "n/a",
      slippage: slippagePct,
      gasUsed: gasUsed.toString(),
      gasPrice: gasPrice.toString(),
      gasCostWei: gasCostWei.toString(),
      blockNumber: log.blockNumber.toString(),
    });
  }

  return { swaps };
}

async function main() {
  for (const pool of pools) {
    const ranges = splitBlockRange(FROM_BLOCK, TO_BLOCK, CHUNKS);
    const tasks = ranges.map((range, i) => {
      const client = clients[i % clients.length];
      return analyzePoolRange(pool, client, range.from, range.to);
    });

    const resultsPerChunk = await Promise.all(tasks);

    const merged = { pool: pool.name, address: pool.address, swaps: [] };
    for (const chunk of resultsPerChunk) merged.swaps.push(...chunk.swaps);

    fs.writeFileSync(
      `script/simulation/output/${pool.name}-curve-swaps.json`,
      JSON.stringify(merged, (k, v) => (typeof v === "bigint" ? v.toString() : v), 2),
    );
    console.log(`\nSaved results to ${pool.name}-curve-swaps.json — total swaps: ${merged.swaps.length}`);
  }
}

main().catch(console.error);
