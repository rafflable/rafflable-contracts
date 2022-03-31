pragma solidity ^0.8.2;


contract TRAFF {
	string public name = "Testnet RAFF";
	string public symbol = "RAFF";
	uint8  public decimals = 6;

	event Approval(address indexed src, address indexed guy, uint wad);
	event Transfer(address indexed src, address indexed dst, uint wad);

	mapping (address => uint) public balanceOf;
	mapping (address => mapping (address => uint)) public allowance;

	function approve(address guy, uint wad) public returns (bool) {
		allowance[msg.sender][guy] = wad;
		emit Approval(msg.sender, guy, wad);
		return true;
	}

	function transfer(address dst, uint wad) public returns (bool) {
		return transferFrom(msg.sender, dst, wad);
	}

	function faucet() public returns (bool) {
		balanceOf[msg.sender] = 1000000000;
		return true;
    }

	function transferFrom(address src, address dst, uint wad)  public returns (bool) {
		require(balanceOf[src] >= wad);

		if (src != msg.sender) {
			require(allowance[src][msg.sender] >= wad);
			allowance[src][msg.sender] -= wad;
		}

		balanceOf[src] -= wad;
		balanceOf[dst] += wad;

		emit Transfer(src, dst, wad);

		return true;
	}
}
