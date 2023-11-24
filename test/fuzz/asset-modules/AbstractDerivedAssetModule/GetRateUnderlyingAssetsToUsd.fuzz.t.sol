/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedAssetModule_Fuzz_Test } from "./_AbstractDerivedAssetModule.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getRateUnderlyingAssetsToUsd" of contract "AbstractDerivedAssetModule".
 */
contract GetRateUnderlyingAssetsToUsd_AbstractDerivedAssetModule_Fuzz_Test is AbstractDerivedAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRateUnderlyingAssetsToUsd(
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: State is persisted.
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // Prepare input.
        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] =
            bytes32(abi.encodePacked(uint96(assetState.underlyingAssetId), assetState.underlyingAsset));

        // Prepare expected internal call.
        address[] memory assets = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        assets[0] = assetState.underlyingAsset;
        assetIds[0] = assetState.underlyingAssetId;
        assetAmounts[0] = 1e18;
        bytes memory data =
            abi.encodeCall(registryExtension.getValuesInUsd, (assetState.creditor, assets, assetIds, assetAmounts));

        // When: "_getRateUnderlyingAssetsToUsd" is called.
        // Then: The Function "getUsdValue" on "Registry" is called with correct parameters.
        vm.expectCall(address(registryExtension), data);
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            derivedAssetModule.getRateUnderlyingAssetsToUsd(assetState.creditor, underlyingAssetKeys);

        // And: Transaction returns correct "rateUnderlyingAssetsToUsd".
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, underlyingPMState.usdValue);
    }
}
