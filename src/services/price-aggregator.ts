import { PriceProvider, ExchangePrice } from "@/types/price-provider";
import {
  WeightedExchangePrice,
  WeightedPriceCalculator,
} from "@/types/weighted-price-provider";
import {
  loadProvidersFromEnv,
  ProviderConfig,
  getActiveProvidersConfig,
} from "@/config/providers-config.types";
import { roundToThreeDecimals } from "@/utils/math";
import { sleep } from "@/utils/async";
import { mapProvidersToExchangePrices, mapProvidersToDetailedPrices } from "@/utils/provider-mapping";

export class PriceAggregator {
  private readonly providers: PriceProvider[];
  private readonly providersConfig: Map<string, ProviderConfig>;
  private readonly timeout = 30000;
  private readonly maxRetries = 3;

  constructor(providers?: PriceProvider[], config?: ProviderConfig[]) {
    if (providers && providers.length === 0) {
      throw new Error("At least one price provider is required");
    }

    this.providers = providers || loadProvidersFromEnv();

    this.providersConfig = new Map();
    const configArray = config || getActiveProvidersConfig();

    configArray.forEach((cfg) => {
      this.providersConfig.set(cfg.name.toLowerCase(), cfg);
    });
  }

  async getAggregatedHivePrice(): Promise<number> {
    if (this.providers.length === 0) {
      throw new Error("No price providers configured");
    }

    let attempt = 1;
    while (attempt <= this.maxRetries) {
      try {
        const exchangePrices = await this.fetchPricesWithTimeout();
        const successfulPrices = exchangePrices.filter((ep) => ep.success);

        if (successfulPrices.length > 0) {
          return this.calculateFinalPrice(successfulPrices);
        }
      } catch (error) {
        console.log(`\x1b[33m[RETRY]\x1b[0m Attempt ${attempt} failed:`, error);
      }

      if (attempt < this.maxRetries) {
        const delay = 2000 * attempt;
        await sleep(delay);
      }

      attempt++;
    }

    throw new Error(
      `Failed to obtain HIVE price after ${this.maxRetries} attempts. All exchanges failed or timed out.`
    );
  }

  private async fetchPricesWithTimeout(): Promise<ExchangePrice[]> {
    const fetchPromise = this.fetchAllExchangePrices();
    const timeoutPromise = this.createTimeoutPromise();

    const result = await Promise.race([fetchPromise, timeoutPromise]);

    if (!result) {
      return [];
    }

    return result;
  }

  private async fetchAllExchangePrices(): Promise<ExchangePrice[]> {
    return mapProvidersToExchangePrices(this.providers);
  }

  private async createTimeoutPromise(): Promise<ExchangePrice[] | null> {
    return new Promise((resolve) => {
      setTimeout(() => resolve(null), this.timeout);
    });
  }

  private calculateFinalPrice(
    successfulPrices: ExchangePrice[]
  ): number {
    if (successfulPrices.length === 0) {
      throw new Error("No successful prices to calculate average");
    }

    const weightedPrices = this.applyWeights(successfulPrices);
    const hasWeights = weightedPrices.some((p) => p.weight !== 1.0);

    if (hasWeights) {
      return WeightedPriceCalculator.calculateWeightedAverage(weightedPrices);
    }

    const totalPrice = successfulPrices.reduce((sum, ep) => sum + ep.price, 0);
    const averagePrice = totalPrice / successfulPrices.length;
    return roundToThreeDecimals(averagePrice);
  }

  private applyWeights(
    exchangePrices: ExchangePrice[]
  ): WeightedExchangePrice[] {
    return exchangePrices.map((ep) => {
      const config = this.providersConfig.get(ep.exchange.toLowerCase());
      return {
        ...ep,
        weight: config?.weight || 1.0,
      };
    });
  }


  async getDetailedPrices(): Promise<ExchangePrice[]> {
    return mapProvidersToDetailedPrices(this.providers);
  }


  addProvider(provider: PriceProvider): void {
    this.providers.push(provider);
  }

  getProviders(): readonly PriceProvider[] {
    return this.providers;
  }
}

export const priceAggregator = new PriceAggregator();
