const Contract = require("web3-eth-contract")

const BN = require("bn.js")

const { assert } = require("chai")
const truffleAssert = require("truffle-assertions")

const SEOCoin = artifacts.require("SEOCoin")
const PreSaleSEO = artifacts.require("PreSaleSEO")
const IUniswapV2Router02 = require("../build/contracts/IUniswapV2Router02.json")

function presaleTest(accounts) {
  let seoTokenInstance
  let presaleInstance
  let uniswap
  before(async () => {
    seoTokenInstance = await SEOCoin.deployed()
    presaleInstance = await PreSaleSEO.deployed()
    uniswap = new web3.eth.Contract(IUniswapV2Router02.abi, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
    await seoTokenInstance.setPreSale(presaleInstance.address)
  })

  it("should not enabled pause", async () => {
    await presaleInstance.pausedNotEnable({ from: accounts[0] })
  })

  it("should transfer eth to presale and check seo balance", async () => {
    const account1SEOBalanceBefore = await seoTokenInstance.balanceOf(accounts[1])
    console.log("[account1SEOBalanceBefore]", web3.utils.fromWei(account1SEOBalanceBefore.toString(), "ether"))

    const account1EthBalanceBefore = await web3.eth.getBalance(accounts[1])
    console.log("[account1EthBalanceBefore]", web3.utils.fromWei(account1EthBalanceBefore.toString(), "ether"))

    // await web3.eth.sendTransaction({from: accounts[1], to: presaleInstance.address, value: web3.utils.toWei('0.5', 'ether')});
    await presaleInstance.buyTokens(accounts[1], { from: accounts[1], value: web3.utils.toWei("0.5", "ether") })

    const account1EthBalanceAfter = await web3.eth.getBalance(accounts[1])
    console.log("[account1EthBalanceAfter]", web3.utils.fromWei(account1EthBalanceAfter.toString(), "ether"))

    const account1SEOBalanceAfter = await seoTokenInstance.balanceOf(accounts[1])
    console.log("[account1SEOBalanceAfter]", web3.utils.fromWei(account1SEOBalanceAfter.toString(), "ether"))
  })

  it("should be locked presale accounts", async () => {
    const account1SEOBalanceBefore = await seoTokenInstance.balanceOf(accounts[1])
    console.log("[account1SEOBalanceBefore]", web3.utils.fromWei(account1SEOBalanceBefore.toString(), "ether"))

    const account1EthBalanceBefore = await web3.eth.getBalance(accounts[1])
    console.log("[account1EthBalanceBefore]", web3.utils.fromWei(account1EthBalanceBefore.toString(), "ether"))

    // await web3.eth.sendTransaction({from: accounts[1], to: presaleInstance.address, value: web3.utils.toWei('0.5', 'ether')});
    await presaleInstance.buyTokens(accounts[1], { from: accounts[1], value: web3.utils.toWei("0.5", "ether") })

    const account1EthBalanceAfter = await web3.eth.getBalance(accounts[1])
    console.log("[account1EthBalanceAfter]", web3.utils.fromWei(account1EthBalanceAfter.toString(), "ether"))

    const account1SEOBalanceAfter = await seoTokenInstance.balanceOf(accounts[1])
    console.log("[account1SEOBalanceAfter]", web3.utils.fromWei(account1SEOBalanceAfter.toString(), "ether"))

    const d = new Date()
    const weth = await uniswap.methods.WETH().call()
    const path = [weth, seoTokenInstance.address]

    const getAmount = await uniswap.methods.getAmountsIn(web3.utils.toWei("10000", "ether"), path).call()

    console.log("get the first token price===========>", web3.utils.fromWei(getAmount[0].toString(), "ether"))

    assert.throws(
      await uniswap.methods.swapETHForExactTokens(web3.utils.toWei("10000", "ether"), path, accounts[1], d.getTime()).send({
        from: accounts[1],
        value: getAmount[0],
        gasLimit: 9999999,
      }),
      "account must be locked",
    )

    const account1BalanceAfterSwap = new BN(await seoTokenInstance.balanceOf(accounts[1]))

    console.log("account1 wallet balance after swap======>", web3.utils.fromWei(account1BalanceAfterSwap.toString(), "ether"))
  })
}

module.exports = {
  presaleTest,
}
