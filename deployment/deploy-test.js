const ethers = require('ethers');
const etherlime = require('etherlime-lib');
const networkMap = require('./network-map.json');
const path = require('path');
const writeJsonFile = require('write-json-file');

const testForceMoveArtifact = require('../build/TESTForceMove.json');
const testNitroAdjudicatorArtifact = require('../build/TESTNitroAdjudicator.json');
const testAssetHolderArtifact = require('../build/TESTAssetHolder.json');
const trivialAppArtifact = require('../build/TrivialApp.json');
const countingAppArtifact = require('../build/CountingApp.json');
const singleAssetPaymentsArtifact = require('../build/SingleAssetPayments.json');

const erc20AssetHolderArtifact = require('../build/ERC20AssetHolder.json');
const ethAssetHolderArtifact = require('../build/ETHAssetHolder.json');
const tokenArtifact = require('../build/token.json');

const deploy = async (network, secret, etherscanApiKey) => {
  let contractsToAddresses = {};
  const deployer = new etherlime.EtherlimeGanacheDeployer();
  const provider = new ethers.providers.JsonRpcProvider(deployer.nodeUrl);
  const networkId = (await provider.getNetwork()).chainId;

  const testNitroAdjudicatorContract = await deployer.deploy(testNitroAdjudicatorArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [testNitroAdjudicatorArtifact.contractName]: testNitroAdjudicatorContract.contractAddress,
  };

  const ethAssetHolderContract = await deployer.deploy(
    ethAssetHolderArtifact,
    false,
    testNitroAdjudicatorContract.contractAddress,
  );
  contractsToAddresses = {
    ...contractsToAddresses,
    [ethAssetHolderArtifact.contractName]: ethAssetHolderContract.contractAddress,
  };

  const erc20AssetHolderContract = await deployer.deploy(
    erc20AssetHolderArtifact,
    false,
    testNitroAdjudicatorContract.contractAddress,
    networkMap[networkId][tokenArtifact.contractName],
  );
  contractsToAddresses = {
    ...contractsToAddresses,
    [erc20AssetHolderArtifact.contractName]: erc20AssetHolderContract.contractAddress,
  };

  const testAssetHolderContract = await deployer.deploy(testAssetHolderArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [testAssetHolderArtifact.contractName]: testAssetHolderContract.contractAddress,
  };

  const trivialAppContract = await deployer.deploy(trivialAppArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [trivialAppArtifact.contractName]: trivialAppContract.contractAddress,
  };

  const countingAppContract = await deployer.deploy(countingAppArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [countingAppArtifact.contractName]: countingAppContract.contractAddress,
  };

  const singleAssetPaymentsContract = await deployer.deploy(singleAssetPaymentsArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [singleAssetPaymentsArtifact.contractName]: singleAssetPaymentsContract.contractAddress,
  };

  const testForceMoveContract = await deployer.deploy(testForceMoveArtifact);
  contractsToAddresses = {
    ...contractsToAddresses,
    [testForceMoveArtifact.contractName]: testForceMoveContract.contractAddress,
  };

  updatedNetworkMap = {...networkMap, [networkId]: contractsToAddresses};
  await writeJsonFile(path.join(__dirname, 'network-map.json'), updatedNetworkMap);
};

module.exports = {
  deploy,
};
