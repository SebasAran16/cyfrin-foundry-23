// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EngineHandler is Test  {
  DSCEngine public engine;
  DecentralizedStableCoin public dsc;
  ERC20Mock public weth;
  ERC20Mock public wbtc;

  uint256 public timesMintIsCalled;
  address[] public usersWithCollateralDeposited;

  uint256 public MAX_DEPOSIT_SIZE = type(uint96).max;

  constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
    engine = _engine;
    dsc = _dsc;

    address[] memory collateralTokens = engine.getCollateralTokens();
    weth = ERC20Mock(collateralTokens[0]);
    wbtc = ERC20Mock(collateralTokens[1]);
  }

  function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, amountCollateral);
    collateral.approve(address(engine), amountCollateral);

    engine.depositCollateral(address(collateral), amountCollateral);
    vm.stopPrank();
    usersWithCollateralDeposited.push(msg.sender); // This double push if address repeats
  }

  function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));
    amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

    if (amountCollateral == 0) return;

    engine.redeemCollateral(address(collateral), amountCollateral);
  }

  function mintDsc(uint256 amount, uint256 addressSeed) public {
    if (usersWithCollateralDeposited.length == 0) return;

    address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
    int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
    if (maxDscToMint < 0) return;
    amount = bound(amount, 0, uint256(maxDscToMint));
    if (amount == 0) return;

    vm.prank(sender);
    engine.mintDsc(amount);
    timesMintIsCalled++;
  }

  // Helper Functions
  function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock) {
    if (collateralSeed % 2 == 0) {
      return weth;
    } else {
      return wbtc;
    }
  }
}