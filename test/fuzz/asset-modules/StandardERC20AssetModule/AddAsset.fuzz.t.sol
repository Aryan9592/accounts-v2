/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC20AssetModule_Fuzz_Test } from "./_StandardERC20AssetModule.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { AssetModule } from "../../../../src/asset-modules/AbstractAssetModule.sol";
import {
    PrimaryAssetModule, StandardERC20AssetModule
} from "../../../../src/asset-modules/StandardERC20AssetModule.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StandardERC20AssetModule".
 */
contract AddAsset_StandardERC20AssetModule_Fuzz_Test is StandardERC20AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc20AssetModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence() public {
        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleToken4ToUsdArr);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(PrimaryAssetModule.BadOracleSequence.selector);
        erc20AssetModule.addAsset(address(mockERC20.token4), badSequence);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc20AssetModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.expectRevert(RegistryErrors.Asset_Already_In_Registry.selector);
        erc20AssetModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_MoreThan18Decimals() public {
        ArcadiaOracle oracle = initMockedOracle(0, "ASSET / USD");
        vm.startPrank(users.tokenCreatorAddress);
        ERC20Mock asset = new ERC20Mock("ASSET", "ASSET", 19);
        chainlinkOM.addOracle(address(oracle), "ASSET", "USD");
        vm.stopPrank();

        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(oracle)));

        vm.prank(users.creatorAddress);
        vm.expectRevert(StandardERC20AssetModule.Max18Decimals.selector);
        erc20AssetModule.addAsset(address(asset), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
    }

    function testFuzz_Success_addAsset() public {
        vm.prank(users.creatorAddress);
        erc20AssetModule.addAsset(address(mockERC20.token4), oraclesToken4ToUsd);

        assertTrue(erc20AssetModule.inAssetModule(address(mockERC20.token4)));
        assertTrue(erc20AssetModule.isAllowed(address(mockERC20.token4), 0));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token4)));
        (uint64 assetUnit, bytes32 oracles) = erc20AssetModule.assetToInformation(assetKey);
        assertEq(assetUnit, 10 ** Constants.tokenDecimals);
        assertEq(oracles, oraclesToken4ToUsd);

        assertTrue(registryExtension.inRegistry(address(mockERC20.token4)));
        address assetModule = registryExtension.assetToAssetModule(address(mockERC20.token4));
        assertEq(assetModule, address(erc20AssetModule));
    }
}
