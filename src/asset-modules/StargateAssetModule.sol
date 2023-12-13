/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "./AbstractDerivedAssetModule.sol";
import { IStargatePool } from "./interfaces/IStargatePool.sol";
import { IStargateLpStaking } from "./interfaces/IStargateLpStaking.sol";
import { StakingModule, ERC20 } from "./staking-module/AbstractStakingModule.sol";
import { AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";

/**
 * @title Asset-Module for Stargate Finance pools
 * @author Pragma Labs
 * @notice The StargateAssetModule stores pricing logic and basic information for Stargate Finance LP pools
 * @dev No end-user should directly interact with the StargateAssetModule, only the Registry, the contract owner or via the actionHandler
 */
contract StargateAssetModule is DerivedAssetModule, StakingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Stargate LP tokens staking contract.
    address public immutable stargateLpStaking;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The Unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;
    // The specific Stargate pool id for an asset.
    mapping(address asset => uint256 poolId) internal assetToPoolId;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error UnderlyingAssetNotAllowed();
    error AssetNotAllowed();
    error RewardTokenNotMatching();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param stargateLpStaking_ The address of the Stargate LP staking contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address registry_, address stargateLpStaking_) DerivedAssetModule(registry_, 0) {
        stargateLpStaking = stargateLpStaking_;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset (Stargate LP Pool) to the StargateAssetModule.
     * @param asset The contract address of the Stargate Pool.
     */
    function addAsset(address asset, uint256 poolId) external onlyOwner {
        address underlyingToken_ = IStargatePool(asset).token();

        // Note: Double check the underlyingToken as for ETH it didn't seem to be the primary asset.
        if (!IRegistry(REGISTRY).isAllowed(underlyingToken_, 0)) revert UnderlyingAssetNotAllowed();

        assetToPoolId[asset] = poolId;
        inAssetModule[asset] = true;

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingToken_, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(asset);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        if (inAssetModule[asset]) return true;
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Modules are ERC20's.
     */
    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Modules are ERC20's.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (address asset,) = _getAssetFromKey(assetKey);
            address underlyingToken_ = IStargatePool(asset).token();

            underlyingAssetKeys = new bytes32[](1);
            underlyingAssetKeys[0] = _getKeyFromAsset(underlyingToken_, 0);
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 assetAmount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);

        // Calculate underlyingAssets amounts
        // "amountSD" comes from the Stargate contracts and stands for amount in Shared Decimals, which should be convered to Local Decimals via convertRate.
        uint256 amountSD =
            assetAmount.mulDivDown(IStargatePool(asset).totalLiquidity(), IStargatePool(asset).totalSupply());
        underlyingAssetsAmounts[0] = amountSD * IStargatePool(asset).convertRate();

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new staking token with it's corresponding underlying and reward token.
     * @param asset The contract address of the Stargate LP token.
     * @param rewardToken_ The contract address of the reward token.
     */
    function addNewStakingToken(address asset, address rewardToken_) external override {
        if (tokenToRewardToId[asset][rewardToken_] != 0) revert TokenToRewardPairAlreadySet();

        if (!isAllowed(asset, 0)) revert AssetNotAllowed();

        if (address(IStargateLpStaking(stargateLpStaking).eToken()) != rewardToken_) revert RewardTokenNotMatching();

        // Note: think this is already checked when adding an asset
        if (ERC20(asset).decimals() > 18 || ERC20(rewardToken_).decimals() > 18) revert InvalidTokenDecimals();

        // Cache new id
        uint256 newId;
        unchecked {
            newId = ++lastId;
        }

        // Note: Think it makes more sense to rename to stakingToken for the case when it's the asset that is staked directly.
        underlyingToken[newId] = ERC20(asset);
        rewardToken[newId] = ERC20(rewardToken_);
        tokenToRewardToId[asset][rewardToken_] = newId;
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function _stake(uint256 id, uint256 amount) internal override {
        // Cache asset
        ERC20 asset = underlyingToken[id];
        asset.approve(stargateLpStaking, amount);
        uint256 poolId = assetToPoolId[address(asset)];

        // Stake asset
        IStargateLpStaking(stargateLpStaking).deposit(poolId, amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal override { }

    /**
     * @notice Claims the rewards available for this contract.
     * @param id The id of the specific staking token.
     */
    function _claimReward(uint256 id) internal override { }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract.
     * @param id The id of the specific staking token.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(uint256 id) internal view override returns (uint256 currentReward) { }

    /*///////////////////////////////////////////////////////////////
                           ERC1155 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that returns the URI as defined in the ERC1155 standard.
     * @param id The id of the specific staking token.
     * @return uri The token URI.
     */
    function uri(uint256 id) public view override returns (string memory) { }
}
