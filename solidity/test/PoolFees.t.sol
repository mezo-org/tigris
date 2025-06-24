// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";

contract PoolFeesTest is BaseTest {
    function _setUp() public override {
        factory.setFee(true, 2); // 2 bps = 0.02%
    }

    function testSwapAndClaimFees() public {
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(
            address(mUSD),
            address(BTC),
            true,
            address(0)
        );

        assertEq(
            router.getAmountsOut(mUSD_1, routes)[1],
            pool4.getAmountOut(mUSD_1, address(mUSD))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(mUSD_1, routes);
        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokens(
            mUSD_1,
            assertedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );
        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool4.poolFees();
        assertEq(mUSD.balanceOf(poolFees), 200); // 0.01% -> 0.02%
        uint256 b = mUSD.balanceOf(address(owner));
        pool4.claimFees();
        assertGt(mUSD.balanceOf(address(owner)), b);
    }

    function testFeeManagerCanChangeFeesAndClaim() public {
        factory.setFee(true, 3); // 3 bps = 0.03%

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(
            address(mUSD),
            address(BTC),
            true,
            address(0)
        );

        assertEq(
            router.getAmountsOut(mUSD_1, routes)[1],
            pool4.getAmountOut(mUSD_1, address(mUSD))
        );

        uint256[] memory assertedOutput = router.getAmountsOut(mUSD_1, routes);

        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokens(
            mUSD_1,
            assertedOutput[1],
            routes,
            address(owner),
            block.timestamp
        );

        skip(1801);
        vm.roll(block.number + 1);
        address poolFees = pool4.poolFees();
        assertEq(mUSD.balanceOf(poolFees), 300);
        uint256 b = mUSD.balanceOf(address(owner));
        pool4.claimFees();
        assertGt(mUSD.balanceOf(address(owner)), b);
    }
}
