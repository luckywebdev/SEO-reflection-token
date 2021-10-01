const IUniswapV2Router02 = require("../build/contracts/IUniswapV2Router02.json")
const Contract = require("web3-eth-contract")

const BN = require("bn.js")

const { assert } = require("chai")

const SEOCoin = artifacts.require("SEOCoin")

function seoTokenTest(accounts) {
  let seoTokenInstance
  let uniswap
  before(async () => {
    seoTokenInstance = await SEOCoin.deployed()
    uniswap = new web3.eth.Contract(IUniswapV2Router02.abi, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
  })

  it("should be set pause not enable at first", async () => {
    await seoTokenInstance.pausedNotEnable({ from: accounts[0] })

    assert.equal(await seoTokenInstance.name(), "SEO Coin", "token name is SEO Coin")

    await seoTokenInstance.setReferralOwner(accounts[1], accounts[2])
    assert.equal(await seoTokenInstance.checkReferralOwner(accounts[1]), accounts[2], "ERR: not same address")
  })

  it("should be set business and reward wallet address", async () => {
    await seoTokenInstance.setBusinessWallet(accounts[3], { from: accounts[0] })
    const balance = web3.utils.toWei("50", "Mwei")
    const realBalance = new BN(await seoTokenInstance.balanceOf(accounts[3]))

    assert.equal(web3.utils.fromWei(realBalance.toString(), "ether"), balance, "ERR: not same balance")

    await seoTokenInstance.setRewardAddress(accounts[4], { from: accounts[0] })
    const balance2 = web3.utils.toWei("350", "Mwei")
    const rewardBalance = new BN(await seoTokenInstance.balanceOf(accounts[4]))

    assert.equal(web3.utils.fromWei(rewardBalance.toString(), "ether"), balance2, "ERR: not same balance")
  })

  it("should be set tx fees", async () => {
    const fees = ["2", "2", "2"]
    const setFee = await seoTokenInstance.setStandardFee(fees, { from: accounts[0] })
  })

  it("should add liquidity seo", async () => {
    const ownerBalance = new BN(await seoTokenInstance.balanceOf(accounts[0]))

    assert.equal(web3.utils.fromWei(ownerBalance.toString(), "ether"), 400000000)

    assert.equal(uniswap.options.address, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")

    const weth = await uniswap.methods.WETH().call()

    assert.equal(weth, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")

    const amountTokenDesired = web3.utils.toWei("1048550", "ether")
    const d = new Date()

    const approveAmount0 = new BN(await seoTokenInstance.allowance(accounts[0], uniswap.options.address))
    assert.equal(web3.utils.fromWei(approveAmount0.toString(), "ether"), 0, "uniswap router not approved")

    const maxValue = web3.utils.toBN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

    await seoTokenInstance.approve(uniswap.options.address, maxValue, { from: accounts[0] })

    const approveAmount = new BN(await seoTokenInstance.allowance(accounts[0], uniswap.options.address))

    assert.equal(
      web3.utils.fromWei(approveAmount.toString(), "ether"),
      web3.utils.fromWei(maxValue.toString(), "ether"),
      "uniswap router approved",
    )

    await uniswap.methods
      .addLiquidityETH(
        seoTokenInstance.address,
        amountTokenDesired,
        amountTokenDesired,
        web3.utils.toWei("1", "ether"),
        accounts[0],
        d.getTime(),
      )
      .send({ from: accounts[0], value: web3.utils.toWei("1", "ether"), gasLimit: 9999999 })
      .on("receipt", (receipt) => {
        console.log("add liquidity receipt===========>")
      })
      .on("error", (error, receipt) => {
        console.log("add liquidity receipt error===========>", error)
      })
  })

  it("should swap ETH for seo", async () => {
    const d = new Date()
    const weth = await uniswap.methods.WETH().call()
    const path = [weth, seoTokenInstance.address]

    const getAmount = await uniswap.methods.getAmountsIn(web3.utils.toWei("10000", "ether"), path).call()

    console.log("get the first token price===========>", web3.utils.fromWei(getAmount[0].toString(), "ether"))

    const ownerBalance1 = new BN(await seoTokenInstance.balanceOf(accounts[5]))

    assert.equal(web3.utils.fromWei(ownerBalance1.toString(), "ether"), 0, "zero balance before swap")

    await uniswap.methods
      .swapETHForExactTokens(web3.utils.toWei("10000", "ether"), path, accounts[5], d.getTime())
      .send({
        from: accounts[5],
        value: getAmount[0],
        gasLimit: 9999999,
      })
      .on("receipt", (receipt) => {
        console.log("[swap receipt]")
      })
      .on("error", (error, receipt) => {
        console.log("swap receipt error===========>", error)
      })

    const ownerBalance2 = new BN(await seoTokenInstance.balanceOf(accounts[5]))

    console.log("owner wallet balance after first swap======>", web3.utils.fromWei(ownerBalance2.toString(), "ether"))
  })

  it("should the second swap ETH for seo", async () => {
    const d = new Date()
    const weth = await uniswap.methods.WETH().call()
    const path = [weth, seoTokenInstance.address]

    const getAmount = await uniswap.methods.getAmountsIn(web3.utils.toWei("10000", "ether"), path).call()

    console.log("get second token price===========>", web3.utils.fromWei(getAmount[0].toString(), "ether"))

    const ownerBalance1 = new BN(await seoTokenInstance.balanceOf(accounts[6]))

    assert.equal(web3.utils.fromWei(ownerBalance1.toString(), "ether"), 0, "zero balance before swap")

    await uniswap.methods
      .swapETHForExactTokens(web3.utils.toWei("10000", "ether"), path, accounts[6], d.getTime())
      .send({
        from: accounts[6],
        value: getAmount[0],
        gasLimit: 9999999,
      })
      .on("receipt", (receipt) => {
        console.log("[swap receipt 1]")
      })
      .on("error", (error, receipt) => {
        console.log("swap receipt error===========>", error)
      })

    const ownerBalance2 = new BN(await seoTokenInstance.balanceOf(accounts[6]))

    console.log("owner wallet balance after second swap======>", web3.utils.fromWei(ownerBalance2.toString(), "ether"))

    const getAmount1 = await uniswap.methods.getAmountsIn(web3.utils.toWei("10000", "ether"), path).call()

    await uniswap.methods
      .swapETHForExactTokens(web3.utils.toWei("10000", "ether"), path, accounts[6], d.getTime())
      .send({
        from: accounts[6],
        value: getAmount1[0],
        gasLimit: 9999999,
      })
      .on("receipt", (receipt) => {
        console.log("[swap receipt 2]")
      })
      .on("error", (error, receipt) => {
        console.log("swap receipt error===========>", error)
      })

    const ownerBalance3 = new BN(await seoTokenInstance.balanceOf(accounts[6]))

    console.log("owner wallet balance after third swap======>", web3.utils.fromWei(ownerBalance3.toString(), "ether"))
  })

  it("should transfer some seo from contract to account7", async () => {
    const ownerBalance1 = new BN(await seoTokenInstance.balanceOf(accounts[7]))

    assert.equal(web3.utils.fromWei(ownerBalance1.toString(), "ether"), 0, "zero balance before transfer")

    await seoTokenInstance.transferFrom(seoTokenInstance.address, accounts[7], web3.utils.toWei("20000", "ether"), {
      from: accounts[0],
    })

    const ownerBalance2 = new BN(await seoTokenInstance.balanceOf(accounts[7]))

    assert.equal(web3.utils.fromWei(ownerBalance2.toString(), "ether"), 20000, "zero balance after transfer")
  })

  it("should transfer between wallets", async () => {
    await seoTokenInstance.transferFrom(seoTokenInstance.address, accounts[1], web3.utils.toWei("200000", "ether"), {
      from: accounts[0],
    })

    const ownerBalance0 = new BN(await seoTokenInstance.balanceOf(accounts[1]))

    assert.equal(web3.utils.fromWei(ownerBalance0.toString(), "ether"), 200000, "20000 balance before transfer")

    const ownerBalance1 = new BN(await seoTokenInstance.balanceOf(accounts[2]))
    assert.equal(web3.utils.fromWei(ownerBalance1.toString(), "ether"), 0, "zero balance before transfer")

    await seoTokenInstance.transfer(accounts[2], web3.utils.toWei("100000", "ether"), { from: accounts[1] })

    const ownerBalance0_1 = new BN(await seoTokenInstance.balanceOf(accounts[1]))
    const ownerBalance2 = new BN(await seoTokenInstance.balanceOf(accounts[2]))
    assert.equal(web3.utils.fromWei(ownerBalance0_1.toString(), "ether"), 100000, "balance after transfer")
    assert.equal(web3.utils.fromWei(ownerBalance2.toString(), "ether"), 100000, "balance after transfer")
  })

  it("should swap seo for ETH and reward to referral link owner", async () => {
    const d = new Date()
    const weth = await uniswap.methods.WETH().call()
    const path = [seoTokenInstance.address, weth]

    await seoTokenInstance.swapTokenForEthEnable({ from: accounts[0] })

    const getAmountOut = await uniswap.methods.getAmountsOut(web3.utils.toWei("10000", "ether"), path).call()

    console.log(
      "get token price for eth after the forth swap===========>",
      web3.utils.fromWei(getAmountOut[1].toString(), "ether"),
    )

    const maxValue = web3.utils.toBN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

    await seoTokenInstance.approve(uniswap.options.address, maxValue, { from: accounts[1] })

    const ownerBalance1 = new BN(await seoTokenInstance.balanceOf(accounts[1]))

    assert.equal(web3.utils.fromWei(ownerBalance1.toString(), "ether"), 100000, "should be 100000 before the forth swap")

    assert.equal(await seoTokenInstance.checkReferralOwner(accounts[1]), accounts[2], "ERR: not same address")

    await uniswap.methods.swapExactTokensForETH(web3.utils.toWei("10000", "ether"), 0, path, accounts[1], d.getTime()).send({
      from: accounts[1],
      gasLimit: 9999999,
    })

    const ownerBalance2 = new BN(await seoTokenInstance.balanceOf(accounts[1]))

    console.log(
      "referral link user wallet balance after the forth swap======>",
      web3.utils.fromWei(ownerBalance2.toString(), "ether"),
    )

    const checkRef = new BN(await seoTokenInstance.checkReferralReward(accounts[2]))
    assert.equal(web3.utils.fromWei(checkRef.toString(), "ether"), 200, "reward amount should be 200")

    const ownerBalance3 = new BN(await seoTokenInstance.balanceOf(accounts[2]))

    console.log(
      "referral link owner wallet balance after the forth swap======>",
      web3.utils.fromWei(ownerBalance3.toString(), "ether"),
    )
  })
}

module.exports = {
  seoTokenTest,
}
