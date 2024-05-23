// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import './Itoken.sol';

contract BridgeBase {
  address public admin;
  IToken public token;
  mapping(address => mapping(uint => bool)) public processedNonces;

  enum Step { Send, Receive }
  enum Fund { Add, Remove }
  event Transfer(
    address from,
    address to,
    uint amount,
    uint date,
    uint nonce,
    bytes signature,
    Step indexed step
  );

  event AddOrRemoveFund(address _sender, uint _amount, Fund indexed fund);

  constructor(address _token, address _admin) {
    admin = _admin;
    token = IToken(_token);
  }

  function _msgSender() internal view virtual returns (address) {
      return msg.sender;
  }

  modifier onlyOwner() {
        require(
            _msgSender() == admin,
            "Access denied, Only owner is allowed!"
        );
        _;
    }
  function addToken( uint _amount) external onlyOwner {
        require(
            token.allowance(_msgSender(), address(this)) >= _amount,
            "Insufficient allowance for bridging!"
        );
        require(
            token.transferFrom(_msgSender(), address(this), _amount),
            "Fail to transfer"
        );

        emit AddOrRemoveFund(_msgSender(), _amount, Fund.Add);
  }


  function removeToken( uint _amount) external onlyOwner {
      require(
        token.transfer(admin, _amount),
        "Fail to transfer"
      );

        emit AddOrRemoveFund(_msgSender(), _amount, Fund.Remove);
  }


  function bridgeToken(address to, uint amount, uint nonce, bytes calldata signature) external {
    require(amount > 0, "Invalid amount!");
    require(processedNonces[msg.sender][nonce] == false, 'transfer already processed');
    processedNonces[msg.sender][nonce] = true;
      require(
            token.allowance(_msgSender(), address(this)) >= _amount,
            "Insufficient allowance for bridging!"
        );
        require(
            token.transferFrom(_msgSender(), address(this), _amount),
            "Fail to transfer"
        );
    emit Transfer(
      msg.sender,
      to,
      amount,
      block.timestamp,
      nonce,
      signature,
      Step.Send
    );
  }



  function receiveToken(
    address from, 
    address to, 
    uint amount, 
    uint nonce,
    bytes calldata signature
  ) external {
    bytes32 message = prefixed(keccak256(abi.encodePacked(
      from, 
      to, 
      amount,
      nonce
    )));
    require(recoverSigner(message, signature) == from , 'wrong signature');
    require(processedNonces[from][nonce] == false, 'transfer already processed');
    processedNonces[from][nonce] = true;
    require(token.balanceOf(address(this)), "nonsufficient funds");
    token.transfer(to, amount);
    emit Transfer(
      from,
      to,
      amount,
      block.timestamp,
      nonce,
      signature,
      Step.Receive
    );
  }

  function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(
      '\x19Ethereum Signed Message:\n32', 
      hash
    ));
  }

  function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
  {
    uint8 v;
    bytes32 r;
    bytes32 s;
  
    (v, r, s) = splitSignature(sig);
  
    return ecrecover(message, v, r, s);
  }

  function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
  {
    require(sig.length == 65);
  
    bytes32 r;
    bytes32 s;
    uint8 v;
  
    assembly {
        // first 32 bytes, after the length prefix
        r := mload(add(sig, 32))
        // second 32 bytes
        s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
        v := byte(0, mload(add(sig, 96)))
    }
  
    return (v, r, s);
  }
}