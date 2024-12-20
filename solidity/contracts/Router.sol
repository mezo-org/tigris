pragma solidity ^0.8.0;

import {IFactoryRegistry} from "./interfaces/factories/IFactoryRegistry.sol";
import {IPoolFactory} from "./interfaces/factories/IPoolFactory.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

abstract contract Router is IRouter {

    address public factoryRegistry;
    address public immutable weth;

    // XXX: underspecified
    address internal _defaultFactory;
    address internal _votingRewardsFactory;
    address internal _gaugeFactory;

    error FactoryNotApproved();

    constructor(
        address _factoryRegistry,
        address _weth
    ) {
        factoryRegistry = _factoryRegistry;
        weth = _weth;
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
        // XXX: underspecified _votingRewardsFactory, _gaugeFactory
        if (!IFactoryRegistry(factoryRegistry).isApproved(_factory, _votingRewardsFactory, _gaugeFactory)) revert FactoryNotApproved();
        (address token0, address token1, bool swapped) = orderedAddresses(tokenA, tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        address implementation = IPoolFactory(_factory).getImplementation();
        return Clones.predictDeterministicAddress(implementation, salt);
    }

    /// @notice Wraps around poolFor(tokenA,tokenB,stable,_factory) for backwards compatibility to Mezodrome v1
    function pairFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool) {
        return poolFor(tokenA, tokenB, stable, _factory);
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
        bool swapped = addressesNotOrdered(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, uint256 _blockTimestampLast) = IPool(pool).getReserves();
        (reserveA, reserveB) = swapped ? (reserve1, reserve0) : (reserve0, reserve1);
        return (reserveA, reserveB);
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
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB, stable, _factory);
        address pool = poolFor(tokenA, tokenB, stable, _factory);
        uint256 totalSupply = IERC20(pool).totalSupply();
        // Logic in the contract itself:
        //
        // liquidity = Math.min((_amount0 * _totalSupply) / _reserve0, (_amount1 * _totalSupply) / _reserve1);
        //
        // We calculate the amount using the same logic. As is, a small rounding error can happen.
        // This could be eliminated with more complex code that adjusts the derived quantity
        // until the output matches the contract logic precisely.
        //
        // XXX: cover the edge case of zero total supply?
        uint256 liquidityA = (amountADesired * totalSupply) / reserveA;
        uint256 liquidityB = (amountBDesired * totalSupply) / reserveB;
        bool minIsA = liquidityA < liquidityB;
        if (minIsA) {
            amountA = amountADesired;
            liquidity = liquidityA;
            amountB = (liquidity * reserveB) / totalSupply;
        } else {
            amountB = amountBDesired;
            liquidity = liquidityB;
            amountA = (liquidity * reserveA) / totalSupply;
        }
        return (amountA, amountB, liquidity);
    }

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) public view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB, stable, _factory);
        address pool = poolFor(tokenA, tokenB, stable, _factory);
        // Use same logic as in the contract itself
        uint256 totalSupply = IERC20(pool).totalSupply();
        uint256 balanceA = IERC20(tokenA).balanceOf(pool);
        uint256 balanceB = IERC20(tokenB).balanceOf(pool);
        amountA = liquidity * reserveA / totalSupply;
        amountB = liquidity * reserveB / totalSupply;
        return (amountA, amountB);
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
        // XXX: Underspecified factory
        address pool = poolFor(tokenA, tokenB, stable, _defaultFactory);
        // XXX: more expensive this way. Optimisations possible.
        uint256 quotedLiquidity;
        (amountA, amountB, quotedLiquidity) = quoteAddLiquidity(
            tokenA,
            tokenB,
            stable,
            _defaultFactory,
            amountADesired,
            amountBDesired
        );
        // The amount A minimum exceeds the amount A this liquidity addition would take.
        // XXX: This technically means that amount B is too low comparatively.
        if (amountA < amountAMin) revert InsufficientAmountBDesired();
        if (amountB < amountBMin) revert InsufficientAmountADesired();
        // Transfer tokens from sender to the contract.
        // XXX: take tokens from `to` or `msg.sender`?
        IERC20(tokenA).transferFrom(msg.sender, pool, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pool, amountB);
        liquidity = IPool(pool).mint(to);
        return (amountA, amountB, liquidity);
    }

    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable expires(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // XXX: Underspecified factory
        address pool = poolFor(token, weth, stable, _defaultFactory);
        uint256 amountETHDesired = msg.value;
        // XXX: more expensive this way
        uint256 quotedLiquidity;
        (amountToken, amountETH, quotedLiquidity) = quoteAddLiquidity(
            token,
            weth,
            stable,
            _defaultFactory,
            amountTokenDesired,
            amountETHDesired
        );
        // The amount A minimum exceeds the amount A this liquidity addition would take.
        // XXX: This technically means that amount B is too low comparatively.
        if (amountToken < amountTokenMin) revert InsufficientAmountBDesired();
        if (amountETH < amountETHMin) revert InsufficientAmountADesired();
        // Transfer tokens from sender to the contract.
        // XXX: take tokens from `to` or `msg.sender`?
        IWETH(weth).deposit{value: amountETH}();
        IWETH(weth).transfer(pool, amountETH);
        IERC20(token).transferFrom(msg.sender, pool, amountToken);
        liquidity = IPool(pool).mint(to);
        return (amountToken, amountETH, liquidity);
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
        address pool = poolFor(tokenA, tokenB, stable, _defaultFactory);
        (uint256 quotedAmountA, uint256 quotedAmountB) = quoteRemoveLiquidity(
            tokenA,
            tokenB,
            stable,
            _defaultFactory,
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

    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external expires(deadline) returns (uint256 amountToken, uint256 amountETH) {
        address pool = poolFor(token, weth, stable, _defaultFactory);
        (uint256 quotedAmountToken, uint256 quotedAmountETH) = quoteRemoveLiquidity(
            token,
            weth,
            stable,
            _defaultFactory,
            liquidity
        );
        if (quotedAmountToken < amountTokenMin) revert InsufficientAmountA();
        if (quotedAmountETH < amountETHMin) revert InsufficientAmountB();
        bool liquidityTransferSuccessful = IERC20(pool).transferFrom(msg.sender, pool, liquidity);
        if (!liquidityTransferSuccessful) revert InsufficientLiquidity();
        (uint256 amount0, uint256 amount1) = IPool(pool).burn(address(this));
        (amountToken, amountETH) = addressesNotOrdered(token, weth) ? (amount1, amount0) : (amount0, amount1);
        IWETH(weth).withdraw(amountETH);
        IERC20(token).transfer(to, amountToken);
        payable(to).send(amountETH);
        return (amountToken, amountETH);
    }

    // **** SWAP ****

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external validPath(routes) expires(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, routes);
        uint256 steps = routes.length;
        if (amounts[steps - 1] < amountOutMin) revert InsufficientOutputAmount();

        uint256 previousAmount = amountIn;
        for (uint256 i = 0; i < steps; i++) {
            Route memory currentRoute = routes[i];
            // address tokenIn = currentRoute.from;
            // address tokenOut = currentRoute.to;
            address pool = poolFor(currentRoute);
            bool swapped = addressesNotOrdered(currentRoute.from, currentRoute.to);
            (uint256 amount0Out, uint256 amount1Out) = swapped ? (amounts[i], uint256(0)) : (uint256(0), amounts[i]);
            (address tokenSender) = i == 0 ? msg.sender : address(this);
            IERC20(currentRoute.from).transferFrom(tokenSender, pool, previousAmount);
            IPool(pool).swap(amount0Out, amount1Out, address(this), bytes(""));
            previousAmount = amounts[i];
            if (i == steps - 1) {
                IERC20(currentRoute.to).transfer(to, previousAmount);
            }
        }
        return amounts;
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
    ) public view returns (uint256 ratio) {
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

    function validatePair(
        address tokenA,
        address tokenB
    ) internal pure {
        if (tokenA == tokenB) revert SameAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
    }

    function validateRoute(Route[] calldata routes) internal view returns (bool) {
        uint256 steps = routes.length;
        if (steps == 0) return false;
        address previousToken = routes[0].from;
        for (uint256 i = 0; i < steps; i++) {
            if (routes[i].from != previousToken) return false;
            previousToken = routes[i].to;
        }
    }

    // XXX: Assume timestamp here. Trivial change for block number.
    modifier expires(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
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