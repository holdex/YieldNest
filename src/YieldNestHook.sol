// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import dependencies from v4-core and v4-periphery
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseHook } from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta } from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

/**
 * @title YieldNestHook
 * @notice A Uniswap V4 hook that implements both swap and liquidity hooks.
 * - During swaps, a commission fee is deducted from the input amount.
 * - The governor may adjust the commission, update the fee collector address, and
 *   whitelist liquidity providers.
 * - For liquidity additions, only whitelisted addresses are allowed.
 */
contract YieldNestHook is BaseHook, Ownable {
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;

    // ========= Governor Parameters =========
    address public feeCollector;
    // Commission expressed in basis points (e.g., 50 means 0.5%)
    uint256 public commission;

    // Mapping to whitelist addresses for liquidity provision
    mapping(address => bool) public liquidityWhitelist;

    // ========= Fee & Counter Tracking =========
    // Records fees collected per pool (by pool id)
    mapping(PoolId => uint256) public feesCollected;

    // ========= Constructor =========
    constructor(
        IPoolManager _poolManager,
        address _governor,
        address _feeCollector,
        uint256 _commission
    ) BaseHook(_poolManager) Ownable(_governor) {
        feeCollector = _feeCollector;
        commission = _commission;
    }

    // ========= Governor-Only Functions =========

    /// @notice Update the commission rate (in basis points)
    function setCommission(uint256 _commission) external onlyOwner {
        commission = _commission;
    }

    /// @notice Update the fee collector address
    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    /// @notice Add an address to the liquidity provider whitelist
    function addToWhitelist(address _provider) external onlyOwner {
        liquidityWhitelist[_provider] = true;
    }

    /// @notice Remove an address from the liquidity provider whitelist
    function removeFromWhitelist(address _provider) external onlyOwner {
        liquidityWhitelist[_provider] = false;
    }

    // ========= Hook Permission Declaration =========

    /**
     * @notice Declare which hook functions are implemented by this contract.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ========= Swap Hooks =========

    /**
     * @notice Called before a swap is executed.
     * @dev Calculates a commission fee based on the swap input.
     * Assumes IPoolManager.SwapParams has:
     *  - `amountSpecified`: the input amount
     *  - `zeroForOne`: a boolean indicating swap direction (true if token0 for token1)
     */
    function _beforeSwap(
        address, // sender (unused here)
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata /* hookData */
    )
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24) {

        uint256 swapAmount = params.amountSpecified < 0
        ? uint256(-params.amountSpecified)
        : uint256(params.amountSpecified);
       
        // Compute the commission fee
        uint256 fee = (swapAmount * commission) / 10000;
        // Accumulate fee for this pool
        feesCollected[key.toId()] += fee;

        BeforeSwapDelta swapDelta;
        if (params.zeroForOne) {
            swapDelta =  toBeforeSwapDelta(fee.toInt128(), 0);
            poolManager.take(key.currency0, feeCollector, fee);
        }  else {
            swapDelta = toBeforeSwapDelta(-fee.toInt128(), 0);
            poolManager.take(key.currency1, feeCollector, fee);
        }

        // // Returning the hook selector, the computed delta adjustment, and a flag (set to 0)
        return (BaseHook.beforeSwap.selector, swapDelta, 0);
    }

    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view override returns (bytes4) {
        require(liquidityWhitelist[sender], "Provider not whitelisted");
        return BaseHook.beforeAddLiquidity.selector;
    }
}
