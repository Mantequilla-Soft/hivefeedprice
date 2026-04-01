import { PriceProvider } from "@/types/price-provider";
import { roundToThreeDecimals } from "@/utils/math";

interface BinancePriceResponse {
  symbol: string;
  price: string;
}

export class BinancePriceProvider extends PriceProvider {
  readonly exchangeName = "Binance";
  readonly baseUrl = "https://api.binance.com";

  async getHivePrice(): Promise<number> {
    const price = await this.fetchWithRetry(() => this.fetchPrice("HIVEUSDT"));
    return roundToThreeDecimals(price);
  }

  private async fetchPrice(symbol: string): Promise<number> {
    const url = `${this.baseUrl}/api/v3/ticker/price?symbol=${symbol}`;
    const data = await this.makeRequest<BinancePriceResponse>(url);
    return parseFloat(data.price);
  }
}
