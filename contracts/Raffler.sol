// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRaffler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Raffler is ERC165Storage, IRaffler, Ownable {
	using EnumerableSet for EnumerableSet.UintSet;
	using EnumerableSet for EnumerableSet.AddressSet;
	using Address for address;

	IERC721 public immutable rafflable;

	uint8 private constant _maxTokens = 10;
	EnumerableSet.AddressSet private _krc20;

	EnumerableSet.UintSet private _hat;
	EnumerableSet.UintSet private _seen;
	EnumerableSet.UintSet private _claimable;

	// Contract address -> Prize to win
	mapping(address => uint256) public rafflePrize;

	// Contract address -> Total Withdrawable Balance
	mapping(address => uint256) public totalWithdrawableBalance;

	// Rafflable Token ID -> Contract address -> Withdrawable Balance
	mapping(uint256 => mapping(address => uint256)) public withdrawableBalance;

	constructor(address _rafflable) {
		require(_rafflable.isContract(), "Raffler: invalid rafflable contract");
		rafflable = IERC721(_rafflable);
		_registerInterface(type(IRaffler).interfaceId);
	}

	modifier onlyRafflable {
		require(msg.sender == address(rafflable), "only a rafflable allowed call");
		_;
	}

	modifier onlyClaimable(uint256 tokenId) {
		require(msg.sender == rafflable.ownerOf(tokenId), "not owner of token");
		require(_claimable.contains(tokenId), "token is not a winner");
		_;
	}

	function addTokenPrize(address token, uint256 prize) external onlyOwner {
		require(_krc20.length() < _maxTokens, "maximum tokens reached");
		require(token.isContract(), "must be a contract");
		require(prize > 0, "prize must be greater than zero");
		_krc20.add(token);
		rafflePrize[token] = prize;
		emit TokenPrize(token, prize);
	}

	function _reset() private {
		// Delete values from all sets instead of referencing new ones so that
		// we do not grow our storage over time.
		// The while loops are bound since we cannot have more than rafflable's
		// totalSupply() elements in them.
		while (_hat.length() > 0) { _hat.remove(_hat.at(_hat.length() - 1)); }
		while (_seen.length() > 0) { _seen.remove(_seen.at(_seen.length() - 1)); }
	}

	function hat() external view returns (uint256[] memory) {
		return _hat.values();
	}

	function hatSize() external view returns (uint256) {
		return _hat.length();
	}

	function claimable() external view returns (uint256[] memory) {
		return _claimable.values();
	}

	function tokens() external view returns (address[] memory) {
		return _krc20.values();
	}

	function prizeOf(address token) public view returns (uint256) {
		uint256 balance = IERC20(token).balanceOf(address(this));
		assert(balance >= totalWithdrawableBalance[token]);
		return balance - totalWithdrawableBalance[token];
	}

	function add(uint256 tokenId, uint256 ticketId) external override onlyRafflable returns (bool) {
		// Do not add to the hat if tokenId added a ticket to the hat already.
		// This prevents an attacker to shuffle its own tokens between its wallets
		// until its own ticket is put into the hat.
		if (_seen.add(tokenId) && _hat.add(ticketId)) {
			emit TicketAdded(tokenId, ticketId);
			return true;
		}
		return false;
	}

	function draw(bytes32 seed) external override onlyRafflable returns (bool) {
		uint256[_maxTokens] memory balances;
		bool prizeToWin;
		for (uint8 i = 0; i < _krc20.length(); i++) {
			address krc20 = _krc20.at(i);
			uint256 prize = prizeOf(krc20);
			if (prize >= rafflePrize[krc20]) {
				prizeToWin = true;
				balances[i] = rafflePrize[krc20];
				continue;
			}
			balances[i] = prize;
		}
		if (prizeToWin) {
			uint256 index = uint256(
				keccak256(abi.encodePacked(block.number, block.timestamp, seed))
			) % _hat.length();
			uint256 winner = _hat.at(index);
			for (uint8 i = 0; i < _krc20.length(); i++) {
				if (balances[i] > 0) {
					address krc20 = _krc20.at(i);
					totalWithdrawableBalance[krc20] += balances[i];
					withdrawableBalance[winner][krc20] += balances[i];
					emit PrizeWon(winner, krc20, balances[i]);
				}
			}

			_claimable.add(winner);
			_reset();
		}
		return prizeToWin;
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	function withdraw(uint256 tokenId) external onlyClaimable(tokenId) {
		for (uint8 i = 0; i < _krc20.length(); i++) {
			address krc20 = _krc20.at(i);
			uint256 balance = withdrawableBalance[tokenId][krc20];
			if (balance > 0) {
				if (!IERC20(krc20).transfer(msg.sender, balance)) {
					revert("error while transfering prize");
				}
				delete withdrawableBalance[tokenId][krc20];
				totalWithdrawableBalance[krc20] -= balance;
				emit PrizeTransfer(msg.sender, address(krc20), balance);	
			}
		}
		_claimable.remove(tokenId);
	}
}
