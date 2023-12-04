// // SPDX-License-Identifier: GPL-3.0

// pragma solidity 0.8.19;

// import "forge-std/Test.sol";
// import {Automator} from "../contracts/Automator.sol";

// import {IUniswapV3SingleTickLiquidityHandler} from "../contracts/vendor/dopexV2/IUniswapV3SingleTickLiquidityHandler.sol";
// import {IDopexV2PositionManager} from "../contracts/vendor/dopexV2/IDopexV2PositionManager.sol";
// import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract TestAutomator is Test {
//     address constant DOPEX_OWNER = 0x2c9bC901f39F847C2fe5D2D7AC9c5888A2Ab8Fcf;
//     address alice = vm.addr(1);
//     address bob = vm.addr(2);
//     address carol = vm.addr(3);
//     address dave = vm.addr(4);

//     address[] actors = [alice, bob, carol, dave];
//     address currentActor;

//     Automator automator;
//     IUniswapV3Pool pool = IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
//     IUniswapV3SingleTickLiquidityHandler handler =
//         IUniswapV3SingleTickLiquidityHandler(0xe11d346757d052214686bCbC860C94363AfB4a9A);
//     IDopexV2PositionManager manager = IDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
//     ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
//     IERC20 constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
//     IERC20 constant USDCE = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

//     modifier useActor(uint256 index) {
//         currentActor = actors[bound(index, 0, actors.length - 1)];
//         vm.startPrank(currentActor);
//         _;
//         vm.stopPrank();
//     }

//     function setUp() public {
//         vm.createSelectFork("arb", 151299689);

//         automator = new Automator({
//             admin: address(this),
//             manager_: manager,
//             handler_: handler,
//             router_: router,
//             pool_: pool,
//             asset_: WETH
//         });

//         vm.label(address(handler), "dopexHandler");
//         vm.label(address(pool), "weth_usdc.e");
//         vm.label(address(router), "router");
//         vm.label(address(manager), "dopexManager");
//         vm.label(address(WETH), "weth");
//         vm.label(address(USDCE), "usdc");
//         vm.label(address(automator), "automator");
//     }

//     function testFuzz_deposit(uint256 assets, uint256 actorIndex) public useActor(actorIndex) {
//         automator.deposit(assets);
//     }
// }

// // contract Handler is Test {
// //     Automator automator;

// //     address[] actors;
// //     address currentActor;

// //     constructor(Automator automator_) {
// //         automator = automator_;
// //     }

// //     function deposit(uint256 assets) external {
// //         automator.deposit(assets);
// //     }
// // }
