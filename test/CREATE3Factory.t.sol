// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {CREATE3Factory} from "../src/CREATE3Factory.sol";

/// @dev Simple contract for testing deployment
contract MockContract {
    uint256 public value;
    address public deployer;

    constructor(uint256 _value) payable {
        value = _value;
        deployer = msg.sender; // Note: This will be the CREATE3 proxy, not the actual deployer
    }

    function setValue(uint256 _value) external {
        value = _value;
    }
}

/// @dev Contract that requires ETH in constructor
contract PayableContract {
    uint256 public balance;

    constructor() payable {
        balance = msg.value;
    }
}

contract CREATE3FactoryTest is Test {
    CREATE3Factory public factory;

    address public alice = address(0x1);
    address public bob = address(0x2);

    bytes32 public constant SALT = keccak256("test-salt");
    bytes32 public constant SALT_2 = keccak256("test-salt-2");

    function setUp() public {
        factory = new CREATE3Factory();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deploy_basic() public {
        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(42));

        address deployed = factory.deploy(SALT, creationCode);

        assertTrue(deployed != address(0), "Deployed address should not be zero");
        assertTrue(deployed.code.length > 0, "Deployed contract should have code");

        MockContract mock = MockContract(deployed);
        assertEq(mock.value(), 42, "Constructor argument should be set correctly");
    }

    function test_deploy_predictedAddressMatches() public {
        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(100));

        address predicted = factory.getDeployed(address(this), SALT);
        address deployed = factory.deploy(SALT, creationCode);

        assertEq(deployed, predicted, "Deployed address should match predicted address");
    }

    function test_deploy_differentSaltsProduceDifferentAddresses() public {
        address predicted1 = factory.getDeployed(address(this), SALT);
        address predicted2 = factory.getDeployed(address(this), SALT_2);

        assertTrue(predicted1 != predicted2, "Different salts should produce different addresses");
    }

    function test_deploy_differentDeployersProduceDifferentAddresses() public {
        address predictedAlice = factory.getDeployed(alice, SALT);
        address predictedBob = factory.getDeployed(bob, SALT);

        assertTrue(predictedAlice != predictedBob, "Different deployers should produce different addresses");
    }

    function test_deploy_sameSaltSameDeployerProducesSameAddress() public {
        address predicted1 = factory.getDeployed(address(this), SALT);
        address predicted2 = factory.getDeployed(address(this), SALT);

        assertEq(predicted1, predicted2, "Same salt and deployer should produce same address");
    }

    function test_deploy_withValue() public {
        uint256 sendValue = 1 ether;
        vm.deal(address(this), sendValue);

        bytes memory creationCode = type(PayableContract).creationCode;

        address deployed = factory.deploy{value: sendValue}(SALT, creationCode);

        PayableContract payable_ = PayableContract(deployed);
        assertEq(payable_.balance(), sendValue, "Deployed contract should receive ETH");
        assertEq(deployed.balance, sendValue, "Contract balance should match sent value");
    }

    function test_deploy_revertOnDuplicateDeploy() public {
        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(42));

        factory.deploy(SALT, creationCode);

        vm.expectRevert();
        factory.deploy(SALT, creationCode);
    }

    function test_deploy_fromDifferentAccounts() public {
        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(42));

        vm.prank(alice);
        address deployedByAlice = factory.deploy(SALT, creationCode);

        vm.prank(bob);
        address deployedByBob = factory.deploy(SALT, creationCode);

        assertTrue(
            deployedByAlice != deployedByBob, "Same salt from different accounts should produce different addresses"
        );

        assertEq(deployedByAlice, factory.getDeployed(alice, SALT), "Alice's deployed address should match prediction");
        assertEq(deployedByBob, factory.getDeployed(bob, SALT), "Bob's deployed address should match prediction");
    }

    /*//////////////////////////////////////////////////////////////
                          GETDEPLOYED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getDeployed_consistentBeforeAndAfterDeploy() public {
        address predictedBefore = factory.getDeployed(address(this), SALT);

        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(42));
        factory.deploy(SALT, creationCode);

        address predictedAfter = factory.getDeployed(address(this), SALT);

        assertEq(predictedBefore, predictedAfter, "Predicted address should be consistent before and after deploy");
    }

    function test_getDeployed_independentOfCreationCode() public {
        // The address should be the same regardless of what contract will be deployed
        address predicted = factory.getDeployed(address(this), SALT);

        // Deploy a different contract
        bytes memory creationCode = type(PayableContract).creationCode;
        address deployed = factory.deploy(SALT, creationCode);

        assertEq(deployed, predicted, "Address should be independent of creation code");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_deploy_predictedAddressMatches(bytes32 salt, uint256 value) public {
        bytes memory creationCode = abi.encodePacked(type(MockContract).creationCode, abi.encode(value));

        address predicted = factory.getDeployed(address(this), salt);
        address deployed = factory.deploy(salt, creationCode);

        assertEq(deployed, predicted, "Deployed address should match predicted address");
    }

    function testFuzz_getDeployed_differentSaltsProduceDifferentAddresses(bytes32 salt1, bytes32 salt2) public {
        vm.assume(salt1 != salt2);

        address predicted1 = factory.getDeployed(address(this), salt1);
        address predicted2 = factory.getDeployed(address(this), salt2);

        assertTrue(predicted1 != predicted2, "Different salts should produce different addresses");
    }

    function testFuzz_getDeployed_differentDeployersProduceDifferentAddresses(address deployer1, address deployer2)
        public
    {
        vm.assume(deployer1 != deployer2);

        address predicted1 = factory.getDeployed(deployer1, SALT);
        address predicted2 = factory.getDeployed(deployer2, SALT);

        assertTrue(predicted1 != predicted2, "Different deployers should produce different addresses");
    }
}
