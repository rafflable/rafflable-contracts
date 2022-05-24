// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Raffler.sol";

contract RafflerFactory {
	address public factory;

	modifier onlyFactory() {
		require(factory == msg.sender, "caller is not the factory");
		_;
	}

	event RafflerCreated(address raffler, address token, uint256 prize);

	constructor(address _factory) {
		factory = _factory;
	}

	function create(
		address rafflable,
		address token,
		uint256 prize
	) external onlyFactory returns (address) {
		Raffler raffler = new Raffler(rafflable, token, prize);
		raffler.transferOwnership(factory);
		emit RafflerCreated(address(raffler), token, prize);
		return address(raffler);
	}
}
