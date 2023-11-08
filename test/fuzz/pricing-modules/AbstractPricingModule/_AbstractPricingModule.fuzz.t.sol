/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { PricingModuleMock } from "../../../utils/mocks/PricingModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractPricingModule" fuzz tests.
 */
abstract contract AbstractPricingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PricingModuleMock internal pricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pricingModule = new PricingModuleMock(address(mainRegistryExtension), 0);
    }
}
