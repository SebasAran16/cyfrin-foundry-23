// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
  DeployDSC public deployer;
  DecentralizedStableCoin public dsc;
  DSCEngine public engine;
  HelperConfig public config;
  address public ethUsdPriceFeed;
  address public btcUsdPriceFeed;
  address public weth;

  address public USER = makeAddr("user");
  uint256 public constant AMOUNT_COLLATERAL = 10 ether;
  uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
  uint256 public constant COLLATERAL_MAX_HEALTHY_USD_MINT = 10000 ether;
  int256 public constant ETH_USD_DEFAULT_ANSWER = 2000e8;

  function setUp() external {
    deployer = new DeployDSC();
    (dsc, engine, config) = deployer.run();
    (ethUsdPriceFeed, btcUsdPriceFeed, weth,) = config.activeNetworkConfig();

    ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
  }

  modifier depositedCollateral() {
    vm.startPrank(USER);
    ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
    engine.depositCollateral(weth, AMOUNT_COLLATERAL);
    vm.stopPrank();
    _;
  }

  address[] public tokenAddresses;
  address[] public priceFeedAddresses;

  function test_constructor_revertsWhenParametersLengthIsNotSame() public {
    tokenAddresses.push(weth);
    priceFeedAddresses.push(ethUsdPriceFeed);
    priceFeedAddresses.push(btcUsdPriceFeed);


    vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
    new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
  }

  function test_getTokenAmountFromUsd_getsAmountCorrectly() public {
    uint256 usdAmount = 100 ether;
    uint256 expectedWeth = 0.05 ether;
    uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

    assertEq(actualWeth, expectedWeth);
  }

  function test_getUsdValue_canGetWETHValueCorrectly() public {
    uint256 ethAmount = 15e18;
    uint256 expectedUsd = 30000e18;
    uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

    assertEq(actualUsd, expectedUsd);
  }

  function test_depositCollateral_revertsIfCollateralIsZero() public {
    vm.startPrank(USER);
    ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.depositCollateral(weth, 0);
    vm.stopPrank();
  }

  function test_depositCollateral_revertsWithUnapprovedCollateral() public {
    ERC20Mock randomToken = new ERC20Mock();

    vm.startPrank(USER);
    vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
    engine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
  }

  function test_depositCollateral_getCount() public depositedCollateral {
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
    uint256 expectedTotalDscMinted = 0;
    uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

    assertEq(totalDscMinted, expectedTotalDscMinted);
    assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
  }

  function test_mintDsc_revertsWhenHasNoCollateral() public {
    uint256 expectedHealthFactor = 0;

    vm.prank(USER);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
    engine.mintDsc(AMOUNT_COLLATERAL);
  }

  function test_mintDsc_whenHavingCollateralCanMintEventEmitsStateExpected() public depositedCollateral {
    vm.prank(USER);
    vm.expectEmit(true, true, false, true);
    emit DSCEngine.DSCMinted(USER, COLLATERAL_MAX_HEALTHY_USD_MINT);
    engine.mintDsc(COLLATERAL_MAX_HEALTHY_USD_MINT);
  }

  function test_redeemCollateral_revertsWhenValueIsZero() public {
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.redeemCollateral(weth, 0);
  }

  function test_redeemCollateral_canRedeemCollateralOnHealthFactorOkEventEmits() public depositedCollateral {
    uint256 userBalanceBefore = ERC20Mock(weth).balanceOf(USER);

    vm.prank(USER);
    vm.expectEmit(true, true, true, true);
    emit DSCEngine.CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL);
    engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
    uint256 userBalanceAfter = ERC20Mock(weth).balanceOf(USER);

    assertEq(userBalanceAfter, userBalanceBefore + AMOUNT_COLLATERAL);
  }

  function test_redeemCollateral_revertsWhenHealthFactorLowerThanMin() public {
    test_mintDsc_whenHavingCollateralCanMintEventEmitsStateExpected();

    uint256 expectedHealthFactor = 5e17;
    vm.prank(USER);
    vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
    engine.redeemCollateral(weth, AMOUNT_COLLATERAL / 2);
  }

  function test_liquidate_revertsWhenDebtToCoverIsZero() public {
    vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
    engine.liquidate(weth, address(0), 0);
  }

  function test_liquidate_revertsWhenHealthFactorIsOk() public {
    test_mintDsc_whenHavingCollateralCanMintEventEmitsStateExpected();

    vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
    engine.liquidate(weth, USER, AMOUNT_COLLATERAL);
  }

//  function test_liquidate_canLiquidateWhenHealthFactorLower() public {
//    test_mintDsc_whenHavingCollateralCanMintEventEmitsStateExpected();
//
//    MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ETH_USD_DEFAULT_ANSWER / 2);
//    uint256 startingBalanceAdjusted = STARTING_ERC20_BALANCE * 2;
//    ERC20Mock(weth).mint(address(this), startingBalanceAdjusted);
//    ERC20Mock(weth).approve(address(engine), startingBalanceAdjusted);
//    engine.depositCollateralAndMintDsc(weth, startingBalanceAdjusted, COLLATERAL_MAX_HEALTHY_USD_MINT);
//
//    vm.expectEmit(true, true, false, true);
//    emit DSCEngine.Liquidated(address(this), USER);
//    engine.liquidate(weth, USER, COLLATERAL_MAX_HEALTHY_USD_MINT);
//  }
}