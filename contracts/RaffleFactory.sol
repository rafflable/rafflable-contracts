// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRafflable.sol";
import "./IRafflableFactory.sol";
import "./IRafflerFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract RaffleFactory is Ownable {
	using EnumerableSet for EnumerableSet.AddressSet;
	EnumerableSet.AddressSet private _tokens;

	bool public enabled = true;
	address[] public rafflables;
	IRafflableFactory public rafflable;
	IRafflerFactory public raffler;

	event RafflePublished(address rafflable, address raffler, address creator);

	constructor(address[] memory tokens)  {
		for (uint8 i = 0; i < tokens.length; i++) {
			_tokens.add(tokens[i]);
		}
	}

    function toggleOnOff() external onlyOwner {
        enabled = !enabled;
    }

	function setRafflableFactory(address to) external onlyOwner {
		rafflable = IRafflableFactory(to);
	}

	function setRafflerFactory(address to) external onlyOwner {
		raffler = IRafflerFactory(to);
	}

	function getTokens() external view returns (address[] memory) {
		return _tokens.values();
	}

	function publish(
		string memory name,
		string memory configUri,
		string memory baseUri,
		string memory secretUri,
		uint256 cap,
		uint256 timelock,
		address token,
		uint256 cost,
		uint256 prize
	) public {
		require(enabled, "publishing is disabled");
		require(_tokens.contains(token), "token not allowed");
		address newRafflable = rafflable.create(
			name,
			configUri,
			baseUri,
			secretUri,
			cap,
			timelock,
			msg.sender,
			token,
			cost
		);
		address newRaffler = raffler.create(newRafflable, token, prize);
		IRafflable(newRafflable).setRaffler(newRaffler);
		rafflables.push(newRafflable);
		emit RafflePublished(newRafflable, newRaffler, msg.sender);
	}
}
