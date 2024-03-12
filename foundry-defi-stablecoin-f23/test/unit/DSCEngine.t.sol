// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
  DeployDSC public deployer;
  DecentralizedStableCoin public dsc;
  DSCEngine public engine;
  HelperConfig public config;
  address public ethUsdPriceFeed;
  address public weth;

  address public USER = makeAddr("user");
  uint256 public constant MOCK_COLLATERAL = 10 ether;
  uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

  function setUp() external {
    deployer = new DeployDSC();
    (dsc, engine, config) = deployer.run();
    (ethUsdPriceFeed,, weth,) = config.activeNetworkConfig();

    ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
  }


  function test_getUsdValue_canGetWETHValueCorrectly() public {
    uint256 ethAmount = 15e18;
    uint256 expectedUsd = 30000e18;
    uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

    assertEq(actualUsd, expectedUsd);
  }

  function test_depositCollateral_revertsIfCollateralIsZero() public {
    vm.startPrank(USER);
    ERC20Mock(weth).approve(address(engine), MOCK_COLLATERAL);

    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.depositCollateral(weth, 0);
    vm.stopPrank();
  }
}