
export interface StaticProviderConfig {
  readonly name: string;
  readonly module: string;
  readonly exportName?: string;
  readonly enabled?: boolean;
  readonly weight?: number;
  readonly timeout?: number;
  readonly maxRetries?: number;
}

/**
 * Static price providers configuration
 * 
 * For developers: To modify exchange providers, weights, or add new exchanges,
 * edit this array directly. Environment variables are not used for provider
 * configuration as this static config takes precedence.
 */
export const STATIC_PROVIDERS: readonly StaticProviderConfig[] = [
  {
    name: "binance",
    module: "@/providers/binance-provider",
    exportName: "BinancePriceProvider",
    enabled: true,
    weight: 1.0,
  },
  {
    name: "bitget",
    module: "@/providers/bitget-provider",
    exportName: "BitgetPriceProvider",
    enabled: false,
    weight: 1.0,
  },
  {
    name: "huobi",
    module: "@/providers/huobi-provider",
    exportName: "HuobiPriceProvider",
    enabled: false,
    weight: 1.0,
  },
  {
    name: "mexc",
    module: "@/providers/mexc-provider",
    exportName: "MEXCPriceProvider",
    enabled: true,
    weight: 1.0,
  },
  {
    name: "probit",
    module: "@/providers/probit-provider",
    exportName: "ProbitPriceProvider",
    enabled: false,
    weight: 1.0,
  },
] as const;
