const Migrations = artifacts.require("MyERC20");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};