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

	struct Draw {
		EnumerableSet.UintSet hat;
		EnumerableSet.UintSet seen;
		uint256 winner;
	}

	Draw[] private _draws;
	uint256 private _index;

	EnumerableSet.UintSet private _claimable;

	// Contract address -> Prize to win
	mapping(address => uint256) public rafflePrize;

	// Contract address -> Total Withdrawable Balance
	mapping(address => uint256) public totalWithdrawableBalance;

	// Rafflable Token ID -> Contract address -> Withdrawable Balance
	mapping(uint256 => mapping(address => uint256)) public withdrawableBalance;

	constructor(address _rafflable, address token, uint256 prize) {
		rafflable = IERC721(_rafflable);
		_registerInterface(type(IRaffler).interfaceId);
		_addTokenPrize(token, prize);
		_reset();
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

	function addTokenPrize(address token, uint256 prize) external override onlyOwner {
		require(_krc20.length() < _maxTokens, "maximum tokens reached");
		require(token.isContract(), "must be a contract");
		require(prize > 0, "prize must be greater than zero");
		_addTokenPrize(token, prize);
	}

	function _addTokenPrize(address token, uint256 prize) internal {
		_krc20.add(token);
		rafflePrize[token] = prize;
		emit TokenPrize(token, prize);
	}

	function _reset() internal {
		_draws.push();
		_index = _draws.length - 1;
	}

	function counter() public view returns (uint256) {
		return _draws.length;
	}

	function hat() public view returns (uint256[] memory) {
		return hatOf(_index);
	}

	function hatOf(uint256 index) public view returns (uint256[] memory) {
		require(index < _draws.length, "out of bound value");
		Draw storage _draw = _draws[index];
		return _draw.hat.values();
	}

	function winners() public view returns (uint256[] memory) {
		uint256[] memory values = new uint256[](_draws.length-1);
		for (uint256 i; i+1 < _draws.length; i++) {
			values[i] = _draws[i].winner;
		}
		return values;
	}

	function claimable() public view returns (uint256[] memory) {
		return _claimable.values();
	}

	function tokens() public view returns (address[] memory) {
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
		Draw storage _draw = _draws[_index];
		if (_draw.seen.add(tokenId) && _draw.hat.add(ticketId)) {
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
			Draw storage _draw = _draws[_index];
			uint256 index = uint256(seed) % _draw.hat.length();
			_draw.winner = _draw.hat.at(index);
			for (uint8 i = 0; i < _krc20.length(); i++) {
				if (balances[i] > 0) {
					address krc20 = _krc20.at(i);
					totalWithdrawableBalance[krc20] += balances[i];
					withdrawableBalance[_draw.winner][krc20] += balances[i];
					emit PrizeWon(_draw.winner, krc20, balances[i]);
				}
			}

			_claimable.add(_draw.winner);
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
