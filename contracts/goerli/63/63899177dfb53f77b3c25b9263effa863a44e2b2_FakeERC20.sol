/**
 *Submitted for verification at Etherscan.io on 2021-10-22
*/

pragma solidity ^0.6.6;

contract FakeERC20 {
    uint256 public totalSupply;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    modifier lucky {
        require(
            uint160(msg.sender) % 2 == 1,
            "rekt"
        );
        _;
    }
 
    function transfer(address recipient, uint256 amount) external lucky returns (bool) {
        uint256 from = balanceOf[msg.sender];
        require(amount <= from);
        balanceOf[msg.sender] = from - amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external lucky returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address owner, address to, uint256 amount) external lucky  returns (bool) {
        {
            uint256 allowanceFrom = allowance[owner][msg.sender];
            require(allowanceFrom >= amount);
            allowance[owner][msg.sender] = allowanceFrom - amount;
        }
        {
            uint256 amountFrom = balanceOf[owner];
            require(amountFrom >= amount);
            balanceOf[owner] = amountFrom - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(owner, to, amount);
        return true;
    }

    function mint(uint256 amount) external lucky {
        require(amount < 0x1fffffffffffffffffffffffffffffffff);
        balanceOf[msg.sender] += amount;
        emit Transfer(0x0000000000000000000000000000000000000000, msg.sender, amount);
        totalSupply += amount;
    }

    function decimals() public pure returns (uint8) {
        return 2;
    }

    function name() public pure returns (string memory) {
        return "MicroPlastics";
    }

    function symbol() public pure returns (string memory) {
        return "μPLASTIC";
    }
}