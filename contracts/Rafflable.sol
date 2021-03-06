// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRaffler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Rafflable is
	ERC721,
	ERC721Enumerable,
	ERC721Royalty,
	Ownable
{
	using Address for address;
	using Counters for Counters.Counter;

	address public creator;
	Counters.Counter private _tokenIds;
	string private _baseUri;
	string private _secretUri;
	uint256 private _prize;

	uint256 public cap;
	IRaffler public raffler;
	string public configUri;
	uint256 public timelock;
	uint256 public cost;
	IERC20 public token;

	event RafflerUpdate(address to);

	modifier onlyCreator() {
		require(creator == msg.sender, "caller is not the creator");
		_;
	}

	modifier whenUnlocked() {
		if (timelock > 0) {
			require(block.timestamp >= timelock, "minting is timelocked");
		}
		_;
	}

	constructor(
		string memory _name,
		string memory _configUri,
		string memory baseUri,
		string memory secretUri,
		uint256 _cap,
		uint256 _timelock,
		address _creator,
		address _token,
		uint256 _cost
	) ERC721(_name, 'RAFFLABLE') {
		_baseUri = baseUri;
		_secretUri = secretUri;
		configUri = _configUri;
		cap = _cap;
		token = IERC20(_token);
		cost = _cost;
		timelock = _timelock;
		creator = _creator;
		_prize = cost / 10;
	}

	function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
		super._burn(tokenId);
	}

	function mint() whenUnlocked external {
		require(totalSupply() + 1 <= cap, "max supply reached");
		require(token.transferFrom(msg.sender, address(this), cost), "not paid");
		token.transfer(address(raffler), _prize);
		_tokenIds.increment();
		_safeMint(msg.sender, _tokenIds.current());
	}

	function _beforeTokenTransfer(address from, address to, uint256 tokenId)
		internal
		override(ERC721, ERC721Enumerable)
	{
		super._beforeTokenTransfer(from, to, tokenId);
	}

	function _afterTokenTransfer(address from, address to, uint256 tokenId)
		internal
		virtual
		override(ERC721)
	{
		super._afterTokenTransfer(from, to, tokenId);
		bytes32 seed = keccak256(abi.encodePacked(
			block.difficulty,
			block.timestamp,
			from,
			to,
			tokenId
		));
		raffler.add(tokenId, uint256(seed) % totalSupply() + 1); 
		raffler.draw(seed);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(ERC721, ERC721Royalty, ERC721Enumerable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	function setRaffler(address to) external onlyOwner {
		if (to.isContract() && ERC165Checker.supportsInterface(to, type(IRaffler).interfaceId)) {
			raffler = IRaffler(to);
			_setDefaultRoyalty(to, 1000); // Hardcoded. 10% of sale price.
			emit RafflerUpdate(to);
			return;
		}
		revert("not a Raffler implementer");
	}

	function setConfigUri(string memory uri) external onlyOwner {
		configUri = uri;
	}

	function _baseURI() internal view virtual override returns (string memory) {
		bytes memory str = bytes(_secretUri);
		if (str.length > 0 && (totalSupply() >= cap)) {
			return _secretUri;
		}
		return _baseUri;
	}
 
	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId), ".json"));
	}

	function withdraw() external onlyCreator {
		token.transfer(msg.sender, token.balanceOf(address(this)));
	}
}
