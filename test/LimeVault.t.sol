// SPDX-License-Identifier: MIT ft @vvcc77 & @PhoenixZeroph
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {LimeVault} from "../src/LimeVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is IERC20 {
    string public name = "MockToken";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "bal");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function approve(address s, uint256 v) external returns (bool) {
        allowance[msg.sender][s] = v;
        emit Approval(msg.sender, s, v);
        return true;
    }
    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        require(balanceOf[f] >= v, "bal");
        uint256 a = allowance[f][msg.sender]; require(a >= v, "allow");
        allowance[f][msg.sender] = a - v;
        balanceOf[f] -= v; balanceOf[t] += v;
        emit Transfer(f, t, v);
        return true;
    }
    function mint(address to, uint256 v) external {
        balanceOf[to] += v; totalSupply += v; emit Transfer(address(0), to, v);
    }
}

contract LimeVaultTest is Test {
    LimeVault vault;
    MockERC20 token;
    address user = address(0xBEEF);

    function setUp() public {
        token = new MockERC20();
        token.mint(user, 100e18);
        vault = new LimeVault(IERC20(address(token)), address(this), address(0));
        vm.prank(user);
        token.approve(address(vault), type(uint256).max);
    }

    function test_CreateAndClaim30d() public {
        vm.startPrank(user);
        uint256 id = vault.createPosition(10e18, 30 days);
        vm.warp(block.timestamp + 30 days);
        vault.claim(id);
        vm.stopPrank();
    }

    function test_RevertNotMature() public {
        vm.startPrank(user);
        uint256 id = vault.createPosition(1e18, 30 days);
        vm.expectRevert(LimeVault.NotMature.selector);
        vault.claim(id);
        vm.stopPrank();
    }
}
