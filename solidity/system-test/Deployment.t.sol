pragma solidity 0.8.24;

import {BaseSystemTest} from "./BaseSystemTest.sol";

contract Deployment is BaseSystemTest {
    function testBTC() public {
        assertNotEq(address(BTC), address(0), "BTC address should be non-zero");
    }

    function testPoolImplementation() public {
        assertNotEq(
            poolImplementation,
            address(0),
            "Pool implementation address should be non-zero"
        );
    }

    function testPoolFactory() public {
        assertNotEq(
            address(poolFactory),
            address(0),
            "PoolFactory address should be non-zero"
        );

        assertEq(
            poolFactory.implementation(),
            poolImplementation,
            "PoolFactory should be wired up to the Pool implementation"
        );
    }

    function testGaugeFactory() public {
        assertNotEq(
            address(gaugeFactory),
            address(0),
            "GaugeFactory address should be non-zero"
        );
    }

    function testVotingRewardsFactory() public {
        assertNotEq(
            address(votingRewardsFactory),
            address(0),
            "VotingRewardsFactory address should be non-zero"
        );
    }

    function testManagedRewardsFactory() public {
        assertNotEq(
            address(managedRewardsFactory),
            address(0),
            "ManagedRewardsFactory address should be non-zero"
        );
    }

    function testFactoryRegistry() public {
        assertNotEq(
            address(factoryRegistry),
            address(0),
            "FactoryRegistry address should be non-zero"
        );

        assertEq(
            factoryRegistry.fallbackPoolFactory(),
            address(poolFactory),
            "FactoryRegistry fallback PoolFactory should be properly set"
        );
        assertEq(
            factoryRegistry.managedRewardsFactory(),
            address(managedRewardsFactory),
            "FactoryRegistry managed RewardsFactory should be properly set"
        );

        (
            address fallbackVotingRewardsFactory,
            address fallbackGaugeFactory
        ) = factoryRegistry.factoriesToPoolFactory(address(poolFactory));
        assertEq(
            fallbackVotingRewardsFactory,
            address(votingRewardsFactory),
            "FactoryRegistry fallback VotingRewardsFactory should be properly approved"
        );
        assertEq(
            fallbackGaugeFactory,
            address(gaugeFactory),
            "FactoryRegistry fallback GaugeFactory should be properly approved"
        );
    }

    function testVeBTC() public {
        assertNotEq(
            address(veBTC),
            address(0),
            "VeBTC address should be non-zero"
        );

        assertEq(
            veBTC.forwarder(),
            address(forwarder),
            "VeBTC forwarder should be properly set"
        );
        assertEq(
            veBTC.token(),
            address(BTC),
            "VeBTC token should be properly set"
        );
        assertEq(
            veBTC.factoryRegistry(),
            address(factoryRegistry),
            "VeBTC factory registry should be properly set"
        );
        assertEq(
            veBTC.voter(),
            address(veBTCVoter),
            "VeBTC voter should be properly set"
        );
        assertEq(
            veBTC.distributor(),
            address(veBTCRewardsDistributor),
            "VeBTC distributor should be properly set"
        );
        assertEq(
            veBTC.team(),
            address(governance),
            "VeBTC team should be properly set"
        );
    }

    function testVeBTCVoter() public {
        assertNotEq(
            address(veBTCVoter),
            address(0),
            "VeBTCVoter address should be non-zero"
        );

        assertEq(
            veBTCVoter.forwarder(),
            address(forwarder),
            "VeBTCVoter forwarder should be properly set"
        );
        assertEq(
            veBTCVoter.ve(),
            address(veBTC),
            "VeBTCVoter ve should be properly set"
        );
        assertEq(
            veBTCVoter.factoryRegistry(),
            address(factoryRegistry),
            "VeBTCVoter factory registry should be properly set"
        );
        assertEq(
            veBTCVoter.governor(),
            address(governance),
            "VeBTCVoter governor should be properly set"
        );
        assertEq(
            veBTCVoter.epochGovernor(),
            address(veBTCEpochGovernor),
            "VeBTCVoter epoch governor should be properly set"
        );
        assertEq(
            veBTCVoter.emergencyCouncil(),
            address(governance),
            "VeBTCVoter emergency council should be properly set"
        );
        assertEq(
            veBTCVoter.splitter(),
            address(chainFeeSplitter),
            "VeBTCVoter splitter should be properly set"
        );
    }

    function testVeBTCRewardsDistributor() public {
        assertNotEq(
            address(veBTCRewardsDistributor),
            address(0),
            "VeBTCRewardsDistributor address should be non-zero"
        );

        assertEq(
            address(veBTCRewardsDistributor.ve()),
            address(veBTC),
            "VeBTCRewardsDistributor ve should be properly set"
        );
        assertEq(
            veBTCRewardsDistributor.depositor(),
            address(chainFeeSplitter),
            "VeBTCRewardsDistributor depositor should be properly set"
        );
    }

    function testChainFeeSplitter() public {
        assertNotEq(
            address(chainFeeSplitter),
            address(0),
            "ChainFeeSplitter address should be non-zero"
        );

        assertEq(
            address(chainFeeSplitter.voter()),
            address(veBTCVoter),
            "ChainFeeSplitter voter should be properly set"
        );
        assertEq(
            address(chainFeeSplitter.token()),
            address(BTC),
            "ChainFeeSplitter token should be properly set"
        );
        assertEq(
            address(chainFeeSplitter.rewardsDistributor()),
            address(veBTCRewardsDistributor),
            "ChainFeeSplitter rewards distributor should be properly set"
        );
    }

    function testVeBTCEpochGovernor() public {
        assertNotEq(
            address(veBTCEpochGovernor),
            address(0),
            "VeBTCEpochGovernor address should be non-zero"
        );

        assertTrue(
            veBTCEpochGovernor.isTrustedForwarder(address(forwarder)),
            "VeBTCEpochGovernor should consider the forwarder as trusted"
        );
        assertEq(
            address(veBTCEpochGovernor.token()),
            address(veBTC),
            "VeBTCEpochGovernor token should be properly set"
        );
        assertEq(
            veBTCEpochGovernor.splitter(),
            address(chainFeeSplitter),
            "VeBTCEpochGovernor splitter should be properly set"
        );
    }

    function testRouter() public {
        assertNotEq(
            address(router),
            address(0),
            "Router address should be non-zero"
        );

        assertTrue(
            router.isTrustedForwarder(address(forwarder)),
            "Router should consider the forwarder as trusted"
        );
        assertEq(
            router.factoryRegistry(),
            address(factoryRegistry),
            "Router factory registry should be properly set"
        );
        assertEq(
            router.defaultFactory(),
            address(poolFactory),
            "Router default pool factory should be properly set"
        );
        assertEq(router.voter(), address(0), "Router voter should not be set");
    }
}
