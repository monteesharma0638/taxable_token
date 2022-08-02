// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interface/RouterInterface.sol";
import "./MyERC20.sol";

contract Intermediate {
    IUniswapV2Router02 public constant router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 public immutable token;

    constructor() {
        token = new MyERC20();
    }

    // This will add liquidity to uniswap router.
    function addLiquidity(uint256 _amount, address _to) public payable {
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(router), _amount*2);
        router.addLiquidityETH{value: msg.value}(
            address(token), // token address
            _amount, // amount desired
            0, // unavoidable 
            0, // unavoidable 
            _to, // where to send the lp tokens
            block.timestamp 
        );
    }

    // This will swap tokens to eth.
    function swapTokensForEth(uint256 _amountOfTokens, address _to) public {
        token.transferFrom(msg.sender, address(this), _amountOfTokens);
        token.approve(address(router), _amountOfTokens);
        address[] memory pair = new address[](2);
        pair[0] = address(token);
        pair[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amountOfTokens,
            0, // unavoidable slippage
            pair, // path 
            _to, // receiver address
            block.timestamp 
        );
    }

    // This will swap Eth to Tokens.
    function swapEthForTokens(address _to) public payable {
        address[] memory pair = new address[](2);
        pair[0] = router.WETH();
        pair[1] = address(token);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            pair, // path
            _to, // receiver address
            block.timestamp 
        );
    }
}
