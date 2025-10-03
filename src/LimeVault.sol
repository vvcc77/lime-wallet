// SPDX-License-Identifier: MIT ft @vvcc77 & @PhoenixZeroph Auditor
pragma solidity ^0.8.24;

/**
 * LimeVault — Protocolo de micro-ahorros disciplinados (multi-token)
 * - Locks de 30/90 días hasta 50 años
 * - Mínimo de entrada: USD 3 (en tokens soportados) usando oráculo
 * - Retiro anticipado con penalidad del 20% (enviado a treasury)
 * - Retiro al vencimiento con costo 0
 * - OWASP: CEI, SafeERC20, ReentrancyGuard, Pausable
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUsdPriceOracle {
    /**
     * @dev Debe retornar precio del token expresado en USD con 8 decimales (estilo Chainlink)
     * p.ej. 1.00 USD => 1e8, 0.99 USD => 99_000_000
     */
    function latestAnswer() external view returns (int256);
}

contract LimeVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Constantes & parámetros ---
    uint256 public constant DAY = 1 days;
    uint256 public constant MIN_LOCK_DAYS_SHORT = 30;
    uint256 public constant MIN_LOCK_DAYS_MEDIUM = 90;
    uint256 public constant MAX_LOCK_YEARS = 50;
    uint256 public constant MAX_LOCK_SECONDS = MAX_LOCK_YEARS * 365 days;

    uint256 public constant USD_DECIMALS = 6;       // USD en 6 dec para comparaciones (p.ej., 3 USDC = 3_000_000)
    uint256 public constant ORACLE_DECIMALS = 8;    // oráculo USD con 8 dec
    uint256 public constant MIN_USD_6DEC = 3_000_000; // US$3 mínimos
    uint256 public constant PENALTY_BPS = 2000;     // 20% (basis points)

    // --- Registro de tokens soportados ---
    struct TokenConfig {
        bool allowed;
        uint8 decimals;               // decimales del token ERC20
        IUsdPriceOracle oracle;       // oráculo USD (8 dec)
    }
    mapping(address => TokenConfig) public tokens;  // token => config

    // --- Duraciones permitidas ---
    mapping(uint256 => bool) public allowedDurations; // segundos => permitido

    // --- Modelo de posición ---
    struct Position {
        address owner;
        address token;       // ERC20 de la posición
        uint128 amount;      // cantidad bloqueada (en unidades de token)
        uint64  start;       // timestamp block
        uint64  duration;    // segundos
        bool    claimed;     // retirado (sea por madurez o early)
    }

    uint256 public nextPositionId = 1;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) private _userPositions;

    // --- Tesorería (recibe penalidades) ---
    address public treasury;

    // --- Eventos ---
    event DurationAllowed(uint256 duration);
    event DurationRemoved(uint256 duration);
    event TokenAllowed(address indexed token, uint8 decimals, address indexed oracle);
    event TokenRemoved(address indexed token);
    event PositionCreated(uint256 indexed id, address indexed user, address indexed token, uint256 amount, uint256 duration, uint256 start);
    event PositionClaimed(uint256 indexed id, address indexed user, uint256 amountNet, uint256 when, bool matured, uint256 penaltyAmount);
    event TreasuryUpdated(address indexed newTreasury);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // --- Errores ---
    error InvalidAmount();
    error DurationNotAllowed();
    error DurationTooLong();
    error TokenNotAllowed();
    error NotOwner();
    error AlreadyClaimed();
    error NotMature();
    error OracleError();
    error BelowMinDeposit();

    constructor(address _owner, address _treasury) Ownable(_owner) {
        treasury = _treasury;

        // Duraciones iniciales
        uint256 d30 = MIN_LOCK_DAYS_SHORT * DAY;
        uint256 d90 = MIN_LOCK_DAYS_MEDIUM * DAY;
        allowedDurations[d30] = true;
        allowedDurations[d90] = true;
        emit DurationAllowed(d30);
        emit DurationAllowed(d90);
        emit TreasuryUpdated(_treasury);
    }

    // ---------------------------
    //           Core
    // ---------------------------

    /**
     * @notice Crea una posición bloqueando un token permitido por una duración whitelisteada.
     * @param token ERC20 del aporte
     * @param amount cantidad del token (debe cumplir mínimo USD 3)
     * @param lockDurationSeconds duración (debe estar en allowedDurations)
     */
    function createPosition(address token, uint256 amount, uint256 lockDurationSeconds)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 id)
    {
        if (!tokens[token].allowed) revert TokenNotAllowed();
        if (amount == 0) revert InvalidAmount();
        if (!allowedDurations[lockDurationSeconds]) revert DurationNotAllowed();
        if (lockDurationSeconds > MAX_LOCK_SECONDS) revert DurationTooLong();

        // Validar USD mínimo vía oráculo
        _enforceMinUsd(token, amount);

        // Effects
        id = nextPositionId++;
        positions[id] = Position({
            owner: msg.sender,
            token: token,
            amount: uint128(amount),
            start: uint64(block.timestamp),
            duration: uint64(lockDurationSeconds),
            claimed: false
        });
        _userPositions[msg.sender].push(id);

        emit PositionCreated(id, msg.sender, token, amount, lockDurationSeconds, block.timestamp);

        // Interactions: pull tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Reclamo al vencer (sin costo).
     */
    function claim(uint256 id) external whenNotPaused nonReentrant {
        Position storage p = positions[id];
        if (p.owner != msg.sender) revert NotOwner();
        if (p.claimed) revert AlreadyClaimed();
        if (!_isMature(p)) revert NotMature();

        p.claimed = true;
        uint256 amt = uint256(p.amount);

        IERC20(p.token).safeTransfer(msg.sender, amt);
        emit PositionClaimed(id, msg.sender, amt, block.timestamp, true, 0);
    }

    /**
     * @notice Retiro anticipado con penalidad 20% -> enviado a `treasury`.
     */
    function withdrawEarly(uint256 id) external whenNotPaused nonReentrant {
        Position storage p = positions[id];
        if (p.owner != msg.sender) revert NotOwner();
        if (p.claimed) revert AlreadyClaimed();

        p.claimed = true;
        uint256 amt = uint256(p.amount);
        uint256 penalty = (amt * PENALTY_BPS) / 10_000;
        uint256 net = amt - penalty;

        if (penalty > 0 && treasury != address(0)) {
            IERC20(p.token).safeTransfer(treasury, penalty);
        }
        IERC20(p.token).safeTransfer(msg.sender, net);

        emit PositionClaimed(id, msg.sender, net, block.timestamp, false, penalty);
    }

    // ---------------------------
    //          Admin
    // ---------------------------

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

    function allowToken(address token, uint8 decimals_, IUsdPriceOracle oracle) external onlyOwner {
        require(token != address(0) && address(oracle) != address(0), "zero addr");
        tokens[token] = TokenConfig({allowed: true, decimals: decimals_, oracle: oracle});
        emit TokenAllowed(token, decimals_, address(oracle));
    }

    function removeToken(address token) external onlyOwner {
        delete tokens[token];
        emit TokenRemoved(token);
    }

    function setTreasury(address t) external onlyOwner {
        treasury = t;
        emit TreasuryUpdated(t);
    }

    function pause() external onlyOwner { _pause(); emit Paused(msg.sender); }
    function unpause() external onlyOwner { _unpause(); emit Unpaused(msg.sender); }

    // ---------------------------
    //           Views
    // ---------------------------

    function userPositions(address user) external view returns (uint256[] memory) {
        return _userPositions[user];
    }

    function positionMaturity(uint256 id) external view returns (uint256) {
        Position memory p = positions[id];
        return uint256(p.start) + uint256(p.duration);
    }

    function isMature(uint256 id) external view returns (bool) {
        return _isMature(positions[id]);
    }

    // ---------------------------
    //         Internals
    // ---------------------------

    function _isMature(Position memory p) internal view returns (bool) {
        return p.start > 0 && !p.claimed && (block.timestamp >= uint256(p.start) + uint256(p.duration));
    }

    function _enforceMinUsd(address token, uint256 amount) internal view {
        TokenConfig memory cfg = tokens[token];
        if (!cfg.allowed) revert TokenNotAllowed();

        int256 price8 = cfg.oracle.latestAnswer(); // USD con 8 dec
        if (price8 <= 0) revert OracleError();

        // usd_8dec = amount * price(1e8) / 10^tokenDecimals
        uint256 usd8 = (amount * uint256(price8)) / (10 ** cfg.decimals);

        // convertimos 8 dec -> 6 dec dividiendo por 100 (redondeo hacia abajo conserva prudencia)
        uint256 usd6 = usd8 / 100;

        if (usd6 < MIN_USD_6DEC) revert BelowMinDeposit();
    }
}
