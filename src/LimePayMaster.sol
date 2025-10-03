// SPDX-License-Identifier: MIT ft @vvcc77 & @PhoenixZeroph
pragma solidity ^0.8.24;

import {BasePaymaster, IEntryPoint, UserOperation, PostOpMode} 
  from "@openzeppelin/contracts/account-abstraction/core/BasePaymaster.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPriceOracle {
    function peek() external view returns (uint256 priceRay, uint256 updatedAt);
}

interface IERC20Permit {
    function permit(
        address owner, address spender, uint256 value, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external;
}

contract LimePaymaster is BasePaymaster {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IPriceOracle public oracle;

    uint256 public constant RAY = 1e27;
    uint256 public MAX_PRICE_AGE = 60;
    uint256 public MAX_USD_PER_TX = 50e6; // 50 USDC
    uint256 public MAX_USD_PER_USER_WINDOW = 500e6;
    uint256 public WINDOW = 1 days;
    uint256 public windowEpoch;

    mapping(address => uint256) public spentWindow;

    error StalePrice();
    error ExceedsCap();
    error InvalidPermit();

    constructor(IEntryPoint entryPoint_, IERC20 usdc_, IPriceOracle oracle_) BasePaymaster(entryPoint_) {
        usdc = usdc_;
        oracle = oracle_;
    }

    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        (uint256 priceRay, uint256 updatedAt) = oracle.peek();
        if (block.timestamp - updatedAt > MAX_PRICE_AGE) revert StalePrice();

        uint256 usdc18 = (maxCost * priceRay) / RAY;
        uint256 usdc6  = usdc18 / 1e12;
        if (usdc6 > MAX_USD_PER_TX) revert ExceedsCap();

        address sender = userOp.getSender();
        _rollWindow();
        spentWindow[sender] += usdc6;
        if (spentWindow[sender] > MAX_USD_PER_USER_WINDOW) revert ExceedsCap();

        // Try consume permit (if passed in paymasterAndData)
        if (userOp.paymasterAndData.length > 20) {
            // decode: [paymasterAddress, owner, value, deadline, v,r,s]
            (, address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
                abi.decode(userOp.paymasterAndData[20:], (address, address, uint256, uint256, uint8, bytes32, bytes32));
            IERC20Permit(address(usdc)).permit(owner, address(this), value, deadline, v, r, s);
        }

        usdc.safeTransferFrom(sender, address(this), usdc6);
        context = abi.encode(sender, usdc6);
        validationData = 0;
    }

    function _postOp(PostOpMode, bytes calldata, uint256) internal override {}

    function _rollWindow() internal {
        uint256 epoch = block.timestamp / WINDOW;
        if (epoch != windowEpoch) {
            windowEpoch = epoch;
            // Simplificado; en prod se limpia mapping o se usa decay
        }
    }
}
