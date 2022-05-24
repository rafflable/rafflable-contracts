// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Rafflable.sol";

contract RafflableFactory {
	address public factory;

	modifier onlyFactory() {
		require(factory == msg.sender, "caller is not the factory");
		_;
	}

	event RafflableCreated(address rafflable, uint256 cap, uint256 timelock);

	constructor(address _factory) {
		factory = _factory;
	}

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
	) external onlyFactory returns (address) {
		Rafflable rafflable = new Rafflable(
			name, configUri, baseUri, secretUri,
			cap, timelock, creator, token, cost
		);
		rafflable.transferOwnership(factory);
		emit RafflableCreated(address(rafflable), cap, timelock);
		return address(rafflable);
	}
}
