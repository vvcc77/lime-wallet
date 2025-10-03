// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LimeVault, IUsdPriceOracle} from "../src/LimeVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockOracle is IUsdPriceOracle {
    int256 public price8;
    function set(int256 p) external { price8 = p; }
    function latestAnswer() external view returns (int256) { return price8; }
}

contract MockERC20 is IERC20 {
    string public name; string public symbol; uint8 public decimals;
    uint256 public totalSupply;
    mapping(address=>uint256) public balanceOf;
    mapping(address=>mapping(address=>uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory n, string memory s, uint8 d) { name=n; symbol=s; decimals=d; }

    function transfer(address to, uint256 v) external returns (bool){
        require(balanceOf[msg.sender]>=v,"bal"); balanceOf[msg.sender]-=v; balanceOf[to]+=v; emit Transfer(msg.sender,to,v); return true;
    }
    function approve(address s, uint256 v) external returns (bool){
        allowance[msg.sender][s]=v; emit Approval(msg.sender,s,v); return true;
    }
    function transferFrom(address f,address t,uint256 v) external returns (bool){
        require(balanceOf[f]>=v,"bal");
        uint256 a=allowance[f][msg.sender]; require(a>=v,"allow"); allowance[f][msg.sender]=a-v;
        balanceOf[f]-=v; balanceOf[t]+=v; emit Transfer(f,t,v); return true;
    }
    function mint(address to, uint256 v) external { balanceOf[to]+=v; totalSupply+=v; emit Transfer(address(0), to, v); }
}

contract LimeVaultTest is Test {
    LimeVault vault;
    MockERC20 usdc;     // 6 dec
    MockERC20 dai;      // 18 dec
    MockOracle oracleUSDC;
    MockOracle oracleDAI;
    address user = address(0xBEEF);
    address tre = address(0xCAFE);

    function setUp() public {
        oracleUSDC = new MockOracle(); oracleUSDC.set(1e8); // 1 USDC ≈ $1
        oracleDAI  = new MockOracle(); oracleDAI.set(1e8);  // 1 DAI  ≈ $1

        vault = new LimeVault(address(this), tre);

        usdc = new MockERC20("USDC","USDC",6);
        dai  = new MockERC20("DAI","DAI",18);

        usdc.mint(user, 1000e6);
        dai.mint(user,  1000e18);

        vault.allowToken(address(usdc), 6, IUsdPriceOracle(address(oracleUSDC)));
        vault.allowToken(address(dai), 18, IUsdPriceOracle(address(oracleDAI)));

        // approve
        vm.startPrank(user);
        usdc.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test_Minimum3USD_Enforced_USDC() public {
        // 2.99 USDC debe fallar
        vm.startPrank(user);
        vm.expectRevert(LimeVault.BelowMinDeposit.selector);
        vault.createPosition(address(usdc), 2_990_000, 30 days); // 2.99 USDC
        vm.stopPrank();

        // 3 USDC ok
        vm.startPrank(user);
        uint256 id = vault.createPosition(address(usdc), 3_000_000, 30 days);
        vm.stopPrank();
        assertEq(id, 1);
    }

    function test_Minimum3USD_Enforced_DAI() public {
        // 2.99 DAI (18 dec) -> 2.99e18 -> fail
        vm.startPrank(user);
        vm.expectRevert(LimeVault.BelowMinDeposit.selector);
        vault.createPosition(address(dai), 2_99e16, 30 days); // 0.0299e18? cuidado: 2.99 * 1e18 = 2_990_000_000_000_000_000
        vm.stopPrank();

        // 3 DAI ok
        vm.startPrank(user);
        uint256 id = vault.createPosition(address(dai), 3e18, 30 days);
        vm.stopPrank();
        assertEq(id, 1);
    }

    function test_ClaimAtMaturity_NoFee() public {
        vm.startPrank(user);
        uint256 id = vault.createPosition(address(usdc), 10_000_000, 30 days); // 10 USDC
        vm.warp(block.timestamp + 30 days);
        uint256 balBefore = usdc.balanceOf(user);
        vault.claim(id);
        uint256 balAfter = usdc.balanceOf(user);
        vm.stopPrank();

        // neto = 10 USDC
        assertEq(balAfter - balBefore, 10_000_000);
    }

    function test_EarlyWithdraw_WithPenalty() public {
        vm.startPrank(user);
        uint256 id = vault.createPosition(address(usdc), 10_000_000, 90 days); // 10 USDC
        uint256 userBefore = usdc.balanceOf(user);
        uint256 treBefore  = usdc.balanceOf(tre);
        vault.withdrawEarly(id);
        uint256 userAfter = usdc.balanceOf(user);
        uint256 treAfter  = usdc.balanceOf(tre);
        vm.stopPrank();

        // penalidad 20%: 2 USDC → tesorería; 8 USDC → usuario
        assertEq(userAfter - userBefore, 8_000_000);
        assertEq(treAfter  - treBefore,  2_000_000);
    }
}
