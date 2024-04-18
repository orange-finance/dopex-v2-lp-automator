// SPDX-License-Identifier: GPL-3.0

/* solhint-disable one-contract-per-file */

pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// solhint-disable-next-line max-states-count
contract MockAutomatorV3 is UUPSUpgradeable {
    // OrangeERC20Upgradeable
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    uint256[45] private __gap;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Vault params
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    uint24 private constant _MAX_TICKS = 150;
    /// @notice max deposit fee percentage is 1% (hundredth of 1e6)
    uint24 private constant _MAX_PERF_FEE_PIPS = 10_000;

    address public asset;
    address public counterAsset;

    uint256 public minDepositAssets;
    uint256 public depositCap;

    /// @notice deposit fee percentage, hundredths of a bip (1 pip = 0.0001%)
    uint24 public depositFeePips;
    address public depositFeeRecipient;

    mapping(address => bool) public isOwner;
    mapping(address => bool) public isStrategist;

    EnumerableSet.UintSet internal _activeTicks;

    uint8 private _decimals;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Stryke
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    address public manager;
    address public handler;
    address public handlerHook;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Chainlink
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    address public quoter;
    address public assetUsdFeed;
    address public counterAssetUsdFeed;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Uniswap
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    address public pool;
    /// @dev previously used as Uniswap Router, now used as own router
    address public router;
    int24 public poolTickSpacing;

    /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    Balancer
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
    address public balancer;

    uint256 public swapInputDelta;

    uint256 public foo;
    uint256 public bar;
    address public baz;

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override {}

    function initializeV3(uint256 foo_, uint256 bar_, address baz_) public reinitializer(3) {
        foo = foo_;
        bar = bar_;
        baz = baz_;
    }

    function newFunction() public view returns (uint256, uint256, address) {
        return (foo, bar, baz);
    }
}
