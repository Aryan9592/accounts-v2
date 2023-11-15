/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { StandardERC4626AssetModule_Fuzz_Test } from "./_StandardERC4626AssetModule.fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/ERC4626Mock.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StandardERC4626AssetModule".
 */
contract AddAsset_StandardERC4626AssetModule_Fuzz_Test is StandardERC4626AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc4626AssetModule.addAsset(asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_UnderlyingAssetNotAllowed() public {
        vm.prank(users.tokenCreatorAddress);
        ERC4626Mock ybToken3 = new ERC4626Mock(mockERC20.token3, "Mocked Yield Bearing Token 3", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("AM4626_AA: Underlying Asset not allowed");
        erc4626AssetModule.addAsset(address(ybToken3));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc4626AssetModule.addAsset(address(ybToken1));
        vm.expectRevert("MR_AA: Asset already in registry");
        erc4626AssetModule.addAsset(address(ybToken1));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset() public {
        vm.prank(users.creatorAddress);
        erc4626AssetModule.addAsset(address(ybToken1));

        assertTrue(registryExtension.inRegistry(address(ybToken1)));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory underlyingAssetKeys = erc4626AssetModule.getUnderlyingAssets(assetKey);

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        assertTrue(erc4626AssetModule.inAssetModule(address(ybToken1)));
    }
}
