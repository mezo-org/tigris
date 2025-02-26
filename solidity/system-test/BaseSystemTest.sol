pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

abstract contract BaseSystemTest is Script, Test {
    using stdJson for string;

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

    IERC20 public BTC;
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

    function setUp() public {
        vm.createSelectFork(forkRpcUrl);

        deriveAccounts();
        governance = accounts[0];

        BTC = IERC20(getDeploymentAddress("Bitcoin"));
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
}
