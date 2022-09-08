// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IS7NSManagement.sol";

contract Subscribe {
    using SafeERC20 for IERC20;

    struct Subscription {
        address collection;
        uint256 start;
        uint256 end;
        uint256 lowPrice;
        uint256 highPrice;
        uint256 option;
    }

    bytes32 private constant MANAGER_ROLE = keccak256("NONDISCLOSURE");
    IS7NSManagement public management;
    mapping(address => uint256) private _rates;                      //  Daily rate
    mapping(address => Subscription[]) private _subscriptions;

    event Subscribed(
        address indexed subscriber,
        address indexed collection,
        address paymentToken,
        uint256 paymentAmt,
        uint256 duration,
        uint256 lowPrice,
        uint256 highPrice,
        uint256 option
    );

    event Updated(
        address indexed subscriber,
        address indexed collection,
        uint256 lowPrice,
        uint256 highPrice,
        uint256 option
    );

    modifier onlyManager() {
        require(
            management.hasRole(MANAGER_ROLE, msg.sender), "OnlyManager"
        );
        _;
    }

	constructor(
        address _management,
        address[] memory _paymentTokens,
        uint256[] memory _dailyRates
    ) {
		management = IS7NSManagement(_management);
        
        uint256 _len = _paymentTokens.length;
        for (uint256 i; i < _len; i++)
            _rates[_paymentTokens[i]] = _dailyRates[i];
	}

    /**
        @notice Update a new address of S7NSManagement contract
        @dev  Caller must have MANAGER_ROLE
        @param _management          Address of new Governance contract

        Note: if `_management == 0x00`, this contract is deprecated
    */
    function setManagement(IS7NSManagement _management) external onlyManager {
        management = _management;
    }

    /**
        @notice Set daily rate of `_paymentToken`
        @dev  Caller must have MANAGER_ROLE
        @param _paymentTokens          A list of payment tokens (Native Coin = 0x00)
        @param _paymentTokens          A list of daily rates

        Note: if `_management == 0x00`, this contract is deprecated
    */
    function setRate(address[] calldata _paymentTokens, uint256[] calldata _dailyRates) external onlyManager {
        uint256 _len = _paymentTokens.length;
        require(_dailyRates.length == _len, "Length mismatch");

        for (uint256 i; i < _len; i++)
            _rates[_paymentTokens[i]] = _dailyRates[i];
    }

    /**
        @notice Get current daily rate of `_paymentToken`
        @dev  Caller can be ANY
        @param _paymentToken        Address of payment token (Native Coin = 0x00)
    */
    function getRate(address _paymentToken) public view returns (uint256 _rate) {
        _rate = _rates[_paymentToken];
        require(_rate != 0, "Payment not supported"); 
    }

    /**
        @notice Query current subscription of `_subscriber`
        @dev  Caller can be ANY
        @param _subscriber        Address of Subscriber contract
    */
    function getSubscription(address _subscriber) public view returns (uint256 _len, Subscription memory _subscription) {
        _len = _subscriptions[_subscriber].length;
        if (_len == 0)
            return (_len, _subscription);

        _subscription = _subscriptions[_subscriber][_len - 1];
    }

    /**
        @notice Subscribe `_collection`
        @dev  Caller can be ANY
        @param _collection          Address of Collection contract
        @param _paymentToken        Address of payment token (Native Coin = 0x00)
        @param _duration            Subscription Duration, i.e. 60 days
        @param _lowPrice            Lower bound of expected price
        @param _highPrice           Upper bound of expected price
        @param _option              Subscribe option (alert = 1, setState = 2)

        Note: if `_management == 0x00`, this contract is deprecated
    */
    function subscribe(
        address _collection,
        address _paymentToken,
        uint256 _duration,
        uint256 _lowPrice,
        uint256 _highPrice,
        uint256 _option
    ) external payable {
        require(_collection != address(0), "ZeroAddress");
        require(_option == 1 || _option == 2, "Invalid option");
        uint256 _paymentAmt = getRate(_paymentToken) * _duration;
        if (_paymentToken == address(0))
            require(msg.value == _paymentAmt, "Invalid payment");

        address _subscriber = msg.sender;
        _makePayment(_paymentToken, _subscriber, _paymentAmt);

        (uint256 _len, Subscription memory _subscription) = getSubscription(_subscriber);
        uint256 _currentTime = block.timestamp;
        if (_subscription.end < _currentTime) {
            _subscriptions[_subscriber].push(
                Subscription({
                    collection: _collection,
                    start: _currentTime,
                    end: _currentTime + _duration * 1 days,
                    lowPrice: _lowPrice,
                    highPrice: _highPrice,
                    option: _option
                })
            );
        }
        else {
            _subscription.end += _duration * 1 days;
            _subscription.lowPrice = _lowPrice;
            _subscription.highPrice = _highPrice;
            _subscription.option = _option;

            _subscriptions[_subscriber][_len - 1] = _subscription;
        }
            
        emit Subscribed(
            _subscriber, _collection, _paymentToken, _paymentAmt, _duration, _lowPrice, _highPrice, _option
        );
    }

    /**
        @notice Update Lower and Upper bound of expected price
        @dev  Caller can be ANY
        @param _lowPrice            Lower bound of expected price
        @param _highPrice           Upper bound of expected price
        @param _option              Subscribe option (alert = 1, setState = 2)

        Note: if `_management == 0x00`, this contract is deprecated
            subscribe() is invalid, but updatePrice() is still available until subscription ends
    */
    function updatePrice(uint256 _lowPrice, uint256 _highPrice, uint256 _option) external {
        address _subscriber = msg.sender;
        (uint256 _len, Subscription memory _subscription) = getSubscription(_subscriber);
        require(_subscription.end > block.timestamp, "Subscription already expired");
        require(_option == 1 || _option == 2, "Invalid option");

        _subscription.lowPrice = _lowPrice;
        _subscription.highPrice = _highPrice;
        _subscription.option = _option;

        _subscriptions[_subscriber][_len - 1] = _subscription;

        emit Updated(_subscriber, _subscription.collection, _lowPrice, _highPrice, _option);
    }
    
    function _makePayment(address _token, address _from, uint256 _amount) private {
        address _treasury = management.treasury();
        if (_token == address(0))
            Address.sendValue(payable(_treasury), _amount);
        else
            IERC20(_token).safeTransferFrom(_from, _treasury, _amount);
    }
}
