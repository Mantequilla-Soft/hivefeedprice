export interface HiveConfig {
  readonly witnessAccount: string;
  readonly privateKey: string;
  readonly rpcNodes?: readonly string[];
  readonly chainId?: string;
}

export interface PriceFeedConfig {
  readonly updateInterval: number;
  readonly retryAttempts: number;
  readonly retryDelay: number;
}

export interface AppConfig {
  readonly hive: HiveConfig;
  readonly priceFeed: PriceFeedConfig;
}

const DEFAULT_CONFIG: Omit<AppConfig, "hive"> = {
  priceFeed: {
    updateInterval: 60_000,
    retryAttempts: 3,
    retryDelay: 5_000,
  },
} as const;

function parseInterval(input: string): number {
  const intervals = {
    "3min": 180000,
    "10min": 600000,
    "30min": 1800000,
    "1hour": 3600000,
    "6hour": 21600000,
  };
  return intervals[input as keyof typeof intervals] || 180000;
}

export function loadConfig(): AppConfig {
  const witnessAccount = process.env.HIVE_WITNESS_ACCOUNT;
  const privateKey = process.env.HIVE_SIGNING_PRIVATE_KEY;

  if (!witnessAccount) {
    throw new Error("HIVE_WITNESS_ACCOUNT environment variable is required");
  }

  if (!privateKey) {
    throw new Error(
      "HIVE_SIGNING_PRIVATE_KEY environment variable is required"
    );
  }

  const rpcNodes = process.env.HIVE_RPC_NODES
    ? (process.env.HIVE_RPC_NODES.split(",").map((node) => node.trim()) as readonly string[])
    : undefined;

  const updateInterval = process.env.FEED_INTERVAL
    ? parseInterval(process.env.FEED_INTERVAL)
    : DEFAULT_CONFIG.priceFeed.updateInterval;

  return {
    hive: {
      witnessAccount,
      privateKey,
      ...(rpcNodes && { rpcNodes }),
      ...(process.env.HIVE_CHAIN_ID && { chainId: process.env.HIVE_CHAIN_ID }),
    },
    priceFeed: {
      updateInterval,
      retryAttempts: DEFAULT_CONFIG.priceFeed.retryAttempts,
      retryDelay: DEFAULT_CONFIG.priceFeed.retryDelay,
    },
  };
}
