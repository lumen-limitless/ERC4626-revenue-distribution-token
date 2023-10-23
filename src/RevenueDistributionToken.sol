// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/*
    ██████╗ ██████╗ ████████╗
    ██╔══██╗██╔══██╗╚══██╔══╝
    ██████╔╝██║  ██║   ██║
    ██╔══██╗██║  ██║   ██║
    ██║  ██║██████╔╝   ██║
    ╚═╝  ╚═╝╚═════╝    ╚═╝
*/

contract RevenueDistributionToken is ERC20, Ownable {
    // =============================================================
    //                       EVENTS
    // =============================================================

    /**
     *  @dev   `caller_` has exchanged `assets_` for `shares_` and transferred them to `owner_`.
     *         MUST be emitted when assets are deposited via the `deposit` or `mint` methods.
     *  @param caller_ The caller of the function that emitted the `Deposit` event.
     *  @param owner_  The owner of the shares.
     *  @param assets_ The amount of assets deposited.
     *  @param shares_ The amount of shares minted.
     */
    event Deposit(address indexed caller_, address indexed owner_, uint256 assets_, uint256 shares_);

    /**
     *  @dev   `caller_` has exchanged `shares_`, owned by `owner_`, for `assets_`, and transferred them to `receiver_`.
     *         MUST be emitted when assets are withdrawn via the `withdraw` or `redeem` methods.
     *  @param caller_   The caller of the function that emitted the `Withdraw` event.
     *  @param receiver_ The receiver of the assets.
     *  @param owner_    The owner of the shares.
     *  @param assets_   The amount of assets withdrawn.
     *  @param shares_   The amount of shares burned.
     */
    event Withdraw(
        address indexed caller_, address indexed receiver_, address indexed owner_, uint256 assets_, uint256 shares_
    );

    /**
     *  @dev   Issuance parameters have been updated after a `_mint` or `_burn`.
     *  @param freeAssets_   Resulting `freeAssets` (y-intercept) value after accounting update.
     *  @param issuanceRate_ The new issuance rate of `asset` until `vestingPeriodFinish_`.
     */
    event IssuanceParamsUpdated(uint256 freeAssets_, uint256 issuanceRate_);

    /**
     *  @dev   `newOwner_` has accepted the transferral of RDT ownership from `previousOwner_`.
     *  @param previousOwner_ The previous RDT owner.
     *  @param newOwner_      The new RDT owner.
     */
    event OwnershipAccepted(address indexed previousOwner_, address indexed newOwner_);

    /**
     *  @dev   `owner_` has set the new pending owner of RDT to `pendingOwner_`.
     *  @param owner_        The current RDT owner.
     *  @param pendingOwner_ The new pending RDT owner.
     */
    event PendingOwnerSet(address indexed owner_, address indexed pendingOwner_);

    /**
     *  @dev   `owner_` has updated the RDT vesting schedule to end at `vestingPeriodFinish_`.
     *  @param owner_               The current RDT owner.
     *  @param vestingPeriodFinish_ When the unvested balance will finish vesting.
     */
    event VestingScheduleUpdated(address indexed owner_, uint256 vestingPeriodFinish_);

    // =============================================================
    //                       ERRORS
    // =============================================================

    error InvalidConstructorArgs();
    error ZeroReceiver();
    error ZeroShares();
    error ZeroAssets();
    error ZeroSupply();
    error InsufficientPermit();
    error NoReentrancy();

    // =============================================================
    //                       IMMUTABLES
    // =============================================================

    uint256 public immutable precision; // Precision of rates, equals max deposit amounts before rounding errors occur

    // =============================================================
    //                       STORAGE
    // =============================================================

    address public asset; // Underlying ERC-20 asset used by ERC-4626 functionality.

    uint256 public freeAssets; // Amount of assets unlocked regardless of time passed.
    uint256 public issuanceRate; // asset/second rate dependent on aggregate vesting schedule.
    uint256 public lastUpdated; // Timestamp of when issuance equation was last updated.
    uint256 public vestingPeriodFinish; // Timestamp when current vesting schedule ends.

    uint256 private _locked = 1; // Used in reentrancy check.

    string private _name;

    string private _symbol;

    // =============================================================
    //                       MODIFIERS
    // =============================================================

    modifier nonReentrant() {
        if (_locked == 2) revert NoReentrancy();

        _locked = 2;

        _;

        _locked = 1;
    }

    // =============================================================
    //                       CONSTRUCTOR
    // =============================================================

    constructor(string memory name_, string memory symbol_, address owner_, address asset_, uint256 precision_) {
        if (asset_ == address(0)) revert InvalidConstructorArgs();
        if (owner_ == address(0)) revert InvalidConstructorArgs();
        _initializeOwner(owner_);

        asset = asset_;
        precision = precision_;

        _name = name_;
        _symbol = symbol_;
    }

    // =============================================================
    //                       OWNER FUNCTIONS
    // =============================================================

    function updateVestingSchedule(uint256 vestingPeriod_)
        external
        virtual
        onlyOwner
        returns (uint256 issuanceRate_, uint256 freeAssets_)
    {
        if (totalSupply() == 0) revert ZeroSupply();

        // Update "y-intercept" to reflect current available asset.
        freeAssets_ = freeAssets = totalAssets();

        // Calculate slope.
        issuanceRate_ =
            issuanceRate = ((ERC20(asset).balanceOf(address(this)) - freeAssets_) * precision) / vestingPeriod_;

        // Update timestamp and period finish.
        vestingPeriodFinish = (lastUpdated = block.timestamp) + vestingPeriod_;

        emit IssuanceParamsUpdated(freeAssets_, issuanceRate_);
        emit VestingScheduleUpdated(msg.sender, vestingPeriodFinish);
    }

    // =============================================================
    //                       STAKER FUNCTIONS
    // =============================================================

    function deposit(uint256 assets_, address receiver_) external virtual nonReentrant returns (uint256 shares_) {
        _mint(shares_ = previewDeposit(assets_), assets_, receiver_, msg.sender);
    }

    function depositWithPermit(uint256 assets_, address receiver_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_)
        external
        virtual
        nonReentrant
        returns (uint256 shares_)
    {
        ERC20(asset).permit(msg.sender, address(this), assets_, deadline_, v_, r_, s_);
        _mint(shares_ = previewDeposit(assets_), assets_, receiver_, msg.sender);
    }

    function mint(uint256 shares_, address receiver_) external virtual nonReentrant returns (uint256 assets_) {
        _mint(shares_, assets_ = previewMint(shares_), receiver_, msg.sender);
    }

    function mintWithPermit(
        uint256 shares_,
        address receiver_,
        uint256 maxAssets_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external virtual nonReentrant returns (uint256 assets_) {
        if ((assets_ = previewMint(shares_)) > maxAssets_) revert InsufficientPermit();

        ERC20(asset).permit(msg.sender, address(this), maxAssets_, deadline_, v_, r_, s_);
        _mint(shares_, assets_, receiver_, msg.sender);
    }

    function redeem(uint256 shares_, address receiver_, address owner_)
        external
        virtual
        nonReentrant
        returns (uint256 assets_)
    {
        _burn(shares_, assets_ = previewRedeem(shares_), receiver_, owner_, msg.sender);
    }

    function withdraw(uint256 assets_, address receiver_, address owner_)
        external
        virtual
        nonReentrant
        returns (uint256 shares_)
    {
        _burn(shares_ = previewWithdraw(assets_), assets_, receiver_, owner_, msg.sender);
    }

    // =============================================================
    //                       INTERNAL FUNCTIONS
    // =============================================================

    function _mint(uint256 shares_, uint256 assets_, address receiver_, address caller_) internal {
        if (receiver_ == address(0)) revert ZeroReceiver();
        if (shares_ == uint256(0)) revert ZeroShares();
        if (assets_ == uint256(0)) revert ZeroAssets();

        _mint(receiver_, shares_);

        uint256 freeAssetsCache = freeAssets = totalAssets() + assets_;

        uint256 issuanceRate_ = _updateIssuanceParams();

        emit Deposit(caller_, receiver_, assets_, shares_);
        emit IssuanceParamsUpdated(freeAssetsCache, issuanceRate_);

        SafeTransferLib.safeTransferFrom(asset, caller_, address(this), assets_);
    }

    function _burn(uint256 shares_, uint256 assets_, address receiver_, address owner_, address caller_) internal {
        if (receiver_ == address(0)) revert ZeroReceiver();
        if (shares_ == uint256(0)) revert ZeroShares();
        if (assets_ == uint256(0)) revert ZeroAssets();

        if (caller_ != owner_) {
            _spendAllowance(owner_, caller_, shares_);
        }

        _burn(owner_, shares_);

        uint256 freeAssetsCache = freeAssets = totalAssets() - assets_;

        uint256 issuanceRate_ = _updateIssuanceParams();

        emit Withdraw(caller_, receiver_, owner_, assets_, shares_);
        emit IssuanceParamsUpdated(freeAssetsCache, issuanceRate_);

        SafeTransferLib.safeTransfer(asset, receiver_, assets_);
    }

    function _updateIssuanceParams() internal returns (uint256 issuanceRate_) {
        return issuanceRate = (lastUpdated = block.timestamp) > vestingPeriodFinish ? 0 : issuanceRate;
    }

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        return (numerator_ / divisor_) + (numerator_ % divisor_ > 0 ? 1 : 0);
    }

    // =============================================================
    //                       VIEW FUNCTIONS
    // =============================================================

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function balanceOfAssets(address account_) public view virtual returns (uint256 balanceOfAssets_) {
        return convertToAssets(balanceOf(account_));
    }

    function convertToAssets(uint256 shares_) public view virtual returns (uint256 assets_) {
        uint256 supply = totalSupply(); // Cache to stack.

        assets_ = supply == 0 ? shares_ : (shares_ * totalAssets()) / supply;
    }

    function convertToShares(uint256 assets_) public view virtual returns (uint256 shares_) {
        uint256 supply = totalSupply(); // Cache to stack.

        shares_ = supply == 0 ? assets_ : (assets_ * supply) / totalAssets();
    }

    function maxDeposit(address receiver_) external pure virtual returns (uint256 maxAssets_) {
        receiver_; // Silence warning
        maxAssets_ = type(uint256).max;
    }

    function maxMint(address receiver_) external pure virtual returns (uint256 maxShares_) {
        receiver_; // Silence warning
        maxShares_ = type(uint256).max;
    }

    function maxRedeem(address owner_) external view virtual returns (uint256 maxShares_) {
        maxShares_ = balanceOf(owner_);
    }

    function maxWithdraw(address owner_) external view virtual returns (uint256 maxAssets_) {
        maxAssets_ = balanceOfAssets(owner_);
    }

    function previewDeposit(uint256 assets_) public view virtual returns (uint256 shares_) {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of shares to issue to a user, given an amount of assets provided.
        shares_ = convertToShares(assets_);
    }

    function previewMint(uint256 shares_) public view virtual returns (uint256 assets_) {
        uint256 supply = totalSupply(); // Cache to stack.

        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of assets a user must provide, to be issued a given amount of shares.
        assets_ = supply == 0 ? shares_ : _divRoundUp(shares_ * totalAssets(), supply);
    }

    function previewRedeem(uint256 shares_) public view virtual returns (uint256 assets_) {
        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round DOWN if it’s calculating the amount of assets to send to a user, given amount of shares returned.
        assets_ = convertToAssets(shares_);
    }

    function previewWithdraw(uint256 assets_) public view virtual returns (uint256 shares_) {
        uint256 supply = totalSupply(); // Cache to stack.

        // As per https://eips.ethereum.org/EIPS/eip-4626#security-considerations,
        // it should round UP if it’s calculating the amount of shares a user must return, to be sent a given amount of assets.
        shares_ = supply == 0 ? assets_ : _divRoundUp(assets_ * supply, totalAssets());
    }

    function totalAssets() public view virtual returns (uint256 totalManagedAssets_) {
        uint256 issuanceRate_ = issuanceRate;

        if (issuanceRate_ == 0) return freeAssets;

        uint256 vestingPeriodFinish_ = vestingPeriodFinish;
        uint256 lastUpdated_ = lastUpdated;

        uint256 vestingTimePassed = block.timestamp > vestingPeriodFinish_
            ? vestingPeriodFinish_ - lastUpdated_
            : block.timestamp - lastUpdated_;

        return ((issuanceRate_ * vestingTimePassed) / precision) + freeAssets;
    }
}
