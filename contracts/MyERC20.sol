// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-solidity/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/Context.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "./interface/RouterInterface.sol";

contract MyERC20 is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256; 
    using Address for address; 

    mapping(address => uint256) private _balances; 

    mapping(address => mapping(address => uint256)) private _allowances;

    /*
    * 10% of the total transaction amount will go to the liquidity. It will be beneficial for the token lifecycle and it's holders.
    */
    uint256 public lp_tax = 10;
    /*
    * If disabled there will be no tax deducted in any transaction.
    */
    bool public tax_enabled = false;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    address[] public black_list_address;
    /*
    * You can blacklist the bot addresses.
    */

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    constructor() {
        _name = "My ERC20";
        _symbol = "MEC20";
        _decimals = 18;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
          0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        // Minting token supply to the owner address.
        _mint(tx.origin, 1000000 * 10**18);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /*
    * You can set the tax_enabled state by this function.
    */
    function setTaxEnabled(bool _state) public onlyOwner {
        tax_enabled = _state;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
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

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }
    
    /*
    * By using this function you can blacklist an address.
    */
    function blacklist_address(address _address_to_blacklist) public onlyOwner {
        black_list_address.push(_address_to_blacklist);
    }
    
    function check_blacklist() private view returns (bool) {
        bool isExist = false;
        for (uint256 i = 0; i < black_list_address.length; i++) {
            if (black_list_address[i] == msg.sender) {
                isExist = true;
                break;
            }
        }
        return isExist;
    }

   function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        require(amount > 0, "Zero Amount!");
        require(check_blacklist() == false, "Parent: Blacklisted Address");
        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[sender] = senderBalance - amount;

        if (sender != address(this) && tax_enabled) {
            uint256 tax_amount = amount.mul(lp_tax).div(100);
            uint256 transfer_amount = amount - tax_amount;
            _balances[address(this)] += tax_amount;

            if (sender != address(uniswapV2Pair)) {
                uint256 contractTokenBalance = balanceOf(address(this));

                //add liquidity
                swapAndLiquify(contractTokenBalance);
            }

            _balances[recipient] += transfer_amount;
            emit Transfer(sender, recipient, transfer_amount);
        } else {
            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }
    }

    function swapAndLiquify(uint256 contractTokenBalance) internal {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    // to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function swapTokensForEth(uint256 tokenAmount) internal {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}


}
