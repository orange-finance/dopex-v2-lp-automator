// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {BaseFixture} from "test/OrangeDopexV2LPAutomator/v2/fixture/BaseFixture.t.sol";
import {OrangeKyberswapProxy} from "contracts/swap-proxy/OrangeKyberswapProxy.sol";
import {OrangeSwapProxy} from "contracts/swap-proxy/OrangeSwapProxy.sol";
import {IOrangeSwapProxy} from "contracts/swap-proxy/IOrangeSwapProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* solhint-disable func-name-mixedcase */
contract TestOrangeKyberswapProxy is BaseFixture {
    OrangeKyberswapProxy public proxy;
    address public mockProvider = makeAddr("TestOrangeKyberswapProxy.mockProvider");

    function setUp() public override {
        proxy = new OrangeKyberswapProxy();
        proxy.setTrustedProvider(mockProvider, true);
    }

    function test_safeInputSwap_Unauthorized() public {
        vm.expectRevert(OrangeSwapProxy.Unauthorized.selector);
        proxy.safeInputSwap(
            IOrangeSwapProxy.SwapInputRequest({
                provider: address(123),
                swapCalldata: "",
                expectTokenIn: IERC20(address(0)),
                expectTokenOut: IERC20(address(0)),
                expectAmountIn: 0,
                inputDelta: 0
            })
        );
    }

    function test_safeInputSwap_UnsupportedSelector() public {
        vm.expectRevert(OrangeKyberswapProxy.UnsupportedSelector.selector);
        proxy.safeInputSwap(
            IOrangeSwapProxy.SwapInputRequest({
                provider: mockProvider,
                swapCalldata: hex"12345678",
                expectTokenIn: IERC20(address(0)),
                expectTokenOut: IERC20(address(0)),
                expectAmountIn: 0,
                inputDelta: 0
            })
        );
    }

    function test_safeInputSwap_SrcTokenDoesNotMatch() public {
        vm.expectRevert(OrangeKyberswapProxy.SrcTokenDoesNotMatch.selector);
        proxy.safeInputSwap(
            createTestRequestWithDesc(
                IERC20(address(1)),
                IERC20(address(2)),
                IERC20(address(3)),
                IERC20(address(2)),
                address(0)
            )
        );
    }

    function test_safeInputSwap_DstTokenDoesNotMatch() public {
        vm.expectRevert(OrangeKyberswapProxy.DstTokenDoesNotMatch.selector);
        proxy.safeInputSwap(
            createTestRequestWithDesc(
                IERC20(address(1)),
                IERC20(address(2)),
                IERC20(address(1)),
                IERC20(address(3)),
                address(0)
            )
        );
    }

    function test_safeInputSwap_ReceiverIsNotSender() public {
        vm.expectRevert(OrangeKyberswapProxy.ReceiverIsNotSender.selector);
        proxy.safeInputSwap(
            createTestRequestWithDesc(
                IERC20(address(1)),
                IERC20(address(2)),
                IERC20(address(1)),
                IERC20(address(2)),
                address(1)
            )
        );
    }

    function test_safeInputSwap_OutOfDelta() public {
        vm.expectRevert(OrangeSwapProxy.OutOfDelta.selector);
        proxy.safeInputSwap(createTestRequestWithDelta(IERC20(address(1)), IERC20(address(2)), 100, 200, 9999));
    }

    function test_setOwner() public {
        proxy.setOwner(address(123));
        assertEq(proxy.owner(), address(123));
    }

    function test_setTrustedProvider_Unauthorized() public {
        vm.expectRevert(OrangeSwapProxy.Unauthorized.selector);
        vm.prank(alice);
        proxy.setTrustedProvider(address(123), true);
    }

    function createTestRequestWithDesc(
        IERC20 srcToken,
        IERC20 dstToken,
        IERC20 expectTokenIn,
        IERC20 expectTokenOut,
        address dstReceiver
    ) private view returns (IOrangeSwapProxy.SwapInputRequest memory) {
        return
            IOrangeSwapProxy.SwapInputRequest({
                provider: mockProvider,
                swapCalldata: abi.encodeWithSelector(
                    bytes4(0xe21fd0e9),
                    OrangeKyberswapProxy.SwapExecutionParams({
                        callTarget: address(0),
                        approveTarget: address(0),
                        targetData: "",
                        desc: OrangeKyberswapProxy.SwapDescriptionV2({
                            srcToken: srcToken,
                            dstToken: dstToken,
                            srcReceivers: new address[](0),
                            srcAmounts: new uint256[](0),
                            feeReceivers: new address[](0),
                            feeAmounts: new uint256[](0),
                            dstReceiver: dstReceiver,
                            amount: 0,
                            minReturnAmount: 0,
                            flags: 0,
                            permit: ""
                        }),
                        clientData: ""
                    })
                ),
                expectTokenIn: expectTokenIn,
                expectTokenOut: expectTokenOut,
                expectAmountIn: 0,
                inputDelta: 0
            });
    }

    function createTestRequestWithDelta(
        IERC20 expectTokenIn,
        IERC20 expectTokenOut,
        uint256 expectAmountIn,
        uint256 actualAmountIn,
        uint256 inputDelta
    ) private view returns (IOrangeSwapProxy.SwapInputRequest memory) {
        return
            IOrangeSwapProxy.SwapInputRequest({
                provider: mockProvider,
                swapCalldata: abi.encodeWithSelector(
                    bytes4(0xe21fd0e9),
                    OrangeKyberswapProxy.SwapExecutionParams({
                        callTarget: address(0),
                        approveTarget: address(0),
                        targetData: "",
                        desc: OrangeKyberswapProxy.SwapDescriptionV2({
                            srcToken: expectTokenIn,
                            dstToken: expectTokenOut,
                            srcReceivers: new address[](0),
                            srcAmounts: new uint256[](0),
                            feeReceivers: new address[](0),
                            feeAmounts: new uint256[](0),
                            dstReceiver: address(this),
                            amount: actualAmountIn,
                            minReturnAmount: 0,
                            flags: 0,
                            permit: ""
                        }),
                        clientData: ""
                    })
                ),
                expectTokenIn: expectTokenIn,
                expectTokenOut: expectTokenOut,
                expectAmountIn: expectAmountIn,
                inputDelta: inputDelta
            });
    }
}
