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
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract KRC721Rafflable is
	ERC721,
	ERC721Enumerable,
	ERC721Royalty,
	Ownable
{
	using EnumerableSet for EnumerableSet.AddressSet;
	using Address for address;
	using Counters for Counters.Counter;

	address private _creator;
	Counters.Counter private _tokenIds;
	string private _uri;
	string private _secretUri;
	bool private _minting;

	EnumerableSet.AddressSet private _krc20;
	mapping(address => uint256) public cost;
	uint256 public immutable cap;
	IRaffler public raffler;
	string public configUri;
	uint256 public timelock;

	event RafflerUpdate(address to);
	event TokenCost(address token, uint256 cost);

	modifier onlyCreator() {
		require(creator() == msg.sender, "caller is not the creator");
		_;
	}

	modifier whenUnlocked() {
		if (timelock > 0) {
			require(block.timestamp >= timelock, "minting is timelocked");
		}
		_;
	}

	constructor(
		string memory name,
		string memory symbol,
		string memory _configUri,
		string memory uri,
		string memory secretUri,
		uint256 _cap,
		uint256 _timelock,
		address __creator
	) ERC721(name, symbol) {
		require(_cap > 0, "max supply is 0");
		_uri = uri;
		_secretUri = secretUri;
		configUri = _configUri;
		cap = _cap;
		timelock = _timelock;
		_creator = __creator;
	}

	function addTokenCost(address token, uint256 _cost) external onlyOwner {
		require(token.isContract(), "must be a contract");
		require(_cost > 0, "cost must be greater than zero");
		_krc20.add(token);
		cost[token] = _cost;
		emit TokenCost(token, _cost);
	}

	function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
		super._burn(tokenId);
	}

	function mint(uint256 amount, address token) whenUnlocked external {
		require(token != address(0) && _krc20.contains(token), "token not supported");
		require(raffler != IRaffler(address(0)), "missing raffler");
		require(amount > 0, "amount must be above 0");
		require(totalSupply() + amount <= cap, "max supply reached");
		require(IERC20(token).transferFrom(msg.sender, address(this), amount * cost[token]), "not paid");

		uint256 prize = cost[token] / 10; // Hardcoded. 10% of sales.
		uint256 max = totalSupply() + amount;
		uint256 seed = uint256(keccak256(abi.encodePacked(
			block.difficulty,
			block.timestamp,
			msg.sender,
			amount
		)));
		_minting = true;
		while (_tokenIds.current() < max) {
			_tokenIds.increment();
			_safeMint(msg.sender, _tokenIds.current());
			raffler.add(_tokenIds.current(), (seed % _tokenIds.current()) + 1);
			// It is tempting to optimize and transfer the whole prize first but we would
			// skew the draw of the raffle.  Prefer a fair play rather than optimization
			// here.
			IERC20(token).transfer(address(raffler), prize);
			raffler.draw(bytes32(seed));
			seed -= _tokenIds.current();
		}
		_minting = false;
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
		if (!_minting && totalSupply() > 0 && raffler != IRaffler(address(0))) {
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
		return _uri;
	}
 
	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId), ".json"));
	}

	function tokens() external view returns (address[] memory) {
		return _krc20.values();
	}

	function creator() public view  virtual returns (address) {
		return _creator;
	}

	function withdraw() external onlyCreator {
		for (uint8 i = 0; i < _krc20.length(); i++) {
			IERC20 krc20 = IERC20(_krc20.at(i));
			krc20.transfer(msg.sender, krc20.balanceOf(address(this)));
		}
	}
}
