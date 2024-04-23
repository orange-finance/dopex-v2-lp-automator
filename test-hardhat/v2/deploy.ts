import hre from 'hardhat'
import { assert } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import {
  MockAutomatorV3,
  OrangeStrykeLPAutomatorV1_1,
  OrangeStrykeLPAutomatorV2,
} from '../../typechain-types'
import { baseSetupFixture } from '../v2/fixture'
import { ensureForkNetwork } from '../utils'

describe('OrangeStrykeLPAutomatorV2', () => {
  before(async () => {
    ensureForkNetwork()
  })

  it('should upgrade to v2 from v1', async () => {
    const [ownerSigner] = await hre.ethers.getSigners()
    const owner = await ownerSigner.getAddress()

    const {
      chainlinkQuoter,
      stryke,
      uniswapRouter,
      tokens,
      pools,
      feeds,
      balancer,
    } = await loadFixture(baseSetupFixture)

    const init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct = {
      name: 'OrangeDopexV2LPAutomatorV1',
      symbol: 'ODV2LP',
      admin: owner,
      manager: stryke.MANAGER,
      handler: stryke.HANDLER_V2,
      handlerHook: hre.ethers.ZeroAddress,
      router: uniswapRouter,
      pool: pools.WETH_USDC,
      asset: tokens.WETH,
      quoter: chainlinkQuoter.target,
      assetUsdFeed: feeds.ETH_USD,
      counterAssetUsdFeed: feeds.USDC_USD,
      minDepositAssets: hre.ethers.parseEther('0.01'),
    }

    const v1 = await _deployV1(init)

    const v2 = await _v2Upgrade(v1, balancer)

    assert.equal(v2.target, v1.target)

    // Check if the upgrade was successful
    // v1 state should be preserved
    assert.equal(await v2.name(), init.name)
    assert.equal(await v2.symbol(), init.symbol)
    assert.equal(await v2.isOwner(init.admin), true)
    assert.equal(await v2.manager(), init.manager)
    assert.equal(await v2.handler(), init.handler)
    assert.equal(await v2.handlerHook(), init.handlerHook)
    assert.equal(await v2.router(), init.router)
    assert.equal(await v2.pool(), init.pool)
    assert.equal(await v2.asset(), init.asset)
    assert.equal(await v2.quoter(), init.quoter)
    assert.equal(await v2.assetUsdFeed(), init.assetUsdFeed)
    assert.equal(await v2.counterAssetUsdFeed(), init.counterAssetUsdFeed)
    assert.equal(await v2.minDepositAssets(), init.minDepositAssets)

    // v2 state should be assigned
    assert.equal(await v2.balancer(), balancer)
    assert.equal(await v2.swapInputDelta(), 10n)
  })

  it('should upgrade to v3', async () => {
    const [ownerSigner] = await hre.ethers.getSigners()
    const owner = await ownerSigner.getAddress()

    const {
      chainlinkQuoter,
      stryke,
      uniswapRouter,
      tokens,
      pools,
      feeds,
      balancer,
    } = await loadFixture(baseSetupFixture)

    const init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct = {
      name: 'OrangeDopexV2LPAutomatorV1',
      symbol: 'ODV2LP',
      admin: owner,
      manager: stryke.MANAGER,
      handler: stryke.HANDLER_V2,
      handlerHook: hre.ethers.ZeroAddress,
      router: uniswapRouter,
      pool: pools.WETH_USDC,
      asset: tokens.WETH,
      quoter: chainlinkQuoter.target,
      assetUsdFeed: feeds.ETH_USD,
      counterAssetUsdFeed: feeds.USDC_USD,
      minDepositAssets: hre.ethers.parseEther('0.01'),
    }

    const v1 = await _deployV1(init)
    const v2 = await _v2Upgrade(v1, balancer)
    const v3 = await _v3Upgrade(v2, [
      1n,
      2n,
      '0x0000000000000000000000000000000000000003',
    ])

    // Check if the upgrade was successful
    // v2 state should be preserved
    assert.equal(await v3.manager(), init.manager)
    assert.equal(await v3.handler(), init.handler)
    assert.equal(await v3.handlerHook(), init.handlerHook)
    assert.equal(await v3.router(), init.router)
    assert.equal(await v3.pool(), init.pool)
    assert.equal(await v3.asset(), init.asset)
    assert.equal(
      await v3.counterAsset(),
      '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    )
    assert.equal(await v3.quoter(), init.quoter)
    assert.equal(await v3.assetUsdFeed(), init.assetUsdFeed)
    assert.equal(await v3.counterAssetUsdFeed(), init.counterAssetUsdFeed)
    assert.equal(await v3.minDepositAssets(), init.minDepositAssets)
    assert.equal(await v3.balancer(), balancer)

    // v2 state should be assigned
    assert.equal(await v3.foo(), 1n)
    assert.equal(await v3.bar(), 2n)
    assert.equal(await v3.baz(), '0x0000000000000000000000000000000000000003')
  })

  async function _v3Upgrade(
    v2: OrangeStrykeLPAutomatorV2,
    upgradeArgs: unknown[],
  ): Promise<MockAutomatorV3> {
    const MockAutomatorV3 =
      await hre.ethers.getContractFactory('MockAutomatorV3')

    const v3 = (await hre.upgrades
      .upgradeProxy(v2, MockAutomatorV3, {
        kind: 'uups',
        call: {
          fn: 'initializeV3',
          args: upgradeArgs,
        },
      })
      .then((c) => c.waitForDeployment())) as MockAutomatorV3

    return v3
  }

  async function _deployV1(
    init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct,
  ): Promise<OrangeStrykeLPAutomatorV1_1> {
    const OrangeStrykeLPAutomatorV1_1 = await hre.ethers.getContractFactory(
      'OrangeStrykeLPAutomatorV1_1',
    )
    const c = hre.upgrades
      .deployProxy(OrangeStrykeLPAutomatorV1_1, [init], {
        kind: 'uups',
      })
      .then((c) =>
        c.waitForDeployment(),
      ) as Promise<OrangeStrykeLPAutomatorV1_1>

    return c
  }

  async function _v2Upgrade(
    v1: OrangeStrykeLPAutomatorV1_1,
    balancerAddress: string,
  ): Promise<OrangeStrykeLPAutomatorV2> {
    const OrangeStrykeLPAutomatorV2 = await hre.ethers.getContractFactory(
      'OrangeStrykeLPAutomatorV2',
    )

    const v2 = (await hre.upgrades
      .upgradeProxy(v1, OrangeStrykeLPAutomatorV2, {
        kind: 'uups',
        call: {
          fn: 'initializeV2',
          args: [balancerAddress],
        },
      })
      .then((c) => c.waitForDeployment())) as OrangeStrykeLPAutomatorV2

    return v2
  }
})
