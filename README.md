# Hive Feed Price Tool

[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)  
[![Node.js](<https://img.shields.io/badge/Node.js-%E2%89%A520%20(recommended%2022)-green.svg>)](https://nodejs.org/)  
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Tool for Hive witnesses to automatically publish feed prices using @hiveio/wax and @hiveio/beekeeper.**

> 🙏 **Credits**: This project is a fork of [enrique89ve/hivefeedprice](https://github.com/enrique89ve/hivefeedprice), originally created by [@enrique89ve](https://github.com/enrique89ve). Thank you for building such a great tool for the Hive witness community!

## ✨ What's New in This Fork

This fork adds several improvements to make the tool even easier to use:

- 🧙 **Interactive Setup Wizard** - No more manual `.env` editing! The install process now guides you through configuration step-by-step
- ⏰ **6-Hour Interval Option** - Added support for `6hour` feed publishing interval for witnesses who prefer minimal updates
- 🔧 **`./run.sh setup` Command** - Reconfigure your settings anytime with the interactive wizard
- 📝 **Better Documentation** - Improved README and help text

## 🚀 Quick Start

```bash
git clone https://github.com/menobass/hivefeedprice.git
cd hivefeedprice
./run.sh install     # Install Node.js, pnpm, dependencies AND run interactive setup
./run.sh start       # Start the application
```

The install command now includes an **interactive setup wizard** that will guide you through configuring your witness account, private key, and feed interval - no manual `.env` editing required!

## 📋 Commands

```bash
./run.sh install      # Install complete environment + interactive setup
./run.sh setup        # Run interactive configuration wizard (reconfigure anytime)
./run.sh start        # Start application
./run.sh stop         # Stop application
./run.sh restart      # Restart application
./run.sh logs         # View real-time logs
./run.sh status       # Show status
./run.sh clean        # Clean logs and PID files
./run.sh clean-wallet # Remove Beekeeper wallet (when changing signing key)
```

### Changing the signing key

If you need to change `HIVE_SIGNING_PRIVATE_KEY` in your `.env` file:

```bash
./run.sh stop         # Stop the application
./run.sh setup        # Run setup wizard (or manually edit .env)
./run.sh clean-wallet # Remove old wallet
./run.sh start        # Start with new key
```

## ⚙️ Requirements & Configuration

Minimum runtime versions:

- Node.js: >= 20 (recommended 22; the installer will use NVM and set 22 by default)
- pnpm: managed via Corepack (installed/enabled automatically)

### Environment variables (.env)

The easiest way is to run `./run.sh setup` which will create the `.env` file for you interactively.

Alternatively, you can start from `.env.example`:

```bash
cp .env.example .env
# then edit .env with your account and key
```

```bash
HIVE_WITNESS_ACCOUNT=your-witness-account
HIVE_SIGNING_PRIVATE_KEY=5J7cSr3Yv4nKwYour1PrivateKey2Here3...
FEED_INTERVAL=10min          # 3min, 10min, 30min, 1hour, 6hour
HIVE_RPC_NODES=https://api.hive.blog,https://api.deathwing.me
```

### Supported exchanges

- **Binance**, **Bitget**, **Huobi**, **MEXC**, **Probit**
- Configurable in `src/providers/static-providers.ts`

## 🔧 Development

```bash
pnpm dev             # Development with hot reload
pnpm build           # Compile TypeScript
pnpm test            # Run tests
pnpm lint            # Linter
pnpm typecheck       # Type checking
```

## 📋 Features

- ✅ **Interactive setup wizard** - Configure everything without editing files
- ✅ **Automatic installation** with NVM and Node.js (targets 22; works with >= 20)
- ✅ **Flexible intervals** - 3min, 10min, 30min, 1hour, or 6hour
- ✅ **100% TypeScript** with strict types
- ✅ **Path mapping** `@/*` to `src/*`
- ✅ **Secure key management** with @hiveio/beekeeper
- ✅ **Multi-exchange** with configurable weights
- ✅ **Retry logic** and error handling
- ✅ **Background process** with nohup

## 🛡️ Security

- Private keys handled with @hiveio/beekeeper (encrypted)
- Environment variables with Node.js native support (.env)
- Temporary in-memory wallets for maximum security

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

## 🔗 Links

- **Original Repository**: [enrique89ve/hivefeedprice](https://github.com/enrique89ve/hivefeedprice)
- **This Fork**: [menobass/hivefeedprice](https://github.com/menobass/hivefeedprice)

---
