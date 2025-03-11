pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {PoolFactory} from "contracts/factories/PoolFactory.sol";
import {GaugeFactory} from "contracts/factories/GaugeFactory.sol";
import {VotingRewardsFactory} from "contracts/factories/VotingRewardsFactory.sol";
import {ManagedRewardsFactory} from "contracts/factories/ManagedRewardsFactory.sol";
import {FactoryRegistry} from "contracts/factories/FactoryRegistry.sol";
import {MezoForwarder} from "contracts/forwarder/MezoForwarder.sol";
import {VeBTC} from "contracts/VeBTC.sol";
import {Voter} from "contracts/Voter.sol";
import {RewardsDistributor} from "contracts/RewardsDistributor.sol";
import {ChainFeeSplitter} from "contracts/ChainFeeSplitter.sol";
import {EpochGovernor} from "contracts/EpochGovernor.sol";
import {TestERC20} from "contracts/test/TestERC20.sol";
import {Router} from "contracts/Router.sol";

abstract contract BaseSystemTest is Script, Test {
    using stdJson for string;

    uint256 public constant YEAR = 365 days;

    /// @dev RPC URL to the forked node.
    string public forkRpcUrl = vm.envString("FORK_RPC_URL");
    /// @dev Path to the Hardhat deployment artifacts.
    ///      Relative to the project root, no leading or trailing slashes.
    ///      For example: deployments/localhost
    string public deploymentArtifacts = vm.envString("DEPLOYMENT_ARTIFACTS");
    /// @dev Mnemonic to derive accounts from.
    string public mnemonic = vm.envString("MNEMONIC");
    /// @dev Number of accounts to derive.
    uint256 public accountsCount = vm.envUint("ACCOUNTS_COUNT");

    address[] public accounts;
    address governance;

    TestERC20 public BTC;
    TestERC20 public mUSD;
    TestERC20 public LIMPETH;
    TestERC20 public wtBTC;
    address public poolImplementation;
    PoolFactory public poolFactory;
    GaugeFactory public gaugeFactory;
    VotingRewardsFactory public votingRewardsFactory;
    ManagedRewardsFactory public managedRewardsFactory;
    FactoryRegistry public factoryRegistry;
    MezoForwarder public forwarder;
    VeBTC public veBTC;
    Voter public veBTCVoter;
    RewardsDistributor public veBTCRewardsDistributor;
    ChainFeeSplitter public chainFeeSplitter;
    EpochGovernor public veBTCEpochGovernor;
    Router public router;

    address public pool_BTC_mUSD;
    address public pool_mUSD_LIMPETH;
    address public pool_mUSD_wtBTC;

    function setUp() public {
        vm.createSelectFork(forkRpcUrl);

        deriveAccounts();
        governance = accounts[0];

        BTC = TestERC20(getDeploymentAddress("Bitcoin"));
        mUSD = new TestERC20("mUSD", "mUSD");
        LIMPETH = new TestERC20("LIMPETH", "LIMPETH");
        wtBTC = new TestERC20("wtBTC", "wtBTC");
        poolImplementation = getDeploymentAddress("Pool");
        poolFactory = PoolFactory(getDeploymentAddress("PoolFactory"));
        gaugeFactory = GaugeFactory(getDeploymentAddress("GaugeFactory"));
        votingRewardsFactory = VotingRewardsFactory(getDeploymentAddress("VotingRewardsFactory"));
        managedRewardsFactory = ManagedRewardsFactory(getDeploymentAddress("ManagedRewardsFactory"));
        factoryRegistry = FactoryRegistry(getDeploymentAddress("FactoryRegistry"));
        forwarder = MezoForwarder(payable(getDeploymentAddress("MezoForwarder")));
        veBTC = VeBTC(getDeploymentAddress("VeBTC"));
        veBTCVoter = Voter(getDeploymentAddress("VeBTCVoter"));
        veBTCRewardsDistributor = RewardsDistributor(getDeploymentAddress("VeBTCRewardsDistributor"));
        chainFeeSplitter = ChainFeeSplitter(getDeploymentAddress("ChainFeeSplitter"));
        veBTCEpochGovernor = EpochGovernor(payable(getDeploymentAddress("VeBTCEpochGovernor")));
        router = Router(getDeploymentAddress("Router"));

        pool_BTC_mUSD = createPoolWithGauge(address(BTC), address(mUSD), false);
        pool_mUSD_LIMPETH = createPoolWithGauge(address(mUSD), address(LIMPETH), false);
        pool_mUSD_wtBTC = createPoolWithGauge(address(mUSD), address(wtBTC), false);
    }

    function getDeploymentAddress(string memory deploymentName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/", deploymentArtifacts);
        string memory path = string.concat(basePath, "/", deploymentName, ".json");
        string memory deployment = vm.readFile(path);
        return abi.decode(deployment.parseRaw(".address"), (address));
    }

    function deriveAccounts() internal {
        accounts = new address[](accountsCount);
        for (uint32 i = 0; i < accountsCount; i++) {
            uint256 privateKey = vm.deriveKey(mnemonic, i);
            address account = vm.addr(privateKey);
            accounts[i] = account;
        }
    }

    function withTokenPrecision18(uint256 value) internal pure returns (uint256) {
        return value * 1e18;
    }

    function skipToNextEpoch(uint256 offset) internal {
        uint256 ts = block.timestamp;
        uint256 nextEpoch = ts - (ts % (1 weeks)) + (1 weeks);
        vm.warp(nextEpoch + offset);
        vm.roll(block.number + 1);
    }

    function createPoolWithGauge(address token1, address token2, bool stable) internal returns (address pool) {
        vm.startPrank(governance);
        pool = poolFactory.createPair(token1, token2, stable);
        veBTCVoter.createGauge(
            address(poolFactory),
            pool
        );
        vm.stopPrank();
    }
}
