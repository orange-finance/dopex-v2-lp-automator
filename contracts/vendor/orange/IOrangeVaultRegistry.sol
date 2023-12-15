// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title OrangeVaultRegistry interface
 * @author Orange Finance
 * @notice Interface for the OrangeVaultRegistry contract.
 */
interface IOrangeVaultRegistry {
    event VaultAdded(address indexed vault, string indexed version, address indexed parameters);
    event VaultRemoved(address indexed vault);

    struct VaultDetail {
        string version;
        address parameters;
    }

    /**
     * @notice Returns the number of vaults.
     */
    function numVaults() external view returns (uint256);

    /**
     * @notice Returns the detail of a vault.
     * @param _vault The address of the vault.
     * @return The detail of the vault.
     */
    function getDetailOf(address _vault) external view returns (VaultDetail memory);

    /**
     * @notice Adds a vault to the registry.
     * @param vault The address of the vault.
     * @param version The version of the vault implementation.
     * @param parameters The address of the vault parameters contract.
     */
    function add(address vault, string calldata version, address parameters) external;

    /**
     * @notice Removes a vault from the registry.
     * @param vault The address of the vault.
     */
    function remove(address vault) external;
}
