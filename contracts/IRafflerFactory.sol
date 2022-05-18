// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRafflerFactory {
	function create(address rafflable, address token, uint256 prize) external returns (address);
}
