# GeomeanOracleHook

### Introduction

The GeomeanOracleHook is a custom hook designed for BalancerV3 pools, transforming them into robust Geometric mean oracles. By tracking and analyzing price observations, this hook provides reliable geometric mean price data, which is essential for various DeFi applications such as stablecoin mechanisms, automated market makers and DeFi protocols that require accurate price feeds

## Problem statement

In DeFi, accurate and reliable price oracles are crucial for maintaining the integrity and functionality of various protocols. Traditional arithmetic mean or single point price oracles can be susceptible to manipulation, volatility and inaccuracies due to limited data points. There's a need for a more resilient approach to price aggregation that can provide a stable and reliable metric for asset prices over time

### Architecture

- Components

  - GeomeanOracleHook contract: Implements the `IHooks` interface and extends `BaseHooks` and `VaultGuard` from BalancerV3. It manages the registration of pools, records price observations and computes the geometric mean of collected prices

  - GeomeanLibrary: A Solidity library that provides functions to compute the geometric mean of an array of values, including utility functions for safe arithmetic operations

### Workflow

- Pool registration: When a new pool is created via the allowed factory, the onRegister function is called. This ensures that only pools from the authorized factory can use the GeomeanOracleHook

- Price observation: Every time a swap occurs in the pool (onAfterSwap), the hook calculates the current price based on the swap parameters and records this observation

- Geometric mean calculation: Users can query the geometric mean price of a pool using the `getGeomeanPrice` function, which aggregates the stored price observations and computes their geometric mean using the GeomeanLibrary

Data management: The hook maintains a sliding window of up to 100 observations per pool, ensuring that the data remains relevant and storage costs are managed

### Features

- Secure pool registration: Ensures that only pools created by the authorized factory can register and use the hook, preventing unauthorized access

- Price tracking: Continuously records price observations after each swap, maintaining a history of up to 100 data points per pool

- Geometric mean calculation: Provides a reliable geometric mean price, mitigating the impact of outliers and reducing the risk of price manipulation

- Event emissions: Emits events for key actions such as pool registration, observation recording and factory updates, facilitating easy monitoring and integration

- Robust Error Handling: Implements comprehensive error checks to ensure data integrity and prevent invalid operations

### Future Scope

The GeomeanOracleHook is designed with extensibility in mind. Future enhancements could include:

- **Dynamic observation window**: Allowing dynamic adjustment of the number of observations stored per pool based on pool activity or governance decisions

- **Advanced Geometric mean algorithms**: Implementing more sophisticated algorithms for geometric mean calculation that can handle larger datasets or provide higher precision

- **Integration with external oracles**: Combining on-chain observations with data from external oracles to enhance price accuracy and reliability

- **Governance controls**: Introducing governance mechanisms to manage the allowed factory address, observation parameters and other critical settings

- **Performance optimizations**: Optimizing storage and computation to reduce gas costs and improve efficiency, especially for pools with high swap frequencies
