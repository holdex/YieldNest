// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import dependencies from v4-core and v4-periphery
import {BaseHook} from "lib/uniswap-hooks/src/base/BaseHook.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta } from "v4-core/src/types/BeforeSwapDelta.sol";

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
        address _feeCollector,
        uint256 _commission
    ) BaseHook(_poolManager) Ownable(msg.sender) {
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
            beforeSwapReturnDelta: false,
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
    function beforeSwap(
        address, // sender (unused here)
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata /* hookData */
    )
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24) {

        // Ensure swap direction is token0 -> token1.
        if (!params.zeroForOne) {
            revert("CustomSingleDirectionHook: Only token0->token1 swaps allowed");
        }        
        // Compute the commission fee
        uint256 fee = (uint256(params.amountSpecified) * commission) / 10000;
        // Accumulate fee for this pool
        feesCollected[key.toId()] += fee;

        // Immediately transfer the fee from this contract to the feeCollector.
        // Assumes that the negative delta from the swap causes the fee to be transferred into this contract.
        key.currency0.transfer(feeCollector, fee);

        // Determine which token is the input and deduct fee accordingly.
        BeforeSwapDelta commissionDelta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        commissionDelta = toBeforeSwapDelta(-fee.toInt128(), 0);
        
        // Returning the hook selector, the computed delta adjustment, and a flag (set to 0)
        return (BaseHook.beforeSwap.selector, commissionDelta, 0);
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        require(liquidityWhitelist[sender], "Provider not whitelisted");
        return BaseHook.beforeAddLiquidity.selector;
    }
}
