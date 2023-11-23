/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AssetModule } from "../../../../src/asset-modules/AbstractAssetModule.sol";
import { RiskModule } from "../../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getCollateralValue" of contract "AccountV1".
 */
contract GetCollateralValue_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getCollateralValue(uint128 spotValue, uint8 collateralFactor) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        spotValue = uint128(bound(spotValue, 0, type(uint128).max - 1));

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "collateralFactor" cannot exceed 100%.
        collateralFactor = uint8(bound(collateralFactor, 0, RiskModule.ONE_4));

        // Set Collateral factor of "stable1" for "stable1" to "collateralFactor".
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint128).max, collateralFactor, 0
        );

        uint256 expectedValue = uint256(spotValue) * collateralFactor / RiskModule.ONE_4;

        uint256 actualValue = accountExtension.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }
}
