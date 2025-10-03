// SPDX-License-Identifier: MIT - @vvcc77 ft @PhoenixZeroph Auditor
pragma solidity ^0.8.24;

/**
 * LimeVault — Protocolo de micro-ahorros disciplinados
 * - Locks de 30/90 días hasta 50 años
 * - Ahorro a largo plazo (no especulación)
 * - Seguridad OWASP: CEI, SafeERC20, ReentrancyGuard, Pausable
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LimeVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant DAY = 1 days;
    uint256 public constant MIN_LOCK_DAYS_SHORT = 30;
    uint256 public constant MIN_LOCK_DAYS_MEDIUM = 90;
    uint256 public constant MAX_LOCK_YEARS = 50;
    uint256 public constant MAX_LOCK_SECONDS = MAX_LOCK_YEARS * 365 days;

    IERC20 public immutable token;
    address public treasury;

    mapping(uint256 => bool) public allowedDurations;

    struct Position {
        address owner;
        uint128 amount;
        uint64 start;
        uint64 duration;
        bool claimed;
    }

    uint256 public nextPositionId = 1;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) private _userPositions;

    event DurationAllowed(uint256 duration);
    event DurationRemoved(uint256 duration);
    event PositionCreated(uint256 indexed id, address indexed user, uint256 amount, uint256 duration, uint256 start);
    event PositionClaimed(uint256 indexed id, address indexed user, uint256 amount, uint256 when);

    error InvalidAmount();
    error DurationNotAllowed();
    error DurationTooLong();
    error NotOwner();
    error AlreadyClaimed();
    error NotMature();

    constructor(IERC20 _token, address _owner, address _treasury) Ownable(_owner) {
        require(address(_token) != address(0), "token=0");
        token = _token;
        treasury = _treasury;

        uint256 d30 = MIN_LOCK_DAYS_SHORT * DAY;
        uint256 d90 = MIN_LOCK_DAYS_MEDIUM * DAY;
        allowedDurations[d30] = true;
        allowedDurations[d90] = true;

        emit DurationAllowed(d30);
        emit DurationAllowed(d90);
    }

    function createPosition(uint256 amount, uint256 lockDurationSeconds) external whenNotPaused nonReentrant returns (uint256 id) {
        if (amount == 0) revert InvalidAmount();
        if (!allowedDurations[lockDurationSeconds]) revert DurationNotAllowed();
        if (lockDurationSeconds > MAX_LOCK_SECONDS) revert DurationTooLong();

        id = nextPositionId++;
        positions[id] = Position({
            owner: msg.sender,
            amount: uint128(amount),
            start: uint64(block.timestamp),
            duration: uint64(lockDurationSeconds),
            claimed: false
        });
        _userPositions[msg.sender].push(id);

        emit PositionCreated(id, msg.sender, amount, lockDurationSeconds, block.timestamp);
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function claim(uint256 id) external whenNotPaused nonReentrant {
        Position storage p = positions[id];
        if (p.owner != msg.sender) revert NotOwner();
        if (p.claimed) revert AlreadyClaimed();
        if (block.timestamp < uint256(p.start) + uint256(p.duration)) revert NotMature();

        p.claimed = true;
        token.safeTransfer(msg.sender, uint256(p.amount));
        emit PositionClaimed(id, msg.sender, p.amount, block.timestamp);
    }

    function allowDuration(uint256 seconds_) external onlyOwner {
        require(seconds_ >= MIN_LOCK_DAYS_SHORT * DAY, "min 30d");
        require(seconds_ <= MAX_LOCK_SECONDS, "max 50y");
        allowedDurations[seconds_] = true;
        emit DurationAllowed(seconds_);
    }

    function removeDuration(uint256 seconds_) external onlyOwner {
        allowedDurations[seconds_] = false;
        emit DurationRemoved(seconds_);
    }

    function userPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }
}
