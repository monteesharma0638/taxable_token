const Intermediate = artifacts.require("Intermediate");

module.exports = async function (deployer) {
  deployer.deploy(Intermediate);
};