// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "./utils/IUniswapV2Factory.sol";
import "./utils/IUniswapV2Pair.sol";
import "./utils/IUniswapV2Router02.sol";
import "./utils/IERC20.sol";
import "./utils/TimeLock.sol";

/**
 * @notice ERC20 token with cost basis tracking and restricted loss-taking
 */
contract SEOCoin is IERC20, TimeLock {
    address private constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isAllowedTransfer;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _blackList;

    address[] private _excluded;

    string private _NAME;
    string private _SYMBOL;
    uint256 private _DECIMALS;

    uint256 private constant _MAX = ~uint256(0);
    uint256 private constant _GRANULARITY = 100;
    uint256 private constant _maxTeamMintAmount = 1e8 ether;

    uint256 private _tTotal;
    uint256 private _rTotal;

    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;
    uint256 private _tMarketingFeeTotal;

    uint256 public _TAX_FEE; // 3%
    uint256 public _BURN_FEE; // 3%
    uint256 public _MARKET_FEE; // 3%

    // Track original fees to bypass fees for charity account
    uint256 private mintedSupply;

    address private _shoppingCart;
    address private _rewardWallet;
    address private _pair;
    address private _owner;
    address private _preSale;

    bool private _paused;
    bool private _isEnableSwapTokenforEth;

    struct Minting {
        address recipient;
        uint256 amount;
    }

    struct StandardFees {
        uint256 taxFee;
        uint256 rewardFee;
        uint256 marketFee;
    }
    StandardFees private _standardFees;

    mapping(address => address) private _referralOwner;
    mapping(address => uint256) private _referralOwnerTotalFee;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        uint256 _supply,
        address[] memory blackList
    ) {
        _owner = msg.sender;
        _NAME = _name;
        _SYMBOL = _symbol;
        _DECIMALS = _decimals;
        _tTotal = _supply * (10**uint256(_DECIMALS));
        _rTotal = (_MAX - (_MAX % _tTotal));

        // setup uniswap pair and store address
        _pair = IUniswapV2Factory(IUniswapV2Router02(UNISWAP_ROUTER).factory()).createPair(
            IUniswapV2Router02(UNISWAP_ROUTER).WETH(),
            address(this)
        );
        _rOwned[address(this)] = _rTotal;
        _excludeAccount(msg.sender);
        _excludeAccount(address(this));
        _excludeAccount(_pair);
        _excludeAccount(UNISWAP_ROUTER);

        // prepare to add liquidity
        _approve(address(this), _owner, _rTotal);

        _paused = true;
        _isEnableSwapTokenforEth = false;

        if (blackList.length > 0) {
            for (uint256 k = 0; k < blackList.length; k++) {
                _blackList[blackList[k]] = true;
            }
        }

        _transfer(address(this), msg.sender, 40 * 1e7 ether);
    }

    modifier isNotPaused() {
        require(_paused == false, "ERR: paused already");
        _;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function name() external view returns (string memory) {
        return _NAME;
    }

    function symbol() external view returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external view returns (uint256) {
        return _DECIMALS;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function isExcluded(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    function totalBurn() external view returns (uint256) {
        return _tBurnTotal;
    }

    function totalMarketingFees() external view returns (uint256) {
        return _tMarketingFeeTotal;
    }

    function checkStandardFee()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (_standardFees.taxFee, _standardFees.rewardFee, _standardFees.marketFee);
    }

    function checkReferralReward(address referralOwner) external view returns (uint256) {
        return _referralOwnerTotalFee[referralOwner];
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) external view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        return rAmount / _getRate();
    }

    function excludeAccount(address account) external onlyOwner {
        _excludeAccount(account);
    }

    function _excludeAccount(address account) private {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
        _isAllowedTransfer[account] = true;
        excludeFromLock(account);
    }

    function includeAccount(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "TOKEN20: approve from the zero address");
        require(spender != address(0), "TOKEN20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function setBusinessWallet(address businessAddress) external onlyOwner isNotPaused returns (bool) {
        require(businessAddress != address(0), "ERR: zero address");
        _shoppingCart = businessAddress;
        uint256 cartAmount = 5e7 ether;
        setPermission(businessAddress, cartAmount);
        return true;
    }

    function setRewardAddress(address rewardAddress) external onlyOwner isNotPaused returns (bool) {
        require(rewardAddress != address(0), "ERR: zero address");
        _rewardWallet = rewardAddress;
        uint256 burnAmount = 35 * 1e7 ether;
        setPermission(rewardAddress, burnAmount);
        return true;
    }

    function setPreSale(address presale) external onlyOwner isNotPaused returns (bool) {
        require(presale != address(0), "ERR: zero address");
        _preSale = presale;
        uint256 presaleAmount = 10 * 1e7 ether;
        setPermission(presale, presaleAmount);
        return true;
    }

    function setSEOServicReward(address serviceAddress) external onlyOwner isNotPaused returns (bool) {
        require(serviceAddress != address(0), "ERR: zero address");
        setPermission(serviceAddress, 0);
        return true;
    }

    function setPermission(address _account, uint256 _amount) private returns (bool) {
        if (_amount > 0) {
            _removeFee();
            _transferFromExcluded(address(this), _account, _amount);
            _restoreAllFee();
        }
        _excludeAccount(_account);
        return true;
    }

    function setReferralOwner(address referralUser, address referralOwner) external returns (bool) {
        require(_referralOwner[referralUser] == address(0), "ERR: address registered already");
        require(referralUser != address(0), "ERR: zero address");
        require(referralOwner != address(0), "ERR: zero address");
        _referralOwner[referralUser] = referralOwner;
        return true;
    }

    function setStandardFee(StandardFees memory _standardFee) external onlyOwner isNotPaused returns (bool) {
        require(_standardFee.taxFee < 100 && _standardFee.rewardFee < 100 && _standardFee.marketFee < 100, "ERR: Fee is so high");
        _standardFees = _standardFee;
        return true;
    }

    function timeLockFromPresale(address _lockAddress, uint256 _lockTime) external returns (bool) {
        require(_preSale != address(0) && msg.sender == _preSale, "ERR: not presale");
        lockAddress(_lockAddress, uint64(_lockTime));
        return true;
    }

    function timeLockReleaseForPresale(address _lockAddress) external returns (bool) {
        require(_preSale != address(0) && msg.sender == _preSale, "ERR: not presale");
        if (!isUnLocked(_lockAddress)) {
            lockedRelease(_lockAddress);
        }
        return true;
    }

    function addBlackList(address blackAddress) external onlyOwner returns (bool) {
        require(blackAddress != _owner);
        require(!_blackList[blackAddress]);
        _blackList[blackAddress] = true;
        return true;
    }

    function removeBlackList(address removeAddress) external onlyOwner returns (bool) {
        require(_blackList[removeAddress]);
        require(removeAddress != _owner);
        _blackList[removeAddress] = false;
        return true;
    }

    function mintDev(Minting[] calldata mintings) external onlyOwner returns (bool) {
        require(mintings.length > 0, "ERR: zero address array");
        _removeFee();
        for (uint256 i = 0; i < mintings.length; i++) {
            Minting memory m = mintings[i];
            require(mintedSupply + m.amount <= _maxTeamMintAmount, "ERR: exceed max team mint amount");
            _transferFromExcluded(address(this), m.recipient, m.amount);
            mintedSupply += m.amount;
            lockAddress(m.recipient, uint64(180 days));
        }
        _restoreAllFee();
        return true;
    }

    function pausedEnable() external onlyOwner returns (bool) {
        require(!_paused, "ERR: already pause enabled");
        _paused = true;
        return true;
    }

    function pausedNotEnable() external onlyOwner returns (bool) {
        require(_paused, "ERR: already pause disabled");
        _paused = false;
        return true;
    }

    function swapTokenForEthEnable() external onlyOwner isNotPaused returns (bool) {
        require(!_isEnableSwapTokenforEth, "ERR: already enabled");
        _isEnableSwapTokenforEth = true;
        return true;
    }

    function swapTokenForEthDisable() external onlyOwner isNotPaused returns (bool) {
        require(_isEnableSwapTokenforEth, "ERR: already disabled");
        _isEnableSwapTokenforEth = false;
        return true;
    }

    function checkReferralOwner(address referralUser) external view returns (address) {
        require(referralUser != address(0), "ERR: zero address");
        return _referralOwner[referralUser];
    }

    function checkedTimeLock(address user) external view returns (bool) {
        return !isUnLocked(user);
    }

    function checkAllowedTransfer(address user) external view returns (bool) {
        return _isAllowedTransfer[user];
    }

    function _beforeTokenTransfer(address from, address to) private {
        require(!_blackList[from] && !_blackList[to]);
        if (from == _pair && !_isExcluded[to]) {
            require(isUnLocked(to), "ERR: address is locked(buy)");
        } else if (to == _pair && !_isExcluded[from]) {
            require(isUnLocked(from), "ERR: address is locked(sales)");
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        _beforeTokenTransfer(sender, recipient);
        _transferWithFee(sender, recipient, amount);
        emit Transfer(sender, recipient, amount);
    }

    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        if ((sender == _pair && !_isAllowedTransfer[recipient]) || (recipient == _pair && !_isAllowedTransfer[sender])) {
            if (recipient == _pair && !_isAllowedTransfer[sender]) {
                require(_isEnableSwapTokenforEth, "ERR: disabled swap");
            }
            _restoreAllFee();
        } else {
            _removeFee();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            if (recipient == _pair) {
                _transferToExcludedForSale(sender, recipient, amount);
            } else {
                _transferToExcluded(sender, recipient, amount);
            }
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        _restoreAllFee();
        return true;
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tBurn,
            uint256 tMarket
        ) = _getValues(tAmount);
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        _standardTransferContent(sender, recipient, rAmount, rTransferAmount);
        if (tMarket > 0) {
            _sendToBusinees(tMarket, sender, recipient);
        }
        if (tBurn > 0) {
            _sendToBurn(tBurn, sender);
        }
        _reflectFee(rFee, rBurn, rMarket, tFee, tBurn, tMarket);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _standardTransferContent(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tBurn,
            uint256 tMarket
        ) = _getValues(tAmount);
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        _excludedFromTransferContent(sender, recipient, tTransferAmount, rAmount, rTransferAmount);
        if (tMarket > 0) {
            _sendToBusinees(tMarket, sender, recipient);
        }
        if (tBurn > 0) {
            _sendToBurn(tBurn, sender);
        }
        _reflectFee(rFee, rBurn, rMarket, tFee, tBurn, tMarket);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _excludedFromTransferContent(
        address sender,
        address recipient,
        uint256 tTransferAmount,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
    }

    function _transferToExcludedForSale(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tBurn,
            uint256 tMarket
        ) = _getValuesForSale(tAmount);
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        _excludedFromTransferContentForSale(sender, recipient, tAmount, rAmount, rTransferAmount);
        if (tMarket > 0) {
            _sendToBusinees(tMarket, sender, recipient);
        }
        if (tBurn > 0) {
            _sendToBurn(tBurn, sender);
        }
        _reflectFee(rFee, rBurn, rMarket, tFee, tBurn, tMarket);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _excludedFromTransferContentForSale(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender] - rTransferAmount;
        _tOwned[recipient] = _tOwned[recipient] + tAmount;
        _rOwned[recipient] = _rOwned[recipient] + rAmount;
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tBurn,
            uint256 tMarket
        ) = _getValues(tAmount);
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        _excludedToTransferContent(sender, recipient, tAmount, rAmount, rTransferAmount);
        if (tMarket > 0) {
            _sendToBusinees(tMarket, sender, recipient);
        }
        if (tBurn > 0) {
            _sendToBurn(tBurn, sender);
        }
        _reflectFee(rFee, rBurn, rMarket, tFee, tBurn, tMarket);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _excludedToTransferContent(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tBurn,
            uint256 tMarket
        ) = _getValues(tAmount);
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        _bothTransferContent(sender, recipient, tAmount, rAmount, tTransferAmount, rTransferAmount);
        if (tMarket > 0) {
            _sendToBusinees(tMarket, sender, recipient);
        }
        if (tBurn > 0) {
            _sendToBurn(tBurn, sender);
        }
        _reflectFee(rFee, rBurn, rMarket, tFee, tBurn, tMarket);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _bothTransferContent(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 rAmount,
        uint256 tTransferAmount,
        uint256 rTransferAmount
    ) private {
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
    }

    function _reflectFee(
        uint256 rFee,
        uint256 rBurn,
        uint256 rMarket,
        uint256 tFee,
        uint256 tBurn,
        uint256 tMarket
    ) private {
        _rTotal = _rTotal - rFee - rBurn - rMarket;
        _tFeeTotal = _tFeeTotal + tFee;
        _tBurnTotal = _tBurnTotal + tBurn;
        _tMarketingFeeTotal = _tMarketingFeeTotal + tMarket;
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tFee, uint256 tBurn, uint256 tMarket) = _getTBasics(tAmount, _TAX_FEE, _BURN_FEE, _MARKET_FEE);
        uint256 tTransferAmount = getTTransferAmount(tAmount, tFee, tBurn, tMarket);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rFee) = _getRBasics(tAmount, tFee, currentRate);
        uint256 rTransferAmount = _getRTransferAmount(rAmount, rFee, tBurn, tMarket, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tBurn, tMarket);
    }

    function _getValuesForSale(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tFee, uint256 tBurn, uint256 tMarket) = _getTBasics(tAmount, _TAX_FEE, _BURN_FEE, _MARKET_FEE);
        uint256 tTransferAmountForSale = getTTransferAmountForSale(tAmount, tFee, tBurn, tMarket);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rFee) = _getRBasics(tAmount, tFee, currentRate);
        uint256 rTransferAmountForSale = _getRTransferAmountForSale(rAmount, rFee, tBurn, tMarket, currentRate);
        return (rAmount, rTransferAmountForSale, rFee, tTransferAmountForSale, tFee, tBurn, tMarket);
    }

    function _getTBasics(
        uint256 tAmount,
        uint256 taxFee,
        uint256 burnFee,
        uint256 marketFee
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = (tAmount * taxFee) / _GRANULARITY / 100;
        uint256 tBurn = (tAmount * burnFee) / _GRANULARITY / 100;
        uint256 tMarket = (tAmount * marketFee) / _GRANULARITY / 100;
        return (tFee, tBurn, tMarket);
    }

    function getTTransferAmount(
        uint256 tAmount,
        uint256 tFee,
        uint256 tBurn,
        uint256 tMarket
    ) private pure returns (uint256) {
        return tAmount - tFee - tBurn - tMarket;
    }

    function getTTransferAmountForSale(
        uint256 tAmount,
        uint256 tFee,
        uint256 tBurn,
        uint256 tMarket
    ) private pure returns (uint256) {
        return tAmount + tFee + tBurn + tMarket;
    }

    function _getRBasics(
        uint256 tAmount,
        uint256 tFee,
        uint256 currentRate
    ) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        return (rAmount, rFee);
    }

    function _getRTransferAmount(
        uint256 rAmount,
        uint256 rFee,
        uint256 tBurn,
        uint256 tMarket,
        uint256 currentRate
    ) private pure returns (uint256) {
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rBurn - rMarket;
        return rTransferAmount;
    }

    function _getRTransferAmountForSale(
        uint256 rAmount,
        uint256 rFee,
        uint256 tBurn,
        uint256 tMarket,
        uint256 currentRate
    ) private pure returns (uint256) {
        uint256 rBurn = tBurn * currentRate;
        uint256 rMarket = tMarket * currentRate;
        uint256 rTransferAmountForSale = rAmount + rFee + rBurn + rMarket;
        return rTransferAmountForSale;
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _sendToBusinees(
        uint256 tMarket,
        address sender,
        address recipient
    ) private {
        uint256 currentRate = _getRate();
        uint256 rMarket = tMarket * currentRate;
        if (_referralOwner[sender] != address(0)) {
            _sendToReferralOwner(tMarket, rMarket, _referralOwner[sender]);
            emit Transfer(sender, _referralOwner[sender], tMarket);
        } else if (_referralOwner[recipient] != address(0)) {
            _sendToReferralOwner(tMarket, rMarket, _referralOwner[recipient]);
            emit Transfer(sender, _referralOwner[recipient], tMarket);
        } else {
            _rOwned[_rewardWallet] = _rOwned[_rewardWallet] + rMarket;
            _tOwned[_rewardWallet] = _tOwned[_rewardWallet] + tMarket;
            emit Transfer(sender, _rewardWallet, tMarket);
        }
    }

    function _sendToBurn(uint256 tBurn, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rBurn = tBurn * currentRate;
        _rOwned[_rewardWallet] = _rOwned[_rewardWallet] + rBurn;
        _tOwned[_rewardWallet] = _tOwned[_rewardWallet] + tBurn;
        emit Transfer(sender, _rewardWallet, tBurn);
    }

    function _sendToReferralOwner(
        uint256 tMarket,
        uint256 rMarket,
        address owner
    ) private {
        if (_isExcluded[owner]) {
            _rOwned[owner] = _rOwned[owner] + rMarket;
            _tOwned[owner] = _tOwned[owner] + tMarket;
        } else {
            _rOwned[owner] = _rOwned[owner] + rMarket;
        }
        _referralOwnerTotalFee[owner] += tMarket;
    }

    function _removeFee() private {
        if (_TAX_FEE == 0 && _BURN_FEE == 0 && _MARKET_FEE == 0) return;
        _TAX_FEE = 0;
        _BURN_FEE = 0;
        _MARKET_FEE = 0;
    }

    function _restoreAllFee() private {
        _TAX_FEE = _standardFees.taxFee * 100;
        _BURN_FEE = _standardFees.rewardFee * 100;
        _MARKET_FEE = _standardFees.marketFee * 100;
    }
}
