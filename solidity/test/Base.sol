pragma solidity 0.8.24;

import {ManagedRewardsFactory} from "contracts/factories/ManagedRewardsFactory.sol";
import {VotingRewardsFactory} from "contracts/factories/VotingRewardsFactory.sol";
import {GaugeFactory} from "contracts/factories/GaugeFactory.sol";
import {PoolFactory, IPoolFactory} from "contracts/factories/PoolFactory.sol";
import {IFactoryRegistry, FactoryRegistry} from "contracts/factories/FactoryRegistry.sol";
import {Pool} from "contracts/Pool.sol";
import {ISplitter, Splitter} from "contracts/Splitter.sol";
import {ChainFeeSplitter} from "contracts/ChainFeeSplitter.sol";
import {IReward, Reward} from "contracts/rewards/Reward.sol";
import {FeesVotingReward} from "contracts/rewards/FeesVotingReward.sol";
import {BribeVotingReward} from "contracts/rewards/BribeVotingReward.sol";
import {FreeManagedReward} from "contracts/rewards/FreeManagedReward.sol";
import {LockedManagedReward} from "contracts/rewards/LockedManagedReward.sol";
import {IGauge, Gauge} from "contracts/gauges/Gauge.sol";
import {PoolFees} from "contracts/PoolFees.sol";
import {RewardsDistributor, IRewardsDistributor} from "contracts/RewardsDistributor.sol";
import {IRouter, Router} from "contracts/Router.sol";
import {IVoter, Voter} from "contracts/Voter.sol";
import {IVotingEscrow, VotingEscrow} from "contracts/VotingEscrow.sol";
import {MezoGovernor} from "contracts/MezoGovernor.sol";
import {EpochGovernor} from "contracts/EpochGovernor.sol";
import {SafeCastLibrary} from "contracts/libraries/SafeCastLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SigUtils} from "test/utils/SigUtils.sol";
import {TestSplitter} from "test/utils/TestSplitter.sol";
import {MezoForwarder} from "contracts/forwarder/MezoForwarder.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {VeBTC} from "../contracts/VeBTC.sol";

/// @notice Base contract used for tests and deployment scripts
abstract contract Base is Script, Test {
    enum Deployment {
        DEFAULT,
        CUSTOM
    }
    /// @dev Determines whether or not to use the base set up configuration
    ///      Local deployment used by default
    Deployment deploymentType;

    IERC20 public BTC;
    address[] public tokens;

    /// @dev Core Deployment
    MezoForwarder public forwarder;
    Pool public implementation;
    Router public router;
    VotingEscrow public escrow;
    PoolFactory public factory;
    FactoryRegistry public factoryRegistry;
    GaugeFactory public gaugeFactory;
    VotingRewardsFactory public votingRewardsFactory;
    ManagedRewardsFactory public managedRewardsFactory;
    Voter public voter;
    RewardsDistributor public distributor;
    ChainFeeSplitter public chainFeeSplitter;
    TestSplitter public splitter;
    Gauge public gauge;
    MezoGovernor public governor;
    EpochGovernor public epochGovernor;

    /// @dev Global address to set
    address public allowedManager;

    /// @dev Dummy address of the proxy admin
    address public constant proxyAdmin = 0x1234567890123456789012345678901234567890;

    /// @dev Dummy address of the router deployer
    address public routerDeployer = 0x21ebdAC67b1F9e9e9f2739bE30C407dc97C71D2C;

    function _coreSetup() public {
        deployFactories();

        forwarder = new MezoForwarder();

        VeBTC impl = new VeBTC();
        bytes memory initData = abi.encodeWithSelector(
            impl.initialize.selector,
            address(forwarder),
            address(BTC),
            address(factoryRegistry)
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdmin,
            initData
        );
        escrow = VeBTC(address(proxy));

        // Setup voter and distributor
        distributor = new RewardsDistributor(address(escrow));
        voter = new Voter(address(forwarder), address(escrow), address(factoryRegistry));

        escrow.setVoterAndDistributor(address(voter), address(distributor));
        escrow.setAllowedManager(allowedManager);

        vm.prank(routerDeployer);
        router = new Router(
            address(forwarder),
            address(factoryRegistry),
            address(factory)
        );

        // Setup fee splitter
        chainFeeSplitter = new ChainFeeSplitter(address(voter), address(escrow), address(distributor));
        distributor.setDepositor(address(chainFeeSplitter));

        /// @dev tokens are already set in the respective setupBefore()
        voter.initialize(tokens, address(chainFeeSplitter));
    }

    function deployFactories() public {
        implementation = new Pool();
        factory = new PoolFactory(address(implementation));

        votingRewardsFactory = new VotingRewardsFactory();
        gaugeFactory = new GaugeFactory();
        managedRewardsFactory = new ManagedRewardsFactory();
        factoryRegistry = new FactoryRegistry(
            address(factory),
            address(votingRewardsFactory),
            address(gaugeFactory),
            address(managedRewardsFactory)
        );
    }
}
