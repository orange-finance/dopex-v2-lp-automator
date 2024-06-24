import hre from 'hardhat'

// to use in fork test, deploy implementation separately
async function main() {
  const impl = await hre.ethers.deployContract(
    'BackwardCompatibleOrangeStrykeLPAutomatorV2',
  )

  console.log(`implementation deployed to: ${impl.target}`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
