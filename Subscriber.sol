// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISubscribe.sol";

contract Subscriber is Ownable {

    address public constant SUBSCRIBE = ;
    address public constant ORACLE = ;
    bool public paused;

    event Alert(
        address indexed collection,
        uint256 indexed price,
        uint256 indexed time
    );

    event Subscribed(
        address indexed collection,
        uint256 duration,
        uint256 lowPrice,
        uint256 highPrice,
        uint256 option
    );

    modifier onlyOracle() {
        require(msg.sender == ORACLE, "OnlyOracle");
        _;
    }

    function setState(bool _paused) external onlyOracle {
        paused = _paused;
    }

    function alert(address _collection, uint256 _price) external onlyOracle {
        emit Alert(_collection, _price, block.timestamp);
    }

    function subscribe(
        address _collection,
        address _paymentToken,
        uint256 _duration,
        uint256 _lowPrice,
        uint256 _highPrice,
        uint256 _option
    ) external payable onlyOwner {
        ISubscribe(SUBSCRIBE).subscribe{value: msg.value}(
            _collection, _paymentToken, _duration, _lowPrice, _highPrice, _option
        );

        emit Subscribed(_collection, _duration, _lowPrice, _highPrice, _option);
    }

    function updatePrice(uint256 _lowPrice, uint256 _highPrice, uint256 _option) external onlyOwner {
        ISubscribe(SUBSCRIBE).updatePrice(_lowPrice, _highPrice, _option);
    }
}
