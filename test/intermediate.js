const Intermediate = artifacts.require("Intermediate");
const MyERC20 = artifacts.require("MyERC20");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("Intermediate", function (accounts) {
  it("should assert true", async function () {
    this.instance = await Intermediate.deployed();
    this.token = await MyERC20.at(await this.instance.token());
    return assert.isTrue(true);
  });

  it("approve tokens to the contract", async function(){
    await this.token.approve(this.instance.address, (await this.token.balanceOf(accounts[0])));
  })
  
  it("add liquidity by Intermediate", async function(){
    await this.instance.addLiquidity(await this.token.balanceOf(accounts[0]), accounts[0],{from: accounts[0], value: "100000000000000000"});
  })
  
  // it("Swap Eth for tokens", async function(){
  //   await this.instance.swapEthForTokens(accounts[0], {from: accounts[0], value: "100000000000000"});
  // })

  // it("approve tokens to the contract", async function(){
  //   await this.token.approve(accounts[0], this.instance.address, await this.token.balanceOf(accounts[0]));
  // })

  // it("Swap Tokens to Eth", async function(){
  //   await this.instance.swapTokensForEth(await this.token.balanceOf(accounts[0]), accounts[0],{from: accounts[0]});
  // })
});
