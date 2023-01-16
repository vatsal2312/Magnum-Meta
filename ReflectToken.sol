pragma solidity ^0.8.10;
import "./Ownable.sol";
import "./IERC20.sol";

abstract contract ReflectToken is Context, IERC20, Ownable {
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _dexList;

    address[] private _excluded;

    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    string private NAME;
    string private SYMBOL;

    uint8 private constant DECIMALS = 18;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 tTotal_
    ) {
        NAME = name_;
        SYMBOL = symbol_;
        _tTotal = tTotal_;
        uint256 MAX = type(uint256).max;
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_msgSender()] = _rTotal;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /**
     * @dev Amount of tokens to be charged as a reflection fee. Must be in range 0..amount.
     */
    function _calculateFee(uint256 amount)
        internal
        view
        virtual
        returns (uint256, uint256);

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return NAME;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory) {
        return SYMBOL;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint8) {
        return DECIMALS;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev Returns the amount of tokens owned by `account` considering `tokenFromReflection`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) {
            return _tOwned[account];
        }

        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        external
        virtual
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual returns (bool) {
        _transfer(sender, recipient, amount);

        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    /**
     * @dev Returns array of excluded accounts from reflection rewards.
     */
    function getExcluded() external view returns (address[] memory) {
        return _excluded;
    }

    /**
     * @dev Checks whether account is excluded from reflection rewards.
     * @param account Address of an account.
     */
    function isExcluded(address account) external view returns (bool) {
        return _isExcluded[account];
    }

    /**
     * @dev Returns number of total fees. It increases when fees are applied.
     */
    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    /**
     * @dev Converts reflection to token amount.
     * @param rAmount Amount of reflection.
     */
    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "ReflectToken: amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /**
     * @dev Excludes account from retrieveng reflect rewards. Can be called only by the owner.
     * @param account Address of the account.
     */
    function excludeAccount(address account) public onlyOwner {
        require(
            !_isExcluded[account],
            "ReflectToken: account is already excluded"
        );
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
     * @dev Allows account to retrieve reflect rewards. Can be called only by the owner.
     * @param account Address of the account.
     */
    function includeAccount(address account) public onlyOwner {
        require(
            _isExcluded[account],
            "ReflectToken: account is already included"
        );
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

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(
            owner != address(0),
            "ReflectToken: approve from the zero address"
        );
        require(
            spender != address(0),
            "ReflectToken: approve to the zero address"
        );

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Transfer is executed considering both accounts states recipient and sender.
     * Also, distributes reflection rewards and accumulates fee.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) internal virtual {
        require(
            sender != address(0),
            "ReflectToken: transfer from the zero address"
        );
        require(
            recipient != address(0),
            "ReflectToken: transfer to the zero address"
        );
        require(
            tAmount > 0,
            "ReflectToken: transfer amount must be greater than zero"
        );

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 rTax,
            uint256 tTransferAmount,
            uint256 tTax,
            uint256 tFee
        ) = _getValues(tAmount, recipient, sender);

        _rOwned[sender] = _rOwned[sender] - rAmount;
        if (_isExcluded[sender]) {
            _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        if (_isExcluded[recipient]) {
            _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        }
        if (tFee != 0) {
            _reflectFee(rFee, tFee);
            _accumulateFee(tTax, rTax);
        }

        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Distributes reflection rewards.
     * @param rFee Fee taken from the sender"s account.
     * @param tFee Fee with considering of a rate (real amount of tokens).
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address from, uint256 tAmount) internal {
        uint256 rAmount = tAmount * _getRate();
        _rOwned[from] = _rOwned[from] - rAmount;
        if (_isExcluded[from]) {
            _tOwned[from] = _tOwned[from] - tAmount;
        }
        _rTotal = _rTotal - rAmount;
        _tTotal = _tTotal - tAmount;
        emit Transfer(_msgSender(), address(0), tAmount);
    }

    /**
     * @dev Accumulates accumulation fee on the contract"s balance with considering of its involvement in rewards reflection.
     */
    function _accumulateFee(uint256 tTax, uint256 rTax) private {
        _rOwned[address(this)] += rTax;
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] += tTax;
        }
    }

    /**
     * @dev Returns results of `_getTValues` and `_getRValues` methods.
     */
    function _getValues(
        uint256 tAmount,
        address to,
        address from
    )
        private
        view
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 rTax,
            uint256 tTransferAmount,
            uint256 tTax,
            uint256 tFee
        )
    {
        (tTransferAmount, tTax, tFee) = _getTValues(tAmount, to, from);

        (rAmount, rTransferAmount, rTax, rFee) = _getRValues(
            tAmount,
            tTax,
            tFee
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            rTax,
            tTransferAmount,
            tTax,
            tFee
        );
    }

    /**
     * @dev Checking if the account is DEX
     */
    function isDex(address account) public view returns (bool) {
        return _dexList[account];
    }

    /**
     * @dev Computes and returns transfer amount, reflection fee, accumulation fee in tokens.
     */
    function _getTValues(
        uint256 tAmount,
        address to,
        address from
    )
        private
        view
        returns (
            uint256 tTransferAmount,
            uint256 tTax,
            uint256 tFee
        )
    {
        if (_dexList[to] || _dexList[from]) {
            (tTax, tFee) = _calculateFee(tAmount);
        }

        tTransferAmount = tAmount - tTax - tFee;

        return (tTransferAmount, tTax, tFee);
    }

    /**
     * @dev Computes and returns amount, transfer amount, reflection fee, accumulation fee in reflection.
     */
    function _getRValues(
        uint256 tAmount,
        uint256 tTax,
        uint256 tFee
    )
        private
        view
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rTax,
            uint256 rFee
        )
    {
        uint256 currentRate = _getRate();
        rAmount = tAmount * currentRate;
        rFee = tFee * currentRate;
        rTax = tTax * currentRate;
        rTransferAmount = rAmount - rTax - rFee;
        return (rAmount, rTransferAmount, rTax, rFee);
    }

    /**
     * @dev Returns reflection to token rate.
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    /**
     * @dev Returns current supply.
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        uint256 len = _excluded.length;
        for (uint256 i = 0; i < len; i++) {
            address account = _excluded[i];
            uint256 rBalance = _rOwned[account];
            uint256 tBalance = _tOwned[account];
            if (rBalance > rSupply || tBalance > tSupply)
                return (_rTotal, _tTotal);
            rSupply -= rBalance;
            tSupply -= tBalance;
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
     * @dev Adding DEX account in list
     */
    function _addAccountInDex(address account, bool val) internal {
        _dexList[account] = val;
        if (val) {
            excludeAccount(account);
        } else {
            includeAccount(account);
        }
    }
}
