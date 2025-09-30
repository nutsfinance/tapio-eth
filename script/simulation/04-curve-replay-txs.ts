const fs = require("fs");
const { mainnet } = require("viem/chains");
const { createPublicClient, createWalletClient, http, parseAbi, encodeFunctionData, decodeEventLog } = require("viem");

// run in fork
const RPC = "http://127.0.0.1:8545";

const CURVE_LIQUIDITY_RESULTS = "script/simulation/output/usdc-usdt-curve-liquidity-with-timestamps.json";
const CURVE_SWAPS_RESULTS = "script/simulation/output/usdc-usdt-curve-swaps-with-timestamps.json";
const CONFIG_JSON = "script/simulation/input/config.json";
const TAPIO_ADDRESS = "0xF917ABA20710B63bD6FFafB304145C41Ff52906a"; // deployed Tapio pool on fork
const WHALE = "0x3a3C006053a9B40286B9951A11bE4C5808c11dc8";
const CURVE_POOL = "0x4f493B7dE8aAC7d55F71853688b1F7C8F0243C85";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const ADMIN = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const KEEPER_ADDRESS = "0x4bEeB6380977d7A106dBec95212b2Ad938533Eb3";

const tapioAbi = parseAbi([
  "function mint(uint256[] calldata _amounts, uint256 _minMintAmount) external returns (uint256)",
  "function swap(uint256 _i,uint256 _j,uint256 _dx,uint256 _minDy) external returns (uint256)",
  "function redeemProportion(uint256 _amount,uint256[] calldata _minRedeemAmounts) external returns (uint256[] memory)",
  "function redeemSingle(uint256 _amount,uint256 _i,uint256 _minRedeemAmount) external returns (uint256)",
  "function redeemMulti(uint256[] calldata _amounts,uint256 _maxRedeemAmount) external returns (uint256[] memory)",
  "event TokenSwapped(address indexed buyer, uint256 swapAmount, uint256[] amounts, uint256 feeAmount)",
]);

const keeperAbi = parseAbi([
  "function setSwapFee(uint256 newFee) external",
  "function rampA(uint256 newA, uint256 endTime) external",
]);

const erc20Abi = parseAbi([
  "function approve(address spender,uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function transfer(address to,uint256 amount) external returns (bool)",
  "function decimals() view returns (uint8)",
]);

let swapCounter = 0;
let publicClient: any;
let whaleClient: any;

async function approveIfNeeded(token: `0x${string}`, spender: `0x${string}`, amount: bigint) {
  const allowance = await publicClient.readContract({
    address: token,
    abi: erc20Abi,
    functionName: "allowance",
    args: [WHALE, spender],
  });
  if (allowance < amount) {
    const hash = await whaleClient.writeContract({
      address: token,
      abi: erc20Abi,
      functionName: "approve",
      args: [spender, BigInt("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")],
    });
    await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Approved ${token} for ${spender}`);
  }
}

async function getCurveBalances(curvePool: `0x${string}`) {
  const usdcBal = await publicClient.readContract({
    address: USDC,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [curvePool],
  });
  const usdtBal = await publicClient.readContract({
    address: USDT,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [curvePool],
  });
  console.log("Curve balances at snapshot:", usdcBal.toString(), usdtBal.toString());
  return [usdcBal, usdtBal];
}

async function mintToTapio(usdcAmount: bigint, usdtAmount: bigint) {
  await approveIfNeeded(USDC, TAPIO_ADDRESS, usdcAmount);
  await approveIfNeeded(USDT, TAPIO_ADDRESS, usdtAmount);

  const amounts = [usdcAmount, usdtAmount];
  const hash = await whaleClient.writeContract({
    address: TAPIO_ADDRESS,
    abi: tapioAbi,
    functionName: "mint",
    args: [amounts, 0n],
  });
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Minted Tapio pool: USDC=${usdcAmount} USDT=${usdtAmount}, gasUsed=${receipt.gasUsed}`);
}

function formatAmount(amount: bigint, decimals: number) {
  const factor = 10n ** BigInt(decimals);
  const whole = amount / factor;
  const fraction = amount % factor;
  const fractionStr = fraction.toString().padStart(decimals, "0").replace(/0+$/, "");
  return fractionStr ? `${whole.toString()}.${fractionStr}` : whole.toString();
}

