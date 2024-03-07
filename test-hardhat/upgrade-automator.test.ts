import hre from 'hardhat'
import { assert } from 'chai'
import {
  loadFixture,
  impersonateAccount,
  stopImpersonatingAccount,
} from '@nomicfoundation/hardhat-toolbox/network-helpers'
import {
  MockAutomatorV2,
  OrangeStrykeLPAutomatorV1_1,
} from '../typechain-types'
import { baseSetupFixture } from './fixture'
import { ensureForkNetwork } from './utils'

describe('Update OrangeStrykeLPAutomatorV1_1', () => {
  before(async () => {
    ensureForkNetwork()
  })

  it('should update OrangeStrykeLPAutomatorV1_1', async () => {
    const [ownerSigner] = await hre.ethers.getSigners()
    const owner = await ownerSigner.getAddress()

    const { chainlinkQuoter, stryke, uniswapRouter, tokens, pools, feeds } =
      await loadFixture(baseSetupFixture)

    const OrangeStrykeLPAutomatorV1_1 = await hre.ethers.getContractFactory(
      'OrangeStrykeLPAutomatorV1_1',
    )
    const MockAutomatorV2 =
      await hre.ethers.getContractFactory('MockAutomatorV2')

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

    const v1 = (await hre.upgrades
      .deployProxy(OrangeStrykeLPAutomatorV1_1, [init], {
        kind: 'uups',
      })
      .then((c) => c.waitForDeployment())) as OrangeStrykeLPAutomatorV1_1

    const v2 = (await hre.upgrades
      .upgradeProxy(v1, MockAutomatorV2, {
        kind: 'uups',
        call: {
          fn: 'initializeV2',
          args: [1n, 2n, '0x0000000000000000000000000000000000000003'],
        },
      })
      .then((c) => c.waitForDeployment())) as MockAutomatorV2

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
    assert.equal(await v2.foo(), 1n)
    assert.equal(await v2.bar(), 2n)
    assert.equal(await v2.baz(), '0x0000000000000000000000000000000000000003')
  })
})
