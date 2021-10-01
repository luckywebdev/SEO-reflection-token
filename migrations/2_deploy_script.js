var PreSale = artifacts.require('./PreSaleSEO.sol');

const seoToken = "";
const rate = "";
const wallet = "";

module.exports = async (deployer) => {
    await deployer.deploy(PreSale, seoToken, rate, wallet);
    const preSaleInstance = await PreSale.deployed();
    console.log(
      `Token Exchange contract deployed at ${preSaleInstance.address} in network: mainnet.`
    );
  };
  