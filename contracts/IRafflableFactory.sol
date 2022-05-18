// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRafflableFactory {
	function create(
		string memory name,
		string memory configUri,
		string memory baseUri,
		string memory secretUri,
		uint256 cap,
		uint256 timelock,
		address creator,
		address token,
		uint256 cost
	) external returns (address);
}