async function main() {
  publicClient = createPublicClient({ chain: mainnet, transport: http(RPC) });

  await publicClient.request({ method: "anvil_impersonateAccount", params: [WHALE] });
  whaleClient = createWalletClient({
    account: WHALE,
    chain: mainnet,
    transport: http(RPC),
  });

  await publicClient.request({ method: "anvil_impersonateAccount", params: [KEEPER_ADDRESS] });
  const keeperClient = createWalletClient({
    account: ADMIN,
    chain: mainnet,
    transport: http(RPC),
  });

  // Initial liquidity
  const [usdcBal, usdtBal] = await getCurveBalances(CURVE_POOL);
  await mintToTapio(usdcBal, usdtBal);

  const liquidityData = JSON.parse(fs.readFileSync(CURVE_LIQUIDITY_RESULTS, "utf8"));
  const liquidity = liquidityData.events ?? [];
  const swapsData = JSON.parse(fs.readFileSync(CURVE_SWAPS_RESULTS, "utf8"));
  const swaps = swapsData.swaps;
  const config = JSON.parse(fs.readFileSync(CONFIG_JSON, "utf8"));
  const ramps = config.ramps ?? [];
  const swapFees = config.swapFees ?? [];

  type Action = {
    type: "swap" | "rampA" | "swapFee" | "addLiquidity" | "removeLiquidity";
    blockNumber: number;
    timestamp: number;
    data: any;
  };
  let actions: Action[] = [];

  actions.push(...ramps.map((r) => ({ type: "rampA", blockNumber: r.blockNumber, timestamp: r.timestamp, data: r })));

  actions.push(
    ...swapFees.map((f) => ({ type: "swapFee", blockNumber: f.blockNumber, timestamp: f.timestamp, data: f })),
  );

  actions.push(
    ...swaps.map((s) => ({ type: "swap", blockNumber: Number(s.blockNumber), timestamp: s.timestamp, data: s })),
  );

  actions.push(
    ...liquidity.map((ev) => ({
      type: ev.type === "add" ? "addLiquidity" : "removeLiquidity",
      blockNumber: Number(ev.entry.blockNumber),
      timestamp: ev.entry.timestamp,
      data: ev.entry,
    })),
  );

  // Sort by timestamp first
  actions.sort((a, b) => a.timestamp - b.timestamp);

  const grouped: Record<number, Action[]> = {};
  for (const act of actions) {
    if (!grouped[act.timestamp]) grouped[act.timestamp] = [];
    grouped[act.timestamp].push(act);
  }

  const results = [];

  const totalSwaps = actions.filter((a) => a.type === "swap").length;
  for (const [groupIdx, ts] of Object.keys(grouped)
    .map(Number)
    .sort((a, b) => a - b)
    .entries()) {
    const group = grouped[ts];

    await publicClient.request({ method: "evm_setNextBlockTimestamp", params: [ts] });

    for (const [idxInGroup, act] of group.entries()) {
      if (act.type === "addLiquidity") {
        const ev = act.data;
        const amounts = ev.args.token_amounts.map((a: string) => BigInt(a));
        await approveIfNeeded(USDC, TAPIO_ADDRESS, amounts[0]);
        await approveIfNeeded(USDT, TAPIO_ADDRESS, amounts[1]);

        console.log(`AddLiquidity: ${ev.tokens.join(", ")}`);

        try {
          const hash = await whaleClient.writeContract({
            address: TAPIO_ADDRESS,
            abi: tapioAbi,
            functionName: "mint",
            args: [amounts, 0n],
          });
          const receipt = await publicClient.waitForTransactionReceipt({ hash });
          results.push({
            type: "addLiquidity",
            blockNumber: act.blockNumber,
            replayTx: hash,
            gasUsed: receipt.gasUsed?.toString(),
            tokens: ev.tokens,
          });
        } catch (err) {
          console.error("AddLiquidity failed:", err.message);
        }
      }

      if (act.type === "removeLiquidity") {
        const ev = act.data;
        console.log(`RemoveLiquidity: ${ev.event}, tokens: ${ev.tokens.join(", ")}`);

        try {
          let hash;
          if (ev.event === "RemoveLiquidityOne") {
            hash = await whaleClient.writeContract({
              address: TAPIO_ADDRESS,
              abi: tapioAbi,
              functionName: "redeemSingle",
              args: [BigInt(ev.args.token_amount), BigInt(ev.args.token_id), 0n],
            });
          } else if (ev.event === "RemoveLiquidity") {
            const tokenAmounts = ev.args.token_amounts.map((a: string) => BigInt(a));
            hash = await whaleClient.writeContract({
              address: TAPIO_ADDRESS,
              abi: tapioAbi,
              functionName: "redeemProportion",
              args: [BigInt(ev.args.token_supply), tokenAmounts.map(() => 0n)], // dummy minRedeem
            });
          } else if (ev.event === "RemoveLiquidityImbalance") {
            const tokenAmounts = ev.args.token_amounts.map((a: string) => BigInt(a));
            hash = await whaleClient.writeContract({
              address: TAPIO_ADDRESS,
              abi: tapioAbi,
              functionName: "redeemMulti",
              args: [tokenAmounts, BigInt(ev.args.token_supply)],
            });
          }

          const receipt = await publicClient.waitForTransactionReceipt({ hash });
          results.push({
            type: "removeLiquidity",
            blockNumber: act.blockNumber,
            event: ev.event,
            replayTx: hash,
            gasUsed: receipt.gasUsed?.toString(),
            tokens: ev.tokens,
          });
        } catch (err) {
          console.error(`RemoveLiquidity ${ev.event} failed:`, err.message);
        }
      }

      if (act.type === "swapFee") {
        const fee = act.data;
        console.log(`SetSwapFee to ${fee.newFee}`);
        try {
          const hash = await keeperClient.writeContract({
            address: TAPIO_ADDRESS,
            abi: keeperAbi,
            functionName: "setSwapFee",
            args: [BigInt(fee.newFee)],
          });
          const receipt = await publicClient.waitForTransactionReceipt({ hash });
          results.push({
            type: "swapFee",
            blockNumber: act.blockNumber,
            replayTx: hash,
            gasUsed: receipt.gasUsed?.toString(),
            newFee: fee.newFee,
          });
        } catch (err) {
          console.error("setSwapFee failed:", err.message);
        }
      }

      if (act.type === "rampA") {
        const r = act.data;
        console.log(`rampA to A=${r.newA} until ${r.endTime}`);
        try {
          const hash = await keeperClient.writeContract({
            address: TAPIO_ADDRESS,
            abi: keeperAbi,
            functionName: "rampA",
            args: [BigInt(r.newA), BigInt(r.endTime)],
          });
          const receipt = await publicClient.waitForTransactionReceipt({ hash });
          results.push({
            type: "rampA",
            blockNumber: act.blockNumber,
            replayTx: hash,
            gasUsed: receipt.gasUsed?.toString(),
            newA: r.newA,
            endTime: r.endTime,
          });
        } catch (err) {
          console.error("rampA failed:", err.message);
        }
      }

      if (act.type === "swap") {
        const swap = act.data;
        if (!swap.tokens_sold || !swap.tokens_bought) continue;

        let i,
          j,
          dx,
          minDy = 0n;
        if (swap.tokens_sold.includes("USDC")) {
          i = 0n;
          j = 1n;
          dx = BigInt(Math.round(parseFloat(swap.tokens_sold) * 1e6));
        } else if (swap.tokens_sold.includes("USDT")) {
          i = 1n;
          j = 0n;
          dx = BigInt(Math.round(parseFloat(swap.tokens_sold) * 1e6));
        } else continue;

        const calldata = encodeFunctionData({ abi: tapioAbi, functionName: "swap", args: [i, j, dx, minDy] });

        swapCounter++;
        console.log(`swap ${swapCounter}/${totalSwaps}: sold=${swap.tokens_sold} bought=${swap.tokens_bought}`);

        try {
          const hash = await whaleClient.sendTransaction({ account: WHALE, to: TAPIO_ADDRESS, data: calldata });
          const receipt = await publicClient.waitForTransactionReceipt({ hash });

          const logs = receipt.logs
            .map((log) => {
              try {
                return decodeEventLog({ abi: tapioAbi, data: log.data, topics: log.topics });
              } catch {
                return null;
              }
            })
            .filter((e) => e && e.eventName === "TokenSwapped");

          let tapioSold = null,
            tapioBought = null;
          if (logs.length > 0) {
            const ev = logs[0];
            tapioSold = formatAmount(ev.args.amounts[Number(i)], 6) + (Number(i) === 0 ? " USDC" : " USDT");
            tapioBought = formatAmount(ev.args.amounts[Number(j)], 6) + (Number(j) === 0 ? " USDC" : " USDT");
          }

          results.push({
            swapId: swapCounter,
            blockNumber: act.blockNumber,
            originalTx: swap.txHash,
            replayTx: hash,
            original: { tokens_sold: swap.tokens_sold, tokens_bought: swap.tokens_bought },
            tapio: { tokens_sold: tapioSold, tokens_bought: tapioBought, gasUsed: receipt.gasUsed?.toString() },
          });
        } catch (err) {
          console.error(`Swap ${groupIdx + 1}.${idxInGroup + 1} failed:`, err.message);
        }
      }
    }

    await publicClient.request({ method: "evm_mine", params: [] });
  }

  fs.writeFileSync("script/simulation/output/tapio-replayed-results.json", JSON.stringify(results, null, 2));
  console.log("Saved replay results to tapio-replayed-results.json");
}

main().catch(console.error);
