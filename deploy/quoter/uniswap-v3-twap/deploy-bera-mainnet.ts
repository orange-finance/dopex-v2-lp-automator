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
  const ORACLE = '0x6feaA6a25AB83c9BA3DD393094094cF91262d8d9'
  const TWAP_CONFIG = {
    'weth-honey': {
      pairId: pairId(
        hre,
        '0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590', // WETH
        '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce', // HONEY
      ),
      pool: '0x9EB897D400f245E151daFD4c81176397D7798C9c',
      duration: 600, // 10 minutes
    },
    'wbtc-honey': {
      pairId: pairId(
        hre,
        '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c', // WBTC
        '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce', // HONEY
      ),
      pool: '0x545Bea6Ea7F8fD8dCC5C9A6802a8ebF3DbFc1C6E',
      duration: 600, // 10 minutes
    },
    'wbera-honey': {
      pairId: pairId(
        hre,
        '0x6969696969696969696969696969696969696969', // WBERA
        '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce', // HONEY
      ),
      pool: '0x1127f801Cb3ab7BDF8923272949AA7Dba94B5805',
      duration: 600, // 10 minutes
    },
  }

  const { deployments, getNamedAccounts } = hre
  const { deploy, execute } = deployments

  const { deployer } = await getNamedAccounts()

  const { address, newlyDeployed } = await deploy('UniswapV3TWAPQuoter', {
    contract: 'UniswapV3TWAPQuoter',
    args: [ORACLE],
    from: deployer,
    log: true,
  })

  if (newlyDeployed) {
    for (const [key, value] of Object.entries(TWAP_CONFIG)) {
      await execute(
        'UniswapV3TWAPQuoter',
        {
          from: deployer,
          log: true,
        },
        'setTWAPConfig',
        value.pairId,
        {
          pool: value.pool,
          duration: value.duration,
        },
      )
    }
  }
}

func.tags = ['base-berachain_mainnet', 'twap-quoter_berachain_mainnet']

export default func
