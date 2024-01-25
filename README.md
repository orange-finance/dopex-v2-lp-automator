# Dopex V2 Automator

The contract to automate Dopex V2 position management.
Deposited funds are automatically allocated to the best performing ticks.

# Specification

## Overview

```mermaid
graph TD
    A[User] --> |deposit/redeem| B[Automator]
    B --> |mint/burn position| C[DopexV2PositionManager]
    C --> |mint/burn position handler logic| D[UniswapV3SingleTickLiquidityHandler]
    C <-.-> |ERC1155 Position NFT| B
    B <-.-> |ERC20 share token| A

    E[Rebalance bot] --> |manage ticks regularly| B
```

# Test Coverage

```
make coverage/html
```
