// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";
import {MockERC20WithTransferFee} from "./utils/MockERC20WithTransferFee.sol";

contract RouterTest is BaseTest {
    Pool _pool;
    Pool poolFee;
    MockERC20WithTransferFee erc20Fee;

    function _setUp() public override {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        amounts[3] = 1e25;
        amounts[4] = 1e25;

        _addLiquidityToPool(address(owner), address(router), address(BTC), address(mUSD), false, TOKEN_1, mUSD_1);
        _pool = Pool(factory.getPool(address(BTC), address(mUSD), false));

        erc20Fee = new MockERC20WithTransferFee("Mock Token", "FEE", 18);
        erc20Fee.mint(address(owner), TOKEN_100K);

        _seedPoolsWithLiquidity();
    }

    function _seedPoolsWithLiquidity() internal {
        erc20Fee.approve(address(router), TOKEN_100K);
        mUSD.approve(address(router), mUSD_100K);
        router.addLiquidity(
            address(erc20Fee),
            address(mUSD),
            false,
            TOKEN_100K,
            mUSD_100K,
            TOKEN_100K,
            mUSD_100K,
            address(owner),
            block.timestamp
        );

        poolFee = Pool(factory.getPool(address(erc20Fee), address(mUSD), false));
    }

    function testCannotSortTokensSameRoute() public {
        vm.expectRevert(IRouter.SameAddresses.selector);
        router.sortTokens(address(_pool), address(_pool));
    }

    function testCannotSortTokensZeroAddress() public {
        vm.expectRevert(IRouter.ZeroAddress.selector);
        router.sortTokens(address(_pool), address(0));
    }

    function testCannotSwapNonApprovedFactory() public {
        vm.expectRevert(IRouter.PoolFactoryDoesNotExist.selector);
        router.poolFor(address(mUSD), address(BTC), false, address(1));
    }

    function testRemoveLiquidity() public {
        // Record the initial token balances.
        uint256 initial_BTC = BTC.balanceOf(address(this));
        uint256 initial_mUSD = mUSD.balanceOf(address(this));
        uint256 poolInitial_BTC = BTC.balanceOf(address(_pool));
        uint256 poolInitial_mUSD = mUSD.balanceOf(address(_pool));

        // Add liquidity to the pool.
        BTC.approve(address(router), TOKEN_100K);
        mUSD.approve(address(router), mUSD_100K);
        (, , uint256 liquidity) = router.addLiquidity(
            address(BTC),
            address(mUSD),
            false,
            TOKEN_100K,
            mUSD_100K,
            TOKEN_100K,
            mUSD_100K,
            address(owner),
            block.timestamp
        );

        assertEq(BTC.balanceOf(address(this)), initial_BTC - TOKEN_100K);
        assertEq(mUSD.balanceOf(address(this)), initial_mUSD - mUSD_100K);

        // Quote the amount of tokens that would be returned.
        (uint256 amount_BTC, uint256 amount_mUSD) = router.quoteRemoveLiquidity(
            address(BTC),
            address(mUSD),
            false,
            address(factory),
            liquidity
        );

        // Remove liquidity from the pool.
        pool.approve(address(router), liquidity);
        router.removeLiquidity(
            address(BTC),
            address(mUSD),
            false,
            liquidity,
            amount_BTC,
            amount_mUSD,
            address(owner),
            block.timestamp
        );

        // Check that the original token balances were restored.
        assertEq(BTC.balanceOf(address(this)), initial_BTC);
        assertEq(mUSD.balanceOf(address(this)), initial_mUSD);
        assertEq(BTC.balanceOf(address(_pool)), poolInitial_BTC);
        assertEq(mUSD.balanceOf(address(_pool)), poolInitial_mUSD);
    }

    function testRouterPoolGetAmountsOutAndSwapExactTokensForTokens_mUSD_BTC() public {
        // Set up a route for swapping mUSD for BTC.
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(mUSD),
            to: address(BTC),
            stable: false,
            factory: address(0)
        });

        // Verify the output amounts calculated by the `Router` and `Pool` match.
        assertEq(
            router.getAmountsOut(mUSD_1, routes)[1],
            _pool.getAmountOut(mUSD_1, address(mUSD))
        );

        uint256[] memory expectedOutput = router.getAmountsOut(mUSD_1, routes);

        // Swap mUSD for BTC.
        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokens(
            mUSD_1,
            expectedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );
    }

    function testRouterPoolGetAmountsOutAndSwapExactTokensForTokens_BTC_mUSD() public {
        // Set up a route for swapping BTC for mUSD.
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(BTC),
            to: address(mUSD),
            stable: false,
            factory: address(0)
        });

        // Verify the output amounts calculated by the `Router` and `Pool` match.
        assertEq(
            router.getAmountsOut(TOKEN_1, routes)[1],
            _pool.getAmountOut(TOKEN_1, address(BTC))
        );

        uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1, routes);

        // Swap BTC for mUSD.
        BTC.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(
            TOKEN_1,
            expectedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );
    }

    // TESTS FOR FEE-ON-TRANSFER TOKENS

    function testRouterSwapExactTokensForTokensSupportingFeeOnTransferTokens() external {
        // Set up a route for swapping mUSD for erc20Fee.
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(mUSD),
            to: address(erc20Fee),
            stable: false,
            factory: address(0)
        });

        uint256 expectedOutput = router.getAmountsOut(mUSD_1, routes)[1];
        assertEq(poolFee.getAmountOut(mUSD_1, address(mUSD)), expectedOutput);

        assertEq(erc20Fee.balanceOf(address(owner)), 0);
        uint256 actualExpectedOutput = expectedOutput - erc20Fee.fee();

        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            mUSD_1,
            0,
            routes,
            address(owner),
            block.timestamp
        );

        // Verify erc20Fee were received.
        assertEq(erc20Fee.balanceOf(address(owner)), actualExpectedOutput);
    }

    function testRouterSwapExactTokensForTokensSupportingFeeOnTransferTokens_Erc20FeeToMUSD() external {
        // First add the token balance to user to swap.
        erc20Fee.mint(address(owner), TOKEN_1);

        // Set up a route for swapping erc20Fee for mUSD.
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: address(erc20Fee),
            to: address(mUSD),
            stable: false,
            factory: address(0)
        });

        uint256 expectedOutput = router.getAmountsOut(TOKEN_1, routes)[1];
        assertEq(poolFee.getAmountOut(TOKEN_1, address(erc20Fee)), expectedOutput);

        uint256 mUSDBalanceBefore = mUSD.balanceOf(address(owner));
        uint256 actualExpectedOutput = router.getAmountsOut(TOKEN_1 - erc20Fee.fee(), routes)[1];

        // Swap erc20Fee for mUSD.
        erc20Fee.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            TOKEN_1,
            0,
            routes,
            address(owner),
            block.timestamp
        );

        // Verify mUSD tokens were received.
        assertEq(mUSD.balanceOf(address(owner)) - mUSDBalanceBefore, actualExpectedOutput);
    }
}
