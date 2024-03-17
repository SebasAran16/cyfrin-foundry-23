// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EngineHandler} from "./EngineHandler.t.sol";


contract EngineInvariantsTest is StdInvariant, Test  {
  DeployDSC public engineDeployer;
  DSCEngine public engine;
  DecentralizedStableCoin public dsc;
  HelperConfig public helperConfig;
  IERC20 public weth;
  IERC20 public wbtc;
  EngineHandler public handler;

  function setUp() external {
    engineDeployer = new DeployDSC();

    (dsc, engine, helperConfig) = engineDeployer.run();
    (,, address wethAddress, address wbtcAddress) = helperConfig.activeNetworkConfig();
    weth = IERC20(wethAddress);
    wbtc = IERC20(wbtcAddress);

    handler = new EngineHandler(engine, dsc);
    targetContract(address(handler));
  }

  function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
    uint256 totalSupply = dsc.totalSupply();
    uint256 totalWethDeposited = weth.balanceOf(address(engine));
    uint256 totalWbtcDeposited = wbtc.balanceOf(address(engine));

    uint256 wethValue = engine.getUsdValue(address(weth), totalWethDeposited);
    uint256 wbtcValue = engine.getUsdValue(address(wbtc), totalWbtcDeposited);

    console.log("Weth Value", wethValue);
    console.log("Wbtc Value", wbtcValue);
    console.log("Total Supply", totalSupply);
    console.log("Times mint called:", handler.timesMintIsCalled());

    assert(wethValue + wbtcValue >= totalSupply);
  }

  function invariant_gettersShouldNotRevert() public view {
    engine.getAccountCollateralValueInUsd(msg.sender);
    engine.getAccountInformation(msg.sender);
    engine.getCollateralTokens();
  }
}