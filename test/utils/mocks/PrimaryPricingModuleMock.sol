// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModuleExtension } from "../Extensions.sol";

contract PrimaryPricingModuleMock is AbstractPrimaryPricingModuleExtension {
    // Price is 1 by default
    bool useRealUsdValue;
    uint256 usdExposureToUnderlyingAsset = 1;

    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        AbstractPrimaryPricingModuleExtension(mainRegistry_, oracleHub_, assetType_)
    { }

    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inPricingModule[asset];
    }

    function setAssetInformation(address asset, uint256 assetId, uint64 assetUnit, bytes32 oracles) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        assetToInformation2[assetKey].assetUnit = assetUnit;
        assetToInformation2[assetKey].oracles = oracles;
    }

    // ToDo: Refactor, due to legacy tests with getValue hardcoded we now use a workaround
    // with the state variable useRealUsdValue to see if we use the hardcoded or actual getValue function.
    function setUseRealUsdValue(bool status) public {
        useRealUsdValue = status;
    }

    function setUsdValue(uint256 usdExposureToUnderlyingAsset_) public {
        usdExposureToUnderlyingAsset = usdExposureToUnderlyingAsset_;
    }

    // The function below is only needed in the case of testing for the "AbstractDerivedPricingModule", in order for the Primary Asset to return a value
    // getValue() will be tested separately per PM.
    function getValue(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // ToDo: Refactor, due to legacy tests with getValue hardcoded we now use a workaround
        // with the state variable useRealUsdValue to see if we use the hardcoded or actual getValue function.
        if (useRealUsdValue) {
            (valueInUsd, collateralFactor, liquidationFactor) = super.getValue(creditor, asset, assetId, amount);
        } else {
            // we assume a price of 1 for this testing purpose
            valueInUsd = usdExposureToUnderlyingAsset;
            bytes32 assetKey = _getKeyFromAsset(asset, assetId);
            collateralFactor = riskParams[creditor][assetKey].collateralFactor;
            liquidationFactor = riskParams[creditor][assetKey].liquidationFactor;
        }
    }
}
