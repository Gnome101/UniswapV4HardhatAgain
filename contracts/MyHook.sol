// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "./Hooks/BaseHook.sol";

import {Hooks} from "./Uniswap/V4-Core/libraries/Hooks.sol";

import {IPoolManager} from "./Uniswap/V4-Core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "./Uniswap/V4-Core/types/Currency.sol";

import {PoolKey} from "./Uniswap/V4-Core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "./Uniswap/V4-Core/types/PoolId.sol";
import {BalanceDelta} from "./Uniswap/V4-Core/types/BalanceDelta.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {UniswapInteract} from "./UniswapInteract.sol";
//Uncomment below for console logs
import "hardhat/console.sol";
error SwapExpired();
error OnlyPoolManager();
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    //Below is for uniswap interact
    mapping(uint256 => InitParams) inits;
    uint256 initCount;

    mapping(uint256 => IPoolManager.SwapParams) swaps;
    uint256 modSwap;
    struct InitParams {
        PoolKey key;
        uint160 sqrtPrice;
        bytes hookData;
    }

    function startPool(
        PoolKey memory key,
        uint160 sqrtPrice,
        bytes calldata hookData,
        uint256 deadLine
    ) public payable returns (int24 tick) {
        inits[initCount] = InitParams(key, sqrtPrice, hookData);

        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, key, 99, initCount, deadLine)
        );
        return abi.decode(res, (int24));
    }

    function swap(
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        uint256 deadline
    ) public payable returns (int256, int256) {
        swaps[modSwap] = swapParams;
        bytes memory res = poolManager.lock(
            abi.encode(msg.sender, poolKey, 1, modSwap, deadline)
        );

        return abi.decode(res, (int256, int256));
    }

    function lockAcquired(
        bytes calldata data
    ) external returns (bytes memory res) {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }

        (
            address user,
            PoolKey memory poolKey,
            uint256 action,
            uint256 counter,
            uint256 deadline
        ) = abi.decode(data, (address, PoolKey, uint256, uint256, uint256));

        if (block.timestamp > deadline) {
            revert();
        }
        BalanceDelta delta;

        if (action == 1) {
            delta = poolManager.swap(poolKey, swaps[counter], "0x");

            int256 amount0 = poolManager.currencyDelta(
                address(this),
                poolKey.currency0
            );

            int256 amount1 = poolManager.currencyDelta(
                address(this),
                poolKey.currency1
            );

            if (amount0 > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    user,
                    address(this),
                    uint256(amount0)
                );

                SafeERC20.safeTransfer(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    address(poolManager),
                    uint256(amount0)
                );
                poolManager.settle(poolKey.currency0);
            }
            if (amount1 > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    user,
                    address(this),
                    uint256(amount0)
                );
                SafeERC20.safeTransfer(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    address(poolManager),
                    uint256(amount0)
                );
                poolManager.settle(poolKey.currency1);
            }
            if (amount0 < 0) {
                poolManager.take(
                    poolKey.currency0,
                    address(this),
                    uint256(-1 * amount0)
                );
                SafeERC20.safeTransfer(
                    IERC20(Currency.unwrap(poolKey.currency0)),
                    user,
                    uint256(-1 * amount0)
                );
            }
            if (amount1 < 0) {
                poolManager.take(
                    poolKey.currency1,
                    address(this),
                    uint256(-1 * amount1)
                );
                console.log(
                    IERC20(Currency.unwrap(poolKey.currency1)).balanceOf(
                        address(this)
                    )
                );
                SafeERC20.safeTransfer(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    user,
                    uint256(-1 * amount1)
                );
            }
            modSwap++;
            int256 amount0After = poolManager.currencyDelta(
                address(this),
                poolKey.currency0
            );

            int256 amount1After = poolManager.currencyDelta(
                address(this),
                poolKey.currency1
            );
            require(amount0After == 0, "Amount0 not settled");
            require(amount1After == 0, "Amount1 not settled");

            return res = abi.encode(amount0, amount1);
        }

        if (action == 99) {
            InitParams memory params;
            params = inits[counter];
            poolManager.initialize(
                params.key,
                params.sqrtPrice,
                params.hookData
            );
        }

        res = abi.encode(delta.amount0(), delta.amount1());
        //return new bytes();
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                noOp: true
            });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        console.log("Before a swap 11");
        uint256 tokenAmount = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);
        // console.log("Here");
        // determine inbound/outbound token based on 0->1 or 1->0 swap
        (Currency inbound, Currency outbound) = params.zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);
        // console.log("Here");

        // take the inbound token from the PoolManager, debt is paid by the swapper via the swap router
        // (inbound token is added to hook's reserves)
        poolManager.mint(address(this), inbound.toId(), tokenAmount);
        // console.log("Here");

        // provide outbound token to the PoolManager, credit is claimed by the swap router who forwards it to the swapper
        // (outbound token is removed from hook's reserves)
        // console.log("Here");

        outbound.transfer(address(poolManager), tokenAmount);
        poolManager.settle(outbound);
        // console.log("Finished");
        return Hooks.NO_OP_SELECTOR;
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.afterSwap.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeRemoveLiquidity.selector;
    }
}
