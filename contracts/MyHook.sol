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
import {Property} from "./TokenTown/Property.sol";
import {Game} from "./TokenTown/Game.sol";

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
    address currentUser;
    Game public game;
    struct InitParams {
        PoolKey key;
        uint160 sqrtPrice;
        bytes hookData;
    }

    function setGame(address _game) public {
        game = Game(_game);
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

    mapping(address => uint256) tokenPrice;
    mapping(address => uint256) tokenChange;

    function swap(
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        uint256 deadline,
        address _user
    ) public payable returns (int256, int256) {
        swaps[modSwap] = swapParams;
        currentUser = _user;
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

            // console.log("-", uint256(-1 * amount0), uint256(amount1));
            // console.log(user);
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
                    uint256(amount1)
                );

                SafeERC20.safeTransfer(
                    IERC20(Currency.unwrap(poolKey.currency1)),
                    address(poolManager),
                    uint256(amount1)
                );
                poolManager.settle(poolKey.currency1);
            }
            // console.log("Here");

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
                // console.log(
                //     IERC20(Currency.unwrap(poolKey.currency1)).balanceOf(
                //         address(this)
                //     )
                // );
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
    mapping(uint256 => uint256) public tokensBoughtAtPositon;

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (bytes4) {
        //Rules for monopoly
        //At most 1 token can be bought at one position
        // tokensBoughtAtPositon[]
        //User must be within the position to length of a token

        // console.log("Before a swap 11");
        uint256 tokenAmount = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);
        uint256 amountSpent = tokenAmount;
        // console.log("Here");
        // determine inbound/outbound token based on 0->1 or 1->0 swap
        (Currency inbound, Currency outbound) = params.zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);

        if (Currency.unwrap(outbound) != game.getCurrentChosenCurrency()) {
            //This means the user is buying property
            //Must check that they are on it and enforce pricing
            Property property = Property(Currency.unwrap(outbound));
            require(currentUser != address(0), "Must have new user");
            uint256 currentUserPosition = game.getPlayerPosition(currentUser);
            require(
                property.canUserPurchase(currentUserPosition),
                "User not on square"
            );
            uint256 price = property.getPrice(currentUserPosition);
            // console.log("Price", price);
            if (price == 0) {
                revert("The price is returning as 0");
            }
            tokenAmount = tokenAmount / price;
            if (tokensBoughtAtPositon[currentUserPosition] >= 10 ** 18) {
                revert("Can not buy anymore here");
            }

            if (
                tokenAmount >
                10 ** 18 - tokensBoughtAtPositon[currentUserPosition]
            ) {
                tokensBoughtAtPositon[currentUserPosition] = 10 ** 18;
                uint256 refund = tokenAmount -
                    tokensBoughtAtPositon[currentUserPosition];
                refund = refund * price;
                amountSpent -= refund;
                tokenAmount = 10 ** 18;
                // console.log("Refund issued of:", refund, amountSpent);
            } else {
                tokensBoughtAtPositon[currentUserPosition] = tokenAmount;
            }
        } else {
            Property property = Property(Currency.unwrap(inbound));
            uint256 currentUserPosition = game.getPlayerPosition(currentUser);

            //User is selling property
            uint256 price = property.getPrice(currentUserPosition);

            tokenAmount = tokenAmount * price;
            // console.log("Balance", outbound.balanceOfSelf());
            poolManager.burn(address(this), outbound.toId(), tokenAmount); //This creates credit
            poolManager.take(outbound, address(this), tokenAmount); //This settles the credit
            if (tokenAmount > 10 ** 18) {
                tokensBoughtAtPositon[currentUserPosition] = 0;
            } else {
                tokensBoughtAtPositon[currentUserPosition] -= tokenAmount;
            }

            // console.log(outbound.balanceOfSelf());
        }

        // take the inbound token from the PoolManager, debt is paid by the swapper via the swap router
        // (inbound token is added to hook's reserves)
        poolManager.mint(address(this), inbound.toId(), amountSpent);
        // console.log("Here", amountSpent);

        // provide outbound token to the PoolManager, credit is claimed by the swap router who forwards it to the swapper
        // (outbound token is removed from hook's reserves)
        // console.log("Here");
        // console.log(inbound.balanceOfSelf(), amountSpent);
        // console.log(outbound.balanceOfSelf(), tokenAmount);
        outbound.transfer(address(poolManager), tokenAmount);
        poolManager.settle(outbound);
        // console.log(outbound.balanceOfSelf(), tokenAmount);

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
