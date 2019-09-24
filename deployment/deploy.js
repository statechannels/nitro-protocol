const ethers = require('ethers');
const etherlime = require('etherlime-lib');
const networkMap = require('./network-map.json');
const path = require('path');
const writeJsonFile = require('write-json-file');

const tokenArtifact = require('../build/Token.json');
const ethAssetHolderArtifact = require('../build/ETHAssetHolder');
const erc20AssetHolderArtifact = require('../build/ERC20AssetHolder');
const nitroAdjudicatorArtifact = require('../build/NitroAdjudicator');
const consensusAppArtifact = require('../build/ConsensusApp');

const deploy = async (network, secret, etherscanApiKey) => {
  let contractsToAddresses = {};
  // todo: use network parameter to pick deployer.
  const deployer = new etherlime.EtherlimeGanacheDeployer();
  const provider = new ethers.providers.JsonRpcProvider(deployer.nodeUrl);
  const networkId = (await provider.getNetwork()).chainId;

  const tokenContract = await deployer.deploy(tokenArtifact);
  // todo: contract name as a key does not hold enough information as there can be many version of a contract
  contractsToAddresses = {
    ...contractsToAddresses,
    [tokenArtifact.contractName]: tokenContract.contractAddress,
  };

  const nitroAdjudicatorContract = await deployer.deploy(nitroAdjudicatorArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [nitroAdjudicatorArtifact.contractName]: nitroAdjudicatorContract.contractAddress,
  };

  const ethAssetHolderContract = await deployer.deploy(
    ethAssetHolderArtifact,
    false,
    nitroAdjudicatorContract.contractAddress,
  );
  contractsToAddresses = {
    ...contractsToAddresses,
    [ethAssetHolderArtifact.contractName]: ethAssetHolderContract.contractAddress,
  };

  const erc20AssetHolderContract = await deployer.deploy(
    erc20AssetHolderArtifact,
    false,
    nitroAdjudicatorContract.contractAddress,
    tokenContract.contractAddress,
  );
  contractsToAddresses = {
    ...contractsToAddresses,
    [erc20AssetHolderArtifact.contractName]: erc20AssetHolderContract.contractAddress,
  };

  const consensusAppContract = await deployer.deploy(consensusAppArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [consensusAppArtifact.contractName]: consensusAppContract.contractAddress,
  };

  updatedNetworkMap = {...networkMap, [networkId]: contractsToAddresses};
  await writeJsonFile(path.join(__dirname, 'network-map.json'), updatedNetworkMap);
};

module.exports = {
  deploy,
};
