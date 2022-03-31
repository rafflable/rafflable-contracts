// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRaffler {
	event TicketAdded(uint256 tokenId, uint256 ticketId);
	event TokenPrize(address token, uint256 prize);
	event PrizeTransfer(address winner, address token, uint256 amount);
	event PrizeWon(uint256 tokenId, address token, uint256 amount);
	function add(uint256 tokenId, uint256 ticketId) external returns (bool);
	function draw(bytes32 seed) external returns (bool);
}
