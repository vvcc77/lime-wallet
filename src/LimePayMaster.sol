// SPDX-License-Identifier: MIT ft vvcc77 & PhoenixZeroph
pragma solidity 0.8.24;

/**
 * LimePaymaster – ERC-4337 Token Paymaster that lets users pay gas in USDC.
 * Patches Lemon’s “dual-token” pain: no ETH/MATIC needed by end-user.
 *
 * Audit targets: OWASP SC Top 10, Checks-Effects-Interactions.
 */
import {IERC20}  from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {BasePaymaster, UserOperation, IEntryPoint, PostOpMode} from
        "account-abstraction/contracts/core/BasePaymaster.sol";

interface IPriceOracle {
    /// @return ethPrice USD-scaled 1e8
    function ethUsdPrice() external view returns (uint256);
}

contract LimePaymaster is BasePaymaster, Ownable {
    IERC20  public immutable usdc;
    IPriceOracle public oracle;          // e.g. Chainlink ETH/USD
    uint256 public constant USDC_DECIMALS = 1e6;
    uint256 public feeMarkupBps = 1_000; // 10 % (100 bps = 1 %)

    constructor(
        address _entryPoint,
        address _usdc,
        address _oracle
    ) {
        _initializeOwner(msg.sender);
        usdc   = IERC20(_usdc);
        oracle = IPriceOracle(_oracle);
        _transferOwnership(msg.sender);
        ENTRY_POINT = IEntryPoint(_entryPoint);
    }

    /// Allow owner to tune markup or oracle
    function setConfig(address _oracle, uint256 _markupBps) external onlyOwner {
        oracle       = IPriceOracle(_oracle);
        feeMarkupBps = _markupBps;
    }

    // === Core ERC-4337 hooks ===
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 maxCost            // max ETH the op *might* cost
    )
        internal override returns (bytes memory context, uint256 validationData)
    {
        uint256 ethUsd = oracle.ethUsdPrice();   // 1e8 scale
        // Convert maxCost (wei) → USDC (6 dec) with markup buffer
        uint256 usdcOwed = (maxCost * ethUsd / 1e8) / 1e12; // wei→ETH→USD→USDC
        usdcOwed = usdcOwed * (10_000 + feeMarkupBps) / 10_000;

        require(
            usdc.allowance(userOp.sender, address(this)) >= usdcOwed,
            "Insufficient USDC allowance"
        );

        // Pull USDC upfront
        usdc.transferFrom(userOp.sender, address(this), usdcOwed);
        return ("", _packValidationData(false, 0, 0));
    }

    function _postOp(PostOpMode, bytes calldata, uint256) internal override {
        // No‑op – already charged. Could refund any diff if desired.
    }

    // === Admin  ops ===
    function sweepUSDC(address to, uint256 amount) external onlyOwner {
        usdc.transfer(to, amount);
    }

    receive() external payable {}
}
