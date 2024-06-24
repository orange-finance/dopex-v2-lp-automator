import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

function pairId(
  hre: HardhatRuntimeEnvironment,
  tokenA: string,
  tokenB: string,
) {
  const ta = hre.ethers.toBigInt(tokenA)
  const tb = hre.ethers.toBigInt(tokenB)
  if (ta < tb) [tokenA, tokenB] = [tokenB, tokenA]

  return hre.ethers.keccak256(
    hre.ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'address'],
      [tokenA, tokenB],
    ),
  )
}

const func: DeployFunction = async function (hre) {
  const ORACLE = '0x4487d08B77530AAdEb11459f1BC19b479f90d8F9'
  const TWAP_CONFIG = {
    'boop-weth': {
      pairId: pairId(
        hre,
        '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH
        '0x13A7DeDb7169a17bE92B0E3C7C2315B46f4772B3', // BOOP
      ),
      pool: '0xe24F62341D84D11078188d83cA3be118193D6389',
      duration: 600, // 10 minutes
    },
  }

  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address, newlyDeployed } = await deploy('UniswapV3TWAPQuoter', {
    contract: 'UniswapV3TWAPQuoter',
    args: [ORACLE],
    from: deployer,
    log: true,
  })

  if (newlyDeployed) {
    const quoter = await hre.ethers.getContractAt(
      'UniswapV3TWAPQuoter',
      address,
    )

    await quoter.setTWAPConfig(TWAP_CONFIG['boop-weth'].pairId, {
      pool: TWAP_CONFIG['boop-weth'].pool,
      duration: TWAP_CONFIG['boop-weth'].duration,
    })
  }
}

func.tags = ['periphery', 'base', 'twap-quoter']

export default func
