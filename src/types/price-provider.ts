import {
  PriceNetworkError,
  PriceAPIError,
  PRICE_ERROR_CODES,
} from "@/types/errors";
import { DomainAwareErrorHandler } from "@/utils/error-handlers";
import { sleep } from "@/utils/async";
import { validatePriceData } from "@/utils/price-validation";

export interface PriceResult {
  exchange: string;
  symbol: string;
  price: number;
  timestamp: Date;
}

export interface ExchangePrice {
  exchange: string;
  price: number;
  success: boolean;
  error?: string;
}

export abstract class PriceProvider {
  abstract readonly exchangeName: string;
  abstract readonly baseUrl: string;
  protected maxRetries = 2;
  protected retryAttempts = 2;
  protected retryDelay = 1000;
  protected requestTimeout = 15000;

  public configure(options: {
    readonly requestTimeout?: number;
    readonly retryAttempts?: number;
    readonly retryDelay?: number;
    readonly maxRetries?: number;
  }): void {
    if (typeof options.requestTimeout === "number") {
      this.requestTimeout = options.requestTimeout;
    }
    if (typeof options.retryAttempts === "number") {
      this.retryAttempts = options.retryAttempts;
    }
    if (typeof options.retryDelay === "number") {
      this.retryDelay = options.retryDelay;
    }
    if (typeof options.maxRetries === "number") {
      this.maxRetries = options.maxRetries;
    }
  }

  abstract getHivePrice(): Promise<number>;


  protected validatePriceData(data: unknown, symbol: string): number {
    return validatePriceData(data, symbol, this.exchangeName);
  }

  protected async fetchWithRetry<T>(fetchFn: () => Promise<T>): Promise<T> {
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= this.retryAttempts; attempt++) {
      try {
        return await fetchFn();
      } catch (error) {
        lastError = error as Error;
        console.log(`\x1b[33m[RETRY]\x1b[0m ${this.exchangeName} attempt ${attempt} failed:`, error);

        if (attempt < this.retryAttempts) {
          const delay = this.retryDelay * Math.pow(2, attempt - 1);
          await sleep(delay);
        }
      }
    }

    throw (
      lastError || new Error(`All attempts failed for ${this.exchangeName}`)
    );
  }


  protected async makeRequest<T>(url: string): Promise<T> {
    return DomainAwareErrorHandler.executeWithRetry(
      async () => {
        const controller = new AbortController();
        const timeoutId = setTimeout(
          () => controller.abort(),
          this.requestTimeout
        );

        try {
          const response = await fetch(url, {
            signal: controller.signal,
            headers: {
              "Content-Type": "application/json",
              "User-Agent": "HiveFeedPrice/1.0",
            },
          });

          clearTimeout(timeoutId);

          if (!response.ok) {
            if (response.status === 429) {
              const retryAfter = response.headers.get("Retry-After");
              const retryAfterSeconds = retryAfter
                ? parseInt(retryAfter, 10)
                : undefined;

              const errorContext: any = {
                exchangeName: this.exchangeName,
                operation: "http_request",
                httpStatus: response.status,
              };

              if (retryAfterSeconds !== undefined) {
                errorContext.retryAfter = retryAfterSeconds;
              }

              throw new PriceAPIError(
                `Rate limit exceeded`,
                PRICE_ERROR_CODES.API_RATE_LIMITED,
                errorContext
              );
            }

            if (response.status >= 500) {
              throw new PriceAPIError(
                `Server error: ${response.statusText}`,
                PRICE_ERROR_CODES.API_SERVER_ERROR,
                {
                  exchangeName: this.exchangeName,
                  operation: "http_request",
                  httpStatus: response.status,
                }
              );
            }

            if (response.status === 404) {
              throw new PriceAPIError(
                `Resource not found: ${url}`,
                PRICE_ERROR_CODES.API_NOT_FOUND,
                {
                  exchangeName: this.exchangeName,
                  operation: "http_request",
                  httpStatus: response.status,
                }
              );
            }

            throw new PriceAPIError(
              `HTTP error: ${response.status} ${response.statusText}`,
              PRICE_ERROR_CODES.API_INVALID_RESPONSE,
              {
                exchangeName: this.exchangeName,
                operation: "http_request",
                httpStatus: response.status,
              }
            );
          }

          try {
            return (await response.json()) as T;
          } catch (parseError) {
            throw new PriceAPIError(
              `Invalid JSON response`,
              PRICE_ERROR_CODES.API_INVALID_RESPONSE,
              {
                exchangeName: this.exchangeName,
                operation: "response_parsing",
              },
              parseError instanceof Error ? parseError : undefined
            );
          }
        } catch (error) {
          clearTimeout(timeoutId);

          if (error instanceof Error && error.name === "AbortError") {
            throw new PriceNetworkError(
              `Request timeout after ${this.requestTimeout}ms`,
              PRICE_ERROR_CODES.NETWORK_TIMEOUT,
              { exchangeName: this.exchangeName, operation: "http_request" }
            );
          }
          throw error;
        }
      },
      {
        domain: "price" as const,
        operation: "http_request",
        exchangeName: this.exchangeName,
        maxRetries: this.maxRetries,
      }
    );
  }
}
