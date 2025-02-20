pragma solidity ^0.8.0;

import {IFactoryRegistry} from "./interfaces/factories/IFactoryRegistry.sol";
import {IPoolFactory} from "./interfaces/factories/IPoolFactory.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IBTC} from "./interfaces/IBTC.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {PoolLibrary} from "./libraries/PoolLibrary.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "hardhat/console.sol";


contract Router is IRouter {

    address public immutable factoryRegistry;
    address public immutable btc;

    address internal immutable defaultFactory;
    address internal immutable votingRewardsFactory;
    address internal immutable gaugeFactory;

    error FactoryNotApproved();

    struct PoolInfo {
        address poolAddress;
        address tokenA;
        address tokenB;
    }

    struct PoolTokens {
        uint256 amountA;
        uint256 amountB;
        uint256 liquidity;
    }

    struct PoolSeed {
        address tokenA;
        address tokenB;
        bool stable;
        address factory;
    }

    struct ZapIn {
        Route poolSeed;
        uint256 amountInA;
        uint256 amountInB;
    }

    constructor(
        address _factoryRegistry,
        address _defaultFactory,
        address _votingRewardsFactory,
        address _gaugeFactory,
        address _btc
    ) {
        factoryRegistry = _factoryRegistry;
        defaultFactory = _defaultFactory;
        votingRewardsFactory = _votingRewardsFactory;
        gaugeFactory = _gaugeFactory;
        btc = _btc;
    }

    /// @notice Calculate the address of a pool by its' factory.
    ///         Used by all Router functions containing a `Route[]` or `_factory` argument.
    ///         Reverts if _factory is not approved by the FactoryRegistry
    /// @dev Returns a randomly generated address for a nonexistent pool
    /// @param tokenA Address of token to query
    /// @param tokenB Address of token to query
    /// @param stable Boolean to indicate if the pool is stable or volatile
    /// @param _factory Address of factory which created the pool
    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) public view returns (address pool) {
        if (!IFactoryRegistry(factoryRegistry).isApproved(_factory, votingRewardsFactory, gaugeFactory)) revert FactoryNotApproved();
        (address token0, address token1, bool swapped) = orderedAddresses(tokenA, tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        address implementation = IPoolFactory(_factory).getImplementation();
        return Clones.predictDeterministicAddress(implementation, salt, _factory);
    }

    function poolFor(
        Route memory route
    ) public view returns (address pool) {
        return poolFor(route.from, route.to, route.stable, route.factory);
    }

    function getReserves(
        address tokenA,
        address tokenB,
        bool stable,
        address factory
    ) public view returns (uint256 reserveA, uint256 reserveB) {
        address pool = poolFor(tokenA, tokenB, stable, factory);
        return _getReserves(pool, tokenA, tokenB);
    }

    function getAmountsOut(
        uint256 amountIn,
        Route[] calldata routes
    ) public view validPath(routes) returns (uint256[] memory amounts) {
        uint256 steps = routes.length;
        amounts = new uint256[](steps);
        uint256 previousAmount = amountIn;
        for (uint256 i = 0; i < steps; i++) {
            Route memory currentRoute = routes[i];
            address tokenIn = currentRoute.from;
            address tokenOut = currentRoute.to;
            address pool = poolFor(currentRoute);
            uint256 amountOut = IPool(pool).getAmountOut(previousAmount, tokenIn);
            amounts[i] = amountOut;
            previousAmount = amountOut;
        }
        return amounts;
    }

    // **** ADD LIQUIDITY ****

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) public view returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        PoolTokens memory quote = _quoteAddLiquidity(tokenA, tokenB, stable, _factory, amountADesired, amountBDesired);
        return (quote.amountA, quote.amountB, quote.liquidity);
    }

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) public view returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = _quoteRemoveLiquidity(_poolInfo(tokenA, tokenB, stable, _factory), liquidity);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB, liquidity) = _addLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, to, msg.sender);
    }

    function addLiquidityBTC(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBTCMin,
        address to,
        uint256 deadline
    ) external payable expires(deadline) returns (uint256 amountToken, uint256 amountBTC, uint256 liquidity) {
        IBTC(btc).deposit{value: msg.value}();
        (amountToken, amountBTC, liquidity) = _addLiquidity(token, btc, stable, amountTokenDesired, msg.value, amountTokenMin, amountBTCMin, to, address(this));
        // // uint256 amountBTCDesired = msg.value;
        // // XXX: more expensive this way
        // uint256 quotedLiquidity;
        // {
        //     (amountToken, amountBTC, quotedLiquidity) = quoteAddLiquidity(
        //         token,
        //         btc,
        //         stable,
        //         defaultFactory,
        //         amountTokenDesired,
        //         msg.value
        //     );
        //     // The amount A minimum exceeds the amount A this liquidity addition would take.
        //     // XXX: This technically means that amount B is too low comparatively.
        //     if (amountToken < amountTokenMin) revert InsufficientAmountBDesired();
        //     if (amountBTC < amountBTCMin) revert InsufficientAmountADesired();
        // }
        
        
        // // Transfer tokens from sender to the contract.
        // // XXX: take tokens from `to` or `msg.sender`?
        // IBTC(btc).deposit{value: amountBTC}();
        // // XXX: Underspecified factory
        // address pool = poolFor(token, btc, stable, defaultFactory);
        // IBTC(btc).transfer(pool, amountBTC);
        // IERC20(token).transferFrom(msg.sender, pool, amountToken);
        // if (addressesNotOrdered(token, btc)) {
        //     IPool(pool).swap(amountBTC, amountToken, pool, bytes(""));
        // } else {
        //     IPool(pool).swap(amountToken, amountBTC, pool, bytes(""));
        // }
        // liquidity = IPool(pool).mint(to);
        // return (amountToken, amountBTC, liquidity);
    }

    // **** REMOVE LIQUIDITY ****

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = _removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to);
    }

    function removeLiquidityBTC(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBTCMin,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256 amountToken, uint256 amountBTC) {
        (amountToken, amountBTC) = _removeLiquidity(
            token,
            btc,
            stable,
            liquidity,
            amountTokenMin,
            amountBTCMin,
            address(this)
        );
        IBTC(btc).withdraw(amountBTC);
        IERC20(token).transfer(to, amountToken);
        payable(to).send(amountBTC);
        return (amountToken, amountBTC);
    }

    function removeLiquidityBTCSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountBTCMin,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256 amountBTC) {
        uint256 amountTokenPre = IERC20(token).balanceOf(address(this));
        uint256 amountBTCPre = IERC20(btc).balanceOf(address(this));
        _removeLiquidity(
            token,
            btc,
            stable,
            liquidity,
            amountTokenMin,
            amountBTCMin,
            address(this)
        );
        uint256 amountToken = IERC20(token).balanceOf(address(this)) - amountTokenPre;
        amountBTC = IERC20(btc).balanceOf(address(this)) - amountBTCPre;
        IBTC(btc).withdraw(amountBTC);
        IERC20(token).transfer(to, amountToken);
        payable(to).send(amountBTC);
        return (amountBTC);
    }

    // **** SWAP ****

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) returns (uint256[] memory amounts) {
        return _swapExactTokensForTokens(amountIn, amountOutMin, routes, to);
    }

    function swapExactBTCForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) payable returns (uint256[] memory amounts) {
        uint256 amountBTC = msg.value;
        IBTC(btc).deposit{value: amountBTC}();
        return _swapExactTokensForTokens(amountBTC, amountOutMin, routes, to);
    }

    function swapExactTokensForBTC(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) returns (uint256[] memory amounts) {
        amounts = _swapExactTokensForTokens(amountIn, amountOutMin, routes, address(this));
        uint256 amountBTC = amounts[amounts.length - 1];
        IBTC(btc).withdraw(amountBTC);
        payable(to).send(amountBTC);
        return amounts;
    }

    function UNSAFE_swapExactTokensForTokens(
        uint256[] memory amounts,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256[] memory) {
        uint256 steps = routes.length;

        uint256 previousAmount = amounts[0];
        for (uint256 i = 0; i < steps; i++) {
            Route memory currentRoute = routes[i];
            // address tokenIn = currentRoute.from;
            // address tokenOut = currentRoute.to;
            
            // bool swapped = addressesNotOrdered(currentRoute.from, currentRoute.to);
            (address tokenSender) = address(this);
            
            {
                address pool = poolFor(currentRoute);
                IERC20(currentRoute.from).transferFrom(tokenSender, pool, previousAmount);
                (uint256 amount0Out, uint256 amount1Out) = addressesNotOrdered(currentRoute.from, currentRoute.to) ? (amounts[i], uint256(0)) : (uint256(0), amounts[i]);
                IPool(pool).swap(amount0Out, amount1Out, address(this), bytes(""));
            }
            
            previousAmount = amounts[i];
            if (i == steps - 1) {
                IERC20(currentRoute.to).transfer(to, amounts[i]);
            }
        }
        return amounts;
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) {
        _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            routes,
            to
        );
    }

    function swapExactBTCForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable validPath(routes) expires(deadline) {
        uint256 amountBTC = msg.value;
        IBTC(btc).deposit{value: amountBTC}();
        _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountBTC,
            amountOutMin,
            routes,
            to
        );
    }

    function swapExactTokensForBTCSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) {
        uint256[] memory amounts = _swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            routes,
            address(this)
        );
        uint256 amountBTC = amounts[amounts.length - 1];
        IBTC(btc).withdraw(amountBTC);
        payable(to).send(amountBTC);
    }

    /// @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the initial swap.
    ///         Additional slippage may be required when adding liquidity as the
    ///         price of the token may have changed.
    /// @param tokenIn Token you are zapping in from (i.e. input token).
    /// @param amountInA Amount of input token you wish to send down routesA
    /// @param amountInB Amount of input token you wish to send down routesB
    /// @param zapInPool Contains zap struct information. See Zap struct.
    /// @param routesA Route used to convert input token to tokenA
    /// @param routesB Route used to convert input token to tokenB
    /// @param to Address you wish to mint liquidity to.
    /// @param stake Auto-stake liquidity in corresponding gauge.
    /// @return liquidity Amount of LP tokens created from zapping in.
    function zapIn(
        address tokenIn,
        uint256 amountInA,
        uint256 amountInB,
        Zap calldata zapInPool,
        Route[] calldata routesA,
        Route[] calldata routesB,
        address to,
        bool stake
    ) external payable validRouteA(routesA) validRouteB(routesB) returns (uint256 liquidity) {
        uint256 amountA;
        if (routesA.length > 0) {
            uint256[] memory amountsA = _swapExactTokensForTokens(
                amountInA,
                zapInPool.amountOutMinA,
                routesA,
                address(this)
            );
            amountA = amountsA[routesA.length - 1];
        } else {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInA);
            amountA = amountInA;
        }
        uint256 amountB;
        if (routesB.length > 0) {
            uint256[] memory amountsB = _swapExactTokensForTokens(
                amountInB,
                zapInPool.amountOutMinB,
                routesB,
                address(this)
            );
            amountB = amountsB[routesB.length - 1];
        } else {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInB);
            amountB = amountInB;
        }
        _addLiquidity(
            zapInPool.tokenA,
            zapInPool.tokenB,
            zapInPool.stable,
            amountA,
            amountB,
            zapInPool.amountAMin,
            zapInPool.amountBMin,
            to,
            address(this)
        );
    }

    /// @notice Zap out a pool (B, C) into A.
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the removal of liquidity.
    ///         Additional slippage may be required on the swap as the
    ///         price of the token may have changed.
    /// @param tokenOut Token you are zapping out to (i.e. output token).
    /// @param liquidity Amount of liquidity you wish to remove.
    /// @param zapOutPool Contains zap struct information. See Zap struct.
    /// @param routesA Route used to convert tokenA into output token.
    /// @param routesB Route used to convert tokenB into output token.
    function zapOut(
        address tokenOut,
        uint256 liquidity,
        Zap calldata zapOutPool,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external validRouteA(routesA) validRouteB(routesB) {
        (uint256 amountA, uint256 amountB) = _removeLiquidity(
            zapOutPool.tokenA,
            zapOutPool.tokenB,
            zapOutPool.stable,
            liquidity,
            zapOutPool.amountAMin,
            zapOutPool.amountBMin,
            address(this)
        );
        _swapExactTokensForTokens(
            amountA,
            zapOutPool.amountOutMinA,
            routesA,
            msg.sender
        );
        _swapExactTokensForTokens(
            amountB,
            zapOutPool.amountOutMinB,
            routesB,
            msg.sender
        );
    }

    /// @notice Used to generate params required for zapping in.
    ///         Zap in => remove liquidity then swap.
    ///         Apply slippage to expected swap values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap in from.
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable .
    /// @param _factory .
    /// @param amountInA Amount of input token you wish to send down routesA
    /// @param amountInB Amount of input token you wish to send down routesB
    /// @param routesA Route used to convert input token to tokenA
    /// @param routesB Route used to convert input token to tokenB
    /// @return amountOutMinA Minimum output expected from swapping input token to tokenA.
    /// @return amountOutMinB Minimum output expected from swapping input token to tokenB.
    /// @return amountAMin Minimum amount of tokenA expected from depositing liquidity.
    /// @return amountBMin Minimum amount of tokenB expected from depositing liquidity.
    function generateZapInParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountInA,
        uint256 amountInB,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view validRouteA(routesA) validRouteB(routesB) returns (
        uint256 amountOutMinA,
        uint256 amountOutMinB,
        uint256 amountAMin,
        uint256 amountBMin
    ) {
        Route memory poolSeed;
        poolSeed.from = tokenA;
        poolSeed.to = tokenB;
        poolSeed.stable = stable;
        poolSeed.factory = _factory;
        return _generateZapInParams(poolSeed, amountInA, amountInB, routesA, routesB);
    }

    /// @notice Used to generate params required for zapping out.
    ///         Zap out => swap then add liquidity.
    ///         Apply slippage to expected liquidity values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap out of.
    /// @param tokenA .
    /// @param tokenB .
    /// @param stable .
    /// @param _factory .
    /// @param liquidity Amount of liquidity being zapped out of into a given output token.
    /// @param routesA Route used to convert tokenA into output token.
    /// @param routesB Route used to convert tokenB into output token.
    /// @return amountOutMinA Minimum output expected from swapping tokenA into output token.
    /// @return amountOutMinB Minimum output expected from swapping tokenB into output token.
    /// @return amountAMin Minimum amount of tokenA expected from withdrawing liquidity.
    /// @return amountBMin Minimum amount of tokenB expected from withdrawing liquidity.
    function generateZapOutParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view validRouteA(routesA) validRouteB(routesB) returns (
        uint256 amountOutMinA,
        uint256 amountOutMinB,
        uint256 amountAMin,
        uint256 amountBMin
    ) {
        (uint256 amountA, uint256 amountB) = quoteRemoveLiquidity(tokenA, tokenB, stable, _factory, liquidity);
        amountAMin = applySlippage(amountA, 10);
        amountBMin = applySlippage(amountB, 10);
        uint256[] memory amountsA = getAmountsOut(amountAMin, routesA);
        amountOutMinA = applyCompoundSlippage(amountsA[routesA.length - 1], 10, routesA.length);
        uint256[] memory amountsB = getAmountsOut(amountBMin, routesB);
        amountOutMinB = applyCompoundSlippage(amountsB[routesB.length - 1], 10, routesB.length);
        return (amountOutMinA, amountOutMinB, amountAMin, amountBMin);
    }

    /// @notice Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.
    /// @dev Returns stable liquidity ratio of B to (A + B).
    ///      E.g. if ratio is 0.4, it means there is more of A than there is of B.
    ///      Therefore you should deposit more of token A than B.
    /// @param tokenA tokenA of stable pool you are zapping into.
    /// @param tokenB tokenB of stable pool you are zapping into.
    /// @param factory Factory that created stable pool.
    /// @return ratio Ratio of token0 to token1 required to deposit into zap.
    function quoteStableLiquidityRatio(
        address tokenA,
        address tokenB,
        address factory
    ) external view returns (uint256 ratio) {
        return quoteLiquidityRatio(tokenA, tokenB, true, factory);
    }

    // Return the ratio for depositing liquidity
    // 1e18 = 1.0
    function quoteLiquidityRatio(
        address tokenA,
        address tokenB,
        bool stable,
        address factory
    ) internal view returns (uint256 ratio) {
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB, stable, factory);
        return (reserveA * 1e18) / reserveB;
    }

    function _poolInfo(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) internal view returns (PoolInfo memory poolInfo) {
        address poolAddress = poolFor(tokenA, tokenB, stable, _factory);
        return (PoolInfo(poolAddress, tokenA, tokenB));
    }

    function _getPoolInfo(
        Route memory route
    ) internal view returns (PoolInfo memory poolInfo) {
        return _poolInfo(route.from, route.to, route.stable, route.factory);
    }

    function _getReserves(
        PoolInfo memory pool
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        return _getReserves(pool.poolAddress, pool.tokenA, pool.tokenB);
    }

    function _getReserves(
        address pool,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        bool swapped = addressesNotOrdered(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, uint256 _blockTimestampLast) = IPool(pool).getReserves();
        (reserveA, reserveB) = swapped ? (reserve1, reserve0) : (reserve0, reserve1);
        // return (reserveA, reserveB);
    }

    function _getReserveInfo(
        PoolInfo memory pool
    ) internal view returns (PoolTokens memory reserveInfo) {
        (uint256 reserveA, uint256 reserveB) = _getReserves(pool);
        uint256 liquidity = IERC20(pool.poolAddress).totalSupply();
        return (PoolTokens(reserveA, reserveB, liquidity));
    }

    function _quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) internal view returns (PoolTokens memory) {
        PoolInfo memory pool = _poolInfo(tokenA, tokenB, stable, _factory);
        PoolTokens memory reserves = _getReserveInfo(pool);
        uint256 amountAQuoted;
        uint256 amountBQuoted;
        uint256 minSwapFraction = 1e18 / 1000; // swap if the amount is off by at least 0.1%; otherwise do even-handed deposit
        if (stable) {
            (amountAQuoted, amountBQuoted) = _quoteAddLiquidityStable(pool, reserves, amountADesired, amountBDesired, minSwapFraction);
        } else {
            (amountAQuoted, amountBQuoted) = _quoteAddLiquidityVolatile(pool, reserves, amountADesired, amountBDesired, minSwapFraction);
        }
        if (amountAQuoted > amountADesired) {
            // we swap B for A
            reserves.amountA = reserves.amountA + amountADesired - amountAQuoted;
            uint256 amountInB = amountBDesired - amountBQuoted;
            uint256 swapFee = (amountInB * IPoolFactory(_factory).getFee(pool.poolAddress, stable)) / 10000;
            reserves.amountB = reserves.amountB + amountInB - swapFee;
            uint256 liquidity = _quoteAddLiquidityNoSwap(reserves, amountAQuoted, amountBQuoted);
            // The swap takes in the full amount of both inputs
            return PoolTokens(amountADesired, amountBDesired, liquidity);
        } else if (amountBQuoted > amountBDesired) {
            // we swap A for B
            reserves.amountB = reserves.amountB + amountBDesired - amountBQuoted;
            uint256 amountInA = amountADesired - amountAQuoted;
            uint256 swapFee = (amountInA * IPoolFactory(_factory).getFee(pool.poolAddress, stable)) / 10000;
            reserves.amountA = reserves.amountA + amountInA - swapFee;
            uint256 liquidity = _quoteAddLiquidityNoSwap(reserves, amountAQuoted, amountBQuoted);
            // The swap takes in the full amount of both inputs
            return PoolTokens(amountADesired, amountBDesired, liquidity);
        } else {
            // we are not swapping, so for an efficient even-handed addition, we may output lower quoted amounts
            uint256 liquidity = _quoteAddLiquidityNoSwap(reserves, amountAQuoted, amountBQuoted);
            return PoolTokens(amountAQuoted, amountBQuoted, liquidity);
        }
    }

    // min swap fraction: if the calculated difference in the token amounts vs. ideal
    // distribution is greater than this fraction (expressed with 1e18 multiplier)
    // quote a swap; otherwise quote an even-handed addition
    function _quoteAddLiquidityVolatile(
        PoolInfo memory pool,
        PoolTokens memory reserves,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 minSwapFraction
    ) internal view returns (uint256 amountA, uint256 amountB) {
        uint256 postA = amountADesired + reserves.amountA;
        uint256 postB = amountBDesired + reserves.amountB;
        uint256 xy = PoolLibrary.volatileK(reserves.amountA, reserves.amountB); // x * y
        uint256 r = postA * (1e18) / postB; // ratio of A / B
        uint256 a2 = xy * r / 1e18;
        uint256 a = Math.sqrt(a2);
        uint256 b = xy / a;
        if (a > reserves.amountA) {
            // trade A for B
            uint256 deltaA = a - reserves.amountA;
            if (deltaA < (amountADesired * minSwapFraction / 1e18)) {
                return optimise(amountADesired, amountBDesired, reserves);
            } else {
                uint256 deltaB = reserves.amountB - b;
                uint256 quoteB = IPool(pool.poolAddress).getAmountOut(deltaA, pool.tokenA);
                console.log(
                    "Calculated B diff: %s, quoted: %s",
                    deltaB,
                    quoteB
                );
                return (amountADesired - deltaA, amountBDesired + quoteB);
            }
        } else if (b > reserves.amountB) {
            // trade B for A
            uint256 deltaB = b - reserves.amountB;
            if (deltaB < (amountBDesired * minSwapFraction / 1e18)) {
                return optimise(amountADesired, amountBDesired, reserves);
            } else {
                uint256 deltaA = reserves.amountA - a;
                uint256 quoteA = IPool(pool.poolAddress).getAmountOut(deltaB, pool.tokenB);
                console.log(
                    "Calculated A diff: %s, quoted: %s",
                    deltaA,
                    quoteA
                );
                return (amountADesired + quoteA, amountBDesired - deltaB);
            }
        } else {
            return (amountADesired, amountBDesired);
        }
    }

    function _quoteAddLiquidityStable(
        PoolInfo memory pool,
        PoolTokens memory reserves,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 minSwapFraction
    ) internal view returns (uint256 amountA, uint256 amountB) {
        uint256 decimalsA = 10 ** ERC20(pool.tokenA).decimals();
        uint256 decimalsB = 10 ** ERC20(pool.tokenB).decimals();
        uint256 k = PoolLibrary.stableK(reserves.amountA, reserves.amountB, decimalsA, decimalsB);
        // y^3x + x^3y
        // when y = rx, this is r^3 x^3 x + x^3 rx = r^3 x^4 + r x^4 = (r + r^3) x^4
        uint256 postA = ((amountADesired + reserves.amountA) * 1e18) / decimalsA;
        uint256 postB = ((amountBDesired + reserves.amountB) * 1e18) / decimalsB;
        uint256 r = postB * (1e18) / postA; // ratio of A / B
        uint256 r3r = (((r * r) / 1e18) * r) / 1e18 + r;
        uint256 a4 = k * 1e18 / r3r;
        // XXX: check the math
        uint256 a2 = Math.sqrt(a4 * 1e18);
        uint256 _a = Math.sqrt(a2 * 1e18);
        uint256 _b = r * _a / 1e18;
        uint256 a = _a * decimalsA / 1e18;
        uint256 b = _b * decimalsB / 1e18;
        if (a > reserves.amountA) {
            // trade A for B
            uint256 deltaA = a - reserves.amountA;
            if (deltaA < (amountADesired * minSwapFraction / 1e18)) {
                return optimise(amountADesired, amountBDesired, reserves);
            }
            uint256 deltaB = reserves.amountB - b;
            uint256 quoteB = IPool(pool.poolAddress).getAmountOut(deltaA, pool.tokenA);
            console.log(
                "Calculated B diff: %s, quoted: %s",
                deltaB,
                quoteB
            );
            return (amountADesired - deltaA, amountBDesired + quoteB);
        } else if (b > reserves.amountB) {
            // trade B for A
            uint256 deltaB = b - reserves.amountB;
            if (deltaB < (amountBDesired * minSwapFraction / 1e18)) {
                return optimise(amountADesired, amountBDesired, reserves);
            }
            uint256 deltaA = reserves.amountA - a;
            uint256 quoteA = IPool(pool.poolAddress).getAmountOut(deltaB, pool.tokenB);
            console.log(
                "Calculated A diff: %s, quoted: %s",
                deltaA,
                quoteA
            );
            return (amountADesired + quoteA, amountBDesired - deltaB);
        } else {
            return (amountADesired, amountBDesired);
        }
    }

    function _quoteAddLiquidityNoSwap(
        PoolTokens memory reserves,
        uint256 amountA,
        uint256 amountB
    ) internal pure returns (uint256) {
        uint256 liquidityA = (amountA * reserves.liquidity) / reserves.amountA;
        uint256 liquidityB = (amountB * reserves.liquidity) / reserves.amountB;
        console.log(
            "Quoted liquidity A: %s, B: %s",
            liquidityA,
            liquidityB
        );
        return (Math.min(liquidityA, liquidityB));
    }

    function _quoteRemoveLiquidity(
        PoolInfo memory pool,
        uint256 liquidity
    ) internal view returns (uint256 amountA, uint256 amountB) {
        // Use same logic as in the contract itself
        uint256 totalSupply = IERC20(pool.poolAddress).totalSupply();
        uint256 balanceA = IERC20(pool.tokenA).balanceOf(pool.poolAddress);
        uint256 balanceB = IERC20(pool.tokenB).balanceOf(pool.poolAddress);
        amountA = liquidity * balanceA / totalSupply;
        amountB = liquidity * balanceB / totalSupply;
        return (amountA, amountB);
    }

    function _swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to
    ) internal returns (uint256[] memory amounts) {
        uint256 steps = routes.length;
        amounts = new uint256[](steps);

        uint256 previousAmount = amountIn;
        console.log(
            "Previous amount: %s",
            previousAmount
        );
        // address tokenSender = msg.sender;
        address tokenRecipient = address(this);
        for (uint256 i = 0; i < steps; i++) {
            Route memory currentRoute = routes[i];
            if (i == steps - 1) {
                tokenRecipient = to;
            }
            address pool = poolFor(currentRoute);
            uint256 amountOut = IPool(pool).getAmountOut(previousAmount, currentRoute.from);
            console.log(
                "Amount out: %s",
                amountOut
            );
            if (i == 0) {
                IERC20(currentRoute.from).transferFrom(msg.sender, pool, previousAmount);
            } else {
                IERC20(currentRoute.from).transfer(pool, previousAmount);
            }
            // tokenSender = address(this);
            (uint256 amount0Out, uint256 amount1Out) = addressesNotOrdered(currentRoute.from, currentRoute.to) ? (amountOut, uint256(0)) : (uint256(0), amountOut);
            IPool(pool).swap(amount0Out, amount1Out, tokenRecipient, bytes(""));
            
            previousAmount = amountOut;
            amounts[i] = amountOut;
        }
        if (previousAmount < amountOutMin) revert InsufficientOutputAmount();
        return amounts;
    }

    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to
    ) internal returns (uint256[] memory amounts) {
        uint256 steps = routes.length;
        amounts = new uint256[](steps);

        uint256 previousAmount = amountIn;
        address tokenSender = address(this);
        address tokenRecipient = address(this);
        for (uint256 i = 0; i < steps; i++) {
            Route memory currentRoute = routes[i];
            if (i == steps - 1) {
                tokenRecipient = to;
            }
            address pool = poolFor(currentRoute);
            uint256 poolBalancePre = IERC20(currentRoute.from).balanceOf(pool);
            IERC20(currentRoute.from).transferFrom(tokenSender, pool, previousAmount);
            uint256 poolBalancePost = IERC20(currentRoute.from).balanceOf(pool);
            uint256 postFeeAmount = poolBalancePost - poolBalancePre;
            uint256 amountOut = IPool(pool).getAmountOut(postFeeAmount, currentRoute.from);
            
            (uint256 amount0Out, uint256 amount1Out) = addressesNotOrdered(currentRoute.from, currentRoute.to) ? (amountOut, uint256(0)) : (uint256(0), amountOut);
            IPool(pool).swap(amount0Out, amount1Out, tokenRecipient, bytes(""));
            
            previousAmount = amountOut;
            amounts[i] = amountOut;
        }
        if (previousAmount < amountOutMin) revert InsufficientOutputAmount();
        return (amounts);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        address from
    ) internal returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        PoolInfo memory pool = _poolInfo(tokenA, tokenB, stable, defaultFactory);
        PoolTokens memory reserves = _getReserveInfo(pool);
        uint256 amountAQuoted;
        uint256 amountBQuoted;
        uint256 minSwapFraction = 1e18 / 1000; // swap if the amount is off by at least 0.1%; otherwise do even-handed deposit
        if (stable) {
            (amountAQuoted, amountBQuoted) = _quoteAddLiquidityStable(pool, reserves, amountADesired, amountBDesired, minSwapFraction);
        } else {
            (amountAQuoted, amountBQuoted) = _quoteAddLiquidityVolatile(pool, reserves, amountADesired, amountBDesired, minSwapFraction);
        }
        // The amount A minimum exceeds the amount A this liquidity addition would take.
        // XXX: This technically means that amount B is too low comparatively.
        // if (amountAQuoted < amountAMin) revert InsufficientAmountBDesired();
        // if (amountBQuoted < amountBMin) revert InsufficientAmountADesired();

        console.log(
            "Desired A: %s, B: %s",
            amountADesired,
            amountBDesired
        );
        console.log(
            "Quoted A: %s, B: %s",
            amountAQuoted,
            amountBQuoted
        );
        if (amountAQuoted > amountADesired) {
            // trade B for A
            uint256 deltaB = amountBDesired - amountBQuoted;
            if (from == address(this)) {
                IERC20(tokenB).transfer(pool.poolAddress, deltaB);
            } else {
                IERC20(tokenB).transferFrom(from, pool.poolAddress, deltaB);
                IERC20(tokenB).transferFrom(from, address(this), amountBQuoted);
                IERC20(tokenA).transferFrom(from, address(this), amountADesired);
            }
            uint256 deltaA = amountAQuoted - amountADesired;
            (uint256 amount0Out, uint256 amount1Out) = addressesNotOrdered(tokenA, tokenB) ? (uint256(0), deltaA) : (deltaA, uint256(0));
            IPool(pool.poolAddress).swap(amount0Out, amount1Out, address(this), bytes(""));
            IERC20(tokenA).transfer(pool.poolAddress, amountAQuoted);
            IERC20(tokenB).transfer(pool.poolAddress, amountBQuoted);
            amountA = amountADesired;
            amountB = amountBDesired;
        } else if (amountBQuoted > amountBDesired) {
            // trade A for B
            uint256 deltaA = amountADesired - amountAQuoted;
            if (from == address(this)) {
                IERC20(tokenA).transfer(pool.poolAddress, deltaA);
            } else {
                IERC20(tokenA).transferFrom(from, pool.poolAddress, deltaA);
                IERC20(tokenA).transferFrom(from, address(this), amountAQuoted);
                IERC20(tokenB).transferFrom(from, address(this), amountBDesired);
            }
            uint256 deltaB = amountBQuoted - amountBDesired;
            (uint256 amount0Out, uint256 amount1Out) = addressesNotOrdered(tokenA, tokenB) ? (deltaB, uint256(0)) : (uint256(0), deltaB);
            IPool(pool.poolAddress).swap(amount0Out, amount1Out, address(this), bytes(""));
            IERC20(tokenA).transfer(pool.poolAddress, amountAQuoted);
            IERC20(tokenB).transfer(pool.poolAddress, amountBQuoted);
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            if (from == address(this)) {
                IERC20(tokenA).transfer(pool.poolAddress, amountAQuoted);
                IERC20(tokenB).transfer(pool.poolAddress, amountBQuoted);
            } else {
                IERC20(tokenA).transferFrom(from, pool.poolAddress, amountAQuoted);
                IERC20(tokenB).transferFrom(from, pool.poolAddress, amountBQuoted);
            }
            amountA = amountAQuoted;
            amountB = amountBQuoted;
        }


        // address pool = poolFor(tokenA, tokenB, stable, defaultFactory);
        // if (from == address(this)) {
        //     IERC20(tokenA).transfer(pool.poolAddress, amountADesired);
        //     IERC20(tokenB).transfer(pool.poolAddress, amountBDesired);
        // } else {
        //     IERC20(tokenA).transferFrom(from, pool.poolAddress, amountADesired);
        //     IERC20(tokenB).transferFrom(from, pool.poolAddress, amountBDesired);
        // }
        // if (amountA != amountADesired || amountB != amountBDesired) {
        //     if (addressesNotOrdered(tokenA, tokenB)) {
        //         IPool(pool).swap(amountB, amountA, address(this), bytes(""));
        //     } else {
        //         IPool(pool).swap(amountA, amountB, address(this), bytes(""));
        //     }
        //     IERC20(tokenA).transfer(pool, amountA);
        //     IERC20(tokenB).transfer(pool, amountB);
        // }
        liquidity = IPool(pool.poolAddress).mint(to);
        return (amountA, amountB, liquidity);
    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pool = poolFor(tokenA, tokenB, stable, defaultFactory);
        (uint256 quotedAmountA, uint256 quotedAmountB) = quoteRemoveLiquidity(
            tokenA,
            tokenB,
            stable,
            defaultFactory,
            liquidity
        );
        {
            if (quotedAmountA < amountAMin) revert InsufficientAmountA();
            if (quotedAmountB < amountBMin) revert InsufficientAmountB();
            bool liquidityTransferSuccessful = IERC20(pool).transferFrom(msg.sender, pool, liquidity);
            if (!liquidityTransferSuccessful) revert InsufficientLiquidity();
        }
        
        if (addressesNotOrdered(tokenA, tokenB)) {
            (amountB, amountA) = IPool(pool).burn(to);
            // return (amount1, amount0);
        } else {
            (amountA, amountB) = IPool(pool).burn(to);
            // return (amount0, amount1);
        }
    }

    function _generateZapInParams(
        Route memory poolSeed,
        uint256 amountInA,
        uint256 amountInB,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) internal view returns (
        uint256 amountOutMinA,
        uint256 amountOutMinB,
        uint256 amountAMin,
        uint256 amountBMin
    ) {
        // PoolInfo memory pool = _getPoolInfo(poolSeed);
        // PoolTokens memory reserves = _getReserveInfo(pool);
        uint256[] memory amountsA = getAmountsOut(amountInA, routesA);
        amountOutMinA = applyCompoundSlippage(amountsA[routesA.length - 1], 10, routesA.length);
        uint256[] memory amountsB = getAmountsOut(amountInB, routesB);
        amountOutMinB = applyCompoundSlippage(amountsB[routesB.length - 1], 10, routesB.length);
        PoolTokens memory quote = _quoteAddLiquidity(poolSeed.from, poolSeed.to, poolSeed.stable, poolSeed.factory, amountOutMinA, amountOutMinB);
        amountAMin = applySlippage(quote.amountA, 10);
        amountBMin = applySlippage(quote.amountB, 10);
        return (amountOutMinA, amountOutMinB, amountAMin, amountBMin);
    }

    function _generateZapOutParams(
        Route memory poolSeed,
        uint256 liquidity,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view validRouteA(routesA) validRouteB(routesB) returns (
        uint256 amountOutMinA,
        uint256 amountOutMinB,
        uint256 amountAMin,
        uint256 amountBMin
    ) {
        {
            PoolInfo memory pool = _getPoolInfo(poolSeed);
            (uint256 amountA, uint256 amountB) = _quoteRemoveLiquidity(pool, liquidity);
            amountAMin = applySlippage(amountA, 10);
            amountBMin = applySlippage(amountB, 10);
        }
        uint256[] memory amountsA = getAmountsOut(amountAMin, routesA);
        amountOutMinA = amountsA[routesA.length - 1];
        for (uint256 i = 0; i < routesA.length; i++) {
            amountOutMinA = amountOutMinA * 999 / 1000;
        }
        uint256[] memory amountsB = getAmountsOut(amountBMin, routesB);
        amountOutMinB = amountsB[routesB.length - 1];
        for (uint256 i = 0; i < routesB.length; i++) {
            amountOutMinB = amountOutMinB * 999 / 1000;
        }
        return (amountOutMinA, amountOutMinB, amountAMin, amountBMin);
    }

    /// @notice Returns the addresses in ascending order, plus a flag denoting whether they were swapped.
    function orderedAddresses(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1, bool swap) {
        return tokenA < tokenB ? (tokenA, tokenB, false) : (tokenB, tokenA, true);
    }

    function addressesNotOrdered(
        address tokenA,
        address tokenB
    ) internal pure returns (bool) {
        return tokenB <= tokenA;
    }

    // Apply 0.1% = 10bp of slippage tolerance per step
    function applySlippage(
        uint256 input,
        uint256 slippageBP
    ) internal pure returns (uint256 output) {
        return (input * (10000 - slippageBP) / 10000);
    }

    function applyCompoundSlippage(
        uint256 input,
        uint256 slippageBP,
        uint256 steps
    ) internal pure returns (uint256 output) {
        output = input;
        for (uint256 i = 0; i < steps; i++) {
            output = (output * (10000 - slippageBP) / 10000);
        }
        return output;
    }

    function validatePair(
        address tokenA,
        address tokenB
    ) internal pure {
        if (tokenA == tokenB) revert SameAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
    }

    function validateRoute(Route[] calldata routes) internal view returns (bool) {
        uint256 steps = routes.length;
        if (steps == 0) return true;
        address previousToken = routes[0].from;
        for (uint256 i = 0; i < steps; i++) {
            if (routes[i].from != previousToken) return false;
            previousToken = routes[i].to;
        }
        return true;
    }

    function optimise(
        uint256 amountADesired,
        uint256 amountBDesired,
        PoolTokens memory reserves
    ) internal pure returns (uint256 amountA, uint256 amountB) {
        uint256 optimalB = amountADesired * reserves.amountB / reserves.amountA;
        uint256 optimalA = amountBDesired * reserves.amountA / reserves.amountB;
        console.log(
            "Desired A: %s, B: %s",
            amountADesired,
            amountBDesired
        );
        console.log(
            "Optimal A: %s, B: %s",
            optimalA,
            optimalB
        );
        return (Math.min(amountADesired, optimalA), Math.min(amountBDesired, optimalB));
    }

    // XXX: Assume timestamp here. Trivial change for block number.
    modifier expires(uint256 deadline) {
        if (deadline > 0 && block.timestamp > deadline) revert Expired();
        _;
    }

    modifier validRouteA(Route[] calldata routeA) {
        if (!validateRoute(routeA)) revert InvalidRouteA();
        _;
    }

    modifier validRouteB(Route[] calldata routeB) {
        if (!validateRoute(routeB)) revert InvalidRouteB();
        _;
    }

    modifier validPath(Route[] calldata route) {
        if (!validateRoute(route)) revert InvalidPath();
        _;
    }
}