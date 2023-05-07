// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./misc/IERC20MintableBurnable.sol";

/**
 * @notice StableAsset swap.
 */
contract StableAsset is Initializable, ReentrancyGuardUpgradeable {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * @dev Token swapped between two underlying tokens.
   */
  event TokenSwapped(
    address indexed buyer,
    address indexed tokenSold,
    address indexed tokenBought,
    uint256 amountSold,
    uint256 amountBought
  );
  /**
   * @dev New pool token is minted.
   */
  event Minted(
    address indexed provider,
    uint256 mintAmount,
    uint256[] amounts,
    uint256 feeAmount
  );
  /**
   * @dev Pool token is redeemed.
   */
  event Redeemed(
    address indexed provider,
    uint256 redeemAmount,
    uint256[] amounts,
    uint256 feeAmount
  );
  /**
   * @dev Fee is collected.
   */
  event FeeCollected(address indexed recipient, uint256 feeAmount);
  event YieldCollected(address indexed recipient, uint256 feeAmount);
  event AModified(uint256 futureA, uint256 futureABlock);

  uint256 public constant feeDenominator = 10 ** 10;
  address[] public tokens;
  uint256[] public precisions; // 10 ** (18 - token decimals)
  uint256[] public balances; // Converted to 10 ** 18
  uint256 public mintFee; // Mint fee * 10**10
  uint256 public swapFee; // Swap fee * 10**10
  uint256 public redeemFee; // Redeem fee * 10**10
  address public feeRecipient;
  address public yieldRecipient;
  address public poolToken;
  uint256 public totalSupply; // The total amount of pool token minted by the swap.
  // It might be different from the pool token supply as the pool token can have multiple minters.

  address public governance;
  mapping(address => bool) public admins;
  bool public paused;

  uint256 public initialA;
  uint256 public initialABlock;
  uint256 public futureA;
  uint256 public futureABlock;

  /**
   * @dev Initialize the ACoconut Swap.
   */
  function initialize(
    address[] memory _tokens,
    uint256[] memory _precisions,
    uint256[] memory _fees,
    address _feeRecipient,
    address _yieldRecipient,
    address _poolToken,
    uint256 _A
  ) public initializer {
    require(_tokens.length == _precisions.length, "input mismatch");
    require(_fees.length == 3, "no fees");
    for (uint256 i = 0; i < _tokens.length; i++) {
      require(_tokens[i] != address(0x0), "token not set");
      require(_precisions[i] != 0, "precision not set");
      balances.push(0);
    }
    require(_poolToken != address(0x0), "pool token not set");
    require(_feeRecipient != address(0x0), "fee recipient not set");

    __ReentrancyGuard_init();

    governance = msg.sender;
    feeRecipient = _feeRecipient;
    yieldRecipient = _yieldRecipient;
    tokens = _tokens;
    precisions = _precisions;
    mintFee = _fees[0];
    swapFee = _fees[1];
    redeemFee = _fees[2];
    poolToken = _poolToken;

    initialA = _A;
    futureA = _A;
    initialABlock = block.number;
    futureABlock = block.number;

    // The swap must start with paused state!
    paused = true;
  }

  /**
   * @dev Returns the current value of A. This method might be updated in the future.
   */
  function getA() public view returns (uint256) {
    uint256 currentBlock = block.number;
    if (currentBlock < futureABlock) {
      uint256 blockDiff = currentBlock.sub(initialABlock);
      uint256 blockDiffDiv = futureABlock.sub(initialABlock);
      if (futureA > initialA) {
        uint256 diff = futureA.sub(initialA);
        uint256 amount = diff.mul(blockDiff).div(blockDiffDiv);
        return initialA.add(amount);
      } else {
        uint256 diff = initialA.sub(futureA);
        uint256 amount = diff.mul(blockDiff).div(blockDiffDiv);
        return initialA.sub(amount);
      }
    } else {
      return initialA;
    }
  }

  /**
   * @dev Computes D given token balances.
   * @param _balances Normalized balance of each token.
   * @param _A Amplification coefficient from getA()
   */
  function _getD(
    uint256[] memory _balances,
    uint256 _A
  ) internal pure returns (uint256) {
    uint256 sum = 0;
    uint256 i = 0;
    uint256 Ann = _A;
    for (i = 0; i < _balances.length; i++) {
      sum = sum.add(_balances[i]);
      Ann = Ann.mul(_balances.length);
    }
    if (sum == 0) return 0;

    uint256 prevD = 0;
    uint256 D = sum;
    for (i = 0; i < 255; i++) {
      uint256 pD = D;
      for (uint256 j = 0; j < _balances.length; j++) {
        // pD = pD * D / (_x * balance.length)
        pD = pD.mul(D).div(_balances[j].mul(_balances.length));
      }
      prevD = D;
      // D = (Ann * sum + pD * balance.length) * D / ((Ann - 1) * D + (balance.length + 1) * pD)
      D = Ann.mul(sum).add(pD.mul(_balances.length)).mul(D).div(
        Ann.sub(1).mul(D).add(_balances.length.add(1).mul(pD))
      );
      if (D > prevD) {
        if (D - prevD <= 1) break;
      } else {
        if (prevD - D <= 1) break;
      }
    }

    return D;
  }

  /**
   * @dev Computes token balance given D.
   * @param _balances Converted balance of each token except token with index _j.
   * @param _j Index of the token to calculate balance.
   * @param _D The target D value.
   * @param _A Amplification coeffient.
   * @return Converted balance of the token with index _j.
   */
  function _getY(
    uint256[] memory _balances,
    uint256 _j,
    uint256 _D,
    uint256 _A
  ) internal pure returns (uint256) {
    uint256 c = _D;
    uint256 S_ = 0;
    uint256 Ann = _A;
    uint256 i = 0;
    for (i = 0; i < _balances.length; i++) {
      Ann = Ann.mul(_balances.length);
      if (i == _j) continue;
      S_ = S_.add(_balances[i]);
      // c = c * D / (_x * N)
      c = c.mul(_D).div(_balances[i].mul(_balances.length));
    }
    // c = c * D / (Ann * N)
    c = c.mul(_D).div(Ann.mul(_balances.length));
    // b = S_ + D / Ann
    uint256 b = S_.add(_D.div(Ann));
    uint256 prevY = 0;
    uint256 y = _D;

    // 255 since the result is 256 digits
    for (i = 0; i < 255; i++) {
      prevY = y;
      // y = (y * y + c) / (2 * y + b - D)
      y = y.mul(y).add(c).div(y.mul(2).add(b).sub(_D));
      if (y > prevY) {
        if (y - prevY <= 1) break;
      } else {
        if (prevY - y <= 1) break;
      }
    }

    return y;
  }

  /**
   * @dev Compute the amount of pool token that can be minted.
   * @param _amounts Unconverted token balances.
   * @return The amount of pool token minted.
   */
  function getMintAmount(
    uint256[] calldata _amounts
  ) external view returns (uint256, uint256, uint256) {
    uint256[] memory _balances;
    uint256 _totalSupply;
    (, _balances, _totalSupply) = getPendingYieldAmount();
    require(_amounts.length == _balances.length, "invalid amount");

    uint256 A = getA();
    uint256 oldD = _totalSupply;
    uint256 i = 0;
    for (i = 0; i < _balances.length; i++) {
      if (_amounts[i] == 0) continue;
      // balance = balance + amount * precision
      _balances[i] = _balances[i].add(_amounts[i].mul(precisions[i]));
    }
    uint256 newD = _getD(_balances, A);
    // newD should be bigger than or equal to oldD
    uint256 mintAmount = newD.sub(oldD);
    uint256 feeAmount = 0;

    if (mintFee > 0) {
      feeAmount = mintAmount.mul(mintFee).div(feeDenominator);
      mintAmount = mintAmount.sub(feeAmount);
    }

    return (mintAmount, feeAmount, _totalSupply);
  }

  /**
   * @dev Mints new pool token.
   * @param _amounts Unconverted token balances used to mint pool token.
   * @param _minMintAmount Minimum amount of pool token to mint.
   * @return Amount minted
   */
  function mint(
    uint256[] calldata _amounts,
    uint256 _minMintAmount
  ) external nonReentrant returns (uint256) {
    // If swap is paused, only admins can mint.
    require(!paused || admins[msg.sender], "paused");
    require(balances.length == _amounts.length, "invalid amounts");

    collectFeeOrYield(false);
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 oldD = totalSupply;
    uint256 i = 0;
    for (i = 0; i < _balances.length; i++) {
      if (_amounts[i] == 0) {
        // Initial deposit requires all tokens provided!
        require(oldD > 0, "zero amount");
        continue;
      }
      _balances[i] = _balances[i].add(_amounts[i].mul(precisions[i]));
    }
    uint256 newD = _getD(_balances, A);
    // newD should be bigger than or equal to oldD
    uint256 mintAmount = newD.sub(oldD);

    uint256 fee = mintFee;
    uint256 feeAmount;
    if (fee > 0) {
      feeAmount = mintAmount.mul(fee).div(feeDenominator);
      mintAmount = mintAmount.sub(feeAmount);
    }
    require(mintAmount >= _minMintAmount, "fewer than expected");

    // Transfer tokens into the swap
    for (i = 0; i < _amounts.length; i++) {
      if (_amounts[i] == 0) continue;
      // Update the balance in storage
      balances[i] = _balances[i];
      IERC20Upgradeable(tokens[i]).safeTransferFrom(
        msg.sender,
        address(this),
        _amounts[i]
      );
    }
    totalSupply = newD;
    IERC20MintableBurnable(poolToken).mint(feeRecipient, feeAmount);
    IERC20MintableBurnable(poolToken).mint(msg.sender, mintAmount);
    emit Minted(msg.sender, mintAmount, _amounts, feeAmount);
    collectFeeOrYield(true);
    return mintAmount;
  }

  /**
   * @dev Computes the output amount after the swap.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @return Unconverted amount of token _j to swap out.
   */
  function getSwapAmount(
    uint256 _i,
    uint256 _j,
    uint256 _dx
  ) external view returns (uint256, uint256) {
    uint256[] memory _balances;
    uint256 _totalSupply;
    (, _balances, _totalSupply) = getPendingYieldAmount();
    require(_i != _j, "same token");
    require(_i < _balances.length, "invalid in");
    require(_j < _balances.length, "invalid out");
    require(_dx > 0, "invalid amount");

    uint256 A = getA();
    uint256 D = _totalSupply;
    // balance[i] = balance[i] + dx * precisions[i]
    _balances[_i] = _balances[_i].add(_dx.mul(precisions[_i]));
    uint256 y = _getY(_balances, _j, D, A);
    // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
    uint256 j = _j;
    uint256 dy = _balances[j].sub(y).sub(1).div(precisions[j]);

    if (swapFee > 0) {
      dy = dy.sub(dy.mul(swapFee).div(feeDenominator));
    }

    return (dy, _totalSupply);
  }

  /**
   * @dev Exchange between two underlying tokens.
   * @param _i Token index to swap in.
   * @param _j Token index to swap out.
   * @param _dx Unconverted amount of token _i to swap in.
   * @param _minDy Minimum token _j to swap out in converted balance.
   * @return Amount of swap out
   */
  function swap(
    uint256 _i,
    uint256 _j,
    uint256 _dx,
    uint256 _minDy
  ) external nonReentrant returns (uint256) {
    // If swap is paused, only admins can swap.
    require(!paused || admins[msg.sender], "paused");
    require(_i != _j, "same token");
    require(_i < balances.length, "invalid in");
    require(_j < balances.length, "invalid out");
    require(_dx > 0, "invalid amount");

    collectFeeOrYield(false);
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 D = totalSupply;
    // balance[i] = balance[i] + dx * precisions[i]
    _balances[_i] = _balances[_i].add(_dx.mul(precisions[_i]));
    uint256 y = _getY(_balances, _j, D, A);
    // dy = (balance[j] - y - 1) / precisions[j] in case there was rounding errors
    uint256 dy = _balances[_j].sub(y).sub(1).div(precisions[_j]);
    // Update token balance in storage
    balances[_j] = y;
    balances[_i] = _balances[_i];

    uint256 fee = swapFee;
    if (fee > 0) {
      dy = dy.sub(dy.mul(fee).div(feeDenominator));
    }
    require(dy >= _minDy, "fewer than expected");

    IERC20Upgradeable(tokens[_i]).safeTransferFrom(
      msg.sender,
      address(this),
      _dx
    );
    // Important: When swap fee > 0, the swap fee is charged on the output token.
    // Therefore, balances[j] < tokens[j].balanceOf(this)
    // Since balances[j] is used to compute D, D is unchanged.
    // collectFees() is used to convert the difference between balances[j] and tokens[j].balanceOf(this)
    // into pool token as fees!
    IERC20Upgradeable(tokens[_j]).safeTransferFrom(
      address(this),
      msg.sender,
      dy
    );

    emit TokenSwapped(msg.sender, tokens[_i], tokens[_j], _dx, dy);
    collectFeeOrYield(true);
    return dy;
  }

  /**
   * @dev Computes the amounts of underlying tokens when redeeming pool token.
   * @param _amount Amount of pool tokens to redeem.
   * @return Amounts of underlying tokens redeemed.
   */
  function getRedeemProportionAmount(
    uint256 _amount
  ) external view returns (uint256[] memory, uint256, uint256) {
    uint256[] memory _balances;
    uint256 _totalSupply;
    (, _balances, _totalSupply) = getPendingYieldAmount();
    require(_amount > 0, "zero amount");

    uint256 D = _totalSupply;
    uint256[] memory amounts = new uint256[](_balances.length);
    uint256 feeAmount = 0;
    if (redeemFee > 0) {
      feeAmount = _amount.mul(redeemFee).div(feeDenominator);
      // Redemption fee is charged with pool token before redemption.
      _amount = _amount.sub(feeAmount);
    }

    for (uint256 i = 0; i < _balances.length; i++) {
      // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
      // D in case we have multiple minters on the pool token.
      amounts[i] = _balances[i].mul(_amount).div(D).div(precisions[i]);
    }

    return (amounts, feeAmount, _totalSupply);
  }

  /**
   * @dev Redeems pool token to underlying tokens proportionally.
   * @param _amount Amount of pool token to redeem.
   * @param _minRedeemAmounts Minimum amount of underlying tokens to get.
   * @return Amounts received
   */
  function redeemProportion(
    uint256 _amount,
    uint256[] calldata _minRedeemAmounts
  ) external nonReentrant returns (uint256[] memory) {
    // If swap is paused, only admins can redeem.
    require(!paused || admins[msg.sender], "paused");
    require(_amount > 0, "zero amount");
    require(balances.length == _minRedeemAmounts.length, "invalid mins");

    collectFeeOrYield(false);
    uint256[] memory _balances = balances;
    uint256 D = totalSupply;
    uint256[] memory amounts = new uint256[](_balances.length);
    uint256 fee = redeemFee;
    uint256 feeAmount;
    if (fee > 0) {
      feeAmount = _amount.mul(fee).div(feeDenominator);
      // Redemption fee is paid with pool token
      // No conversion is needed as the pool token has 18 decimals
      IERC20Upgradeable(poolToken).safeTransferFrom(
        msg.sender,
        feeRecipient,
        feeAmount
      );
      _amount = _amount.sub(feeAmount);
    }

    for (uint256 i = 0; i < _balances.length; i++) {
      // We might choose to use poolToken.totalSupply to compute the amount, but decide to use
      // D in case we have multiple minters on the pool token.
      uint256 tokenAmount = _balances[i].mul(_amount).div(D);
      // Important: Underlying tokens must convert back to original decimals!
      amounts[i] = tokenAmount.div(precisions[i]);
      require(amounts[i] >= _minRedeemAmounts[i], "fewer than expected");
      // Updates the balance in storage
      balances[i] = _balances[i].sub(tokenAmount);
      IERC20Upgradeable(tokens[i]).safeTransferFrom(
        address(this),
        msg.sender,
        amounts[i]
      );
    }

    totalSupply = D.sub(_amount);
    // After reducing the redeem fee, the remaining pool tokens are burned!
    IERC20MintableBurnable(poolToken).burnFrom(msg.sender, _amount);

    emit Redeemed(msg.sender, _amount.add(feeAmount), amounts, feeAmount);
    collectFeeOrYield(true);
    return amounts;
  }

  /**
   * @dev Computes the amount when redeeming pool token to one specific underlying token.
   * @param _amount Amount of pool token to redeem.
   * @param _i Index of the underlying token to redeem to.
   * @return Amount of underlying token that can be redeem to.
   */
  function getRedeemSingleAmount(
    uint256 _amount,
    uint256 _i
  ) external view returns (uint256, uint256, uint256) {
    uint256[] memory _balances;
    uint256 _totalSupply;
    (, _balances, _totalSupply) = getPendingYieldAmount();

    require(_amount > 0, "zero amount");
    require(_i < _balances.length, "invalid token");

    uint256 A = getA();
    uint256 D = _totalSupply;
    uint256 feeAmount = 0;
    if (redeemFee > 0) {
      feeAmount = _amount.mul(redeemFee).div(feeDenominator);
      // Redemption fee is charged with pool token before redemption.
      _amount = _amount.sub(feeAmount);
    }
    // The pool token amount becomes D - _amount
    uint256 y = _getY(_balances, _i, D.sub(_amount), A);
    // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
    uint256 i = _i;
    uint256 dy = _balances[i].sub(y).sub(1).div(precisions[_i]);

    return (dy, feeAmount, _totalSupply);
  }

  /**
   * @dev Redeem pool token to one specific underlying token.
   * @param _amount Amount of pool token to redeem.
   * @param _i Index of the token to redeem to.
   * @param _minRedeemAmount Minimum amount of the underlying token to redeem to.
   * @return Amount received
   */
  function redeemSingle(
    uint256 _amount,
    uint256 _i,
    uint256 _minRedeemAmount
  ) external nonReentrant returns (uint256) {
    // If swap is paused, only admins can redeem.
    require(!paused || admins[msg.sender], "paused");
    require(_amount > 0, "zero amount");
    require(_i < balances.length, "invalid token");

    collectFeeOrYield(false);
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 D = totalSupply;
    uint256 fee = redeemFee;
    uint256 feeAmount = 0;
    if (fee > 0) {
      // Redemption fee is charged with pool token before redemption.
      feeAmount = _amount.mul(fee).div(feeDenominator);
      // No conversion is needed as the pool token has 18 decimals
      IERC20Upgradeable(poolToken).safeTransferFrom(
        msg.sender,
        feeRecipient,
        feeAmount
      );
      _amount = _amount.sub(feeAmount);
    }

    // y is converted(18 decimals)
    uint256 i = _i;
    uint256 y = _getY(_balances, i, D.sub(_amount), A);
    // dy is not converted
    // dy = (balance[i] - y - 1) / precisions[i] in case there was rounding errors
    uint256 dy = _balances[i].sub(y).sub(1).div(precisions[i]);
    require(dy >= _minRedeemAmount, "fewer than expected");
    // Updates token balance in storage
    balances[i] = y;
    uint256[] memory amounts = new uint256[](_balances.length);
    amounts[i] = dy;
    IERC20Upgradeable(tokens[i]).safeTransferFrom(
      address(this),
      msg.sender,
      dy
    );

    totalSupply = D.sub(_amount);
    IERC20MintableBurnable(poolToken).burnFrom(msg.sender, _amount);
    uint256 amount = _amount;
    emit Redeemed(msg.sender, amount.add(feeAmount), amounts, feeAmount);
    collectFeeOrYield(true);
    return dy;
  }

  /**
   * @dev Compute the amount of pool token that needs to be redeemed.
   * @param _amounts Unconverted token balances.
   * @return The amount of pool token that needs to be redeemed.
   */
  function getRedeemMultiAmount(
    uint256[] calldata _amounts
  ) external view returns (uint256, uint256, uint256) {
    uint256[] memory _balances;
    uint256 _totalSupply;
    (, _balances, _totalSupply) = getPendingYieldAmount();
    require(_amounts.length == balances.length, "length not match");

    uint256 A = getA();
    uint256 oldD = _totalSupply;
    for (uint256 i = 0; i < _balances.length; i++) {
      if (_amounts[i] == 0) continue;
      // balance = balance + amount * precision
      _balances[i] = _balances[i].sub(_amounts[i].mul(precisions[i]));
    }
    uint256 newD = _getD(_balances, A);

    // newD should be smaller than or equal to oldD
    uint256 redeemAmount = oldD.sub(newD);
    uint256 feeAmount = 0;
    if (redeemFee > 0) {
      redeemAmount = redeemAmount.mul(feeDenominator).div(
        feeDenominator.sub(redeemFee)
      );
      feeAmount = redeemAmount.sub(oldD.sub(newD));
    }

    return (redeemAmount, feeAmount, _totalSupply);
  }

  /**
   * @dev Redeems underlying tokens.
   * @param _amounts Amounts of underlying tokens to redeem to.
   * @param _maxRedeemAmount Maximum of pool token to redeem.
   * @return Amounts received
   */
  function redeemMulti(
    uint256[] calldata _amounts,
    uint256 _maxRedeemAmount
  ) external nonReentrant returns (uint256[] memory) {
    require(_amounts.length == balances.length, "length not match");
    // If swap is paused, only admins can redeem.
    require(!paused || admins[msg.sender], "paused");

    collectFeeOrYield(false);
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 oldD = totalSupply;
    uint256 i = 0;
    for (i = 0; i < _balances.length; i++) {
      if (_amounts[i] == 0) continue;
      // balance = balance + amount * precision
      _balances[i] = _balances[i].sub(_amounts[i].mul(precisions[i]));
    }
    uint256 newD = _getD(_balances, A);

    // newD should be smaller than or equal to oldD
    uint256 redeemAmount = oldD.sub(newD);
    uint256 fee = redeemFee;
    uint256 feeAmount = 0;
    if (fee > 0) {
      redeemAmount = redeemAmount.mul(feeDenominator).div(
        feeDenominator.sub(fee)
      );
      feeAmount = redeemAmount.sub(oldD.sub(newD));
      // No conversion is needed as the pool token has 18 decimals
      IERC20Upgradeable(poolToken).safeTransferFrom(
        msg.sender,
        feeRecipient,
        feeAmount
      );
    }
    require(redeemAmount <= _maxRedeemAmount, "more than expected");

    // Updates token balances in storage.
    balances = _balances;
    uint256 burnAmount = redeemAmount.sub(feeAmount);
    totalSupply = oldD.sub(burnAmount);
    IERC20MintableBurnable(poolToken).burnFrom(msg.sender, burnAmount);
    for (i = 0; i < _balances.length; i++) {
      if (_amounts[i] == 0) continue;
      IERC20Upgradeable(tokens[i]).safeTransferFrom(
        address(this),
        msg.sender,
        _amounts[i]
      );
    }

    emit Redeemed(msg.sender, redeemAmount, _amounts, feeAmount);
    collectFeeOrYield(true);
    return _amounts;
  }

  /**
   * @dev Return the amount of fee that's not collected.
   */
  function getPendingYieldAmount()
    internal
    view
    returns (uint256, uint256[] memory, uint256)
  {
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 oldD = totalSupply;

    for (uint256 i = 0; i < _balances.length; i++) {
      _balances[i] = IERC20Upgradeable(tokens[i]).balanceOf(address(this)).mul(
        precisions[i]
      );
    }
    uint256 newD = _getD(_balances, A);

    return (newD.sub(oldD), _balances, newD);
  }

  /**
   * @dev Collect fee or yield based on the token balance difference.
   */
  function collectFeeOrYield(bool isFee) internal returns (uint256) {
    uint256[] memory _balances = balances;
    uint256 A = getA();
    uint256 oldD = totalSupply;

    for (uint256 i = 0; i < _balances.length; i++) {
      _balances[i] = IERC20Upgradeable(tokens[i]).balanceOf(address(this)).mul(
        precisions[i]
      );
    }
    uint256 newD = _getD(_balances, A);
    if (isFee && newD < oldD) {
      return 0;
    }
    uint256 feeAmount = newD.sub(oldD);
    if (feeAmount == 0) {
      return 0;
    }

    balances = _balances;
    totalSupply = newD;

    if (isFee) {
      address recipient = feeRecipient;
      IERC20MintableBurnable(poolToken).mint(recipient, feeAmount);
      emit FeeCollected(recipient, feeAmount);
    } else {
      address recipient = yieldRecipient;
      IERC20MintableBurnable(poolToken).mint(recipient, feeAmount);
      emit YieldCollected(recipient, feeAmount);
    }
    return feeAmount;
  }

  /**
   * @dev Updates the govenance address.
   */
  function setGovernance(address _governance) external {
    require(msg.sender == governance, "not governance");
    governance = _governance;
  }

  /**
   * @dev Updates the mint fee.
   */
  function setMintFee(uint256 _mintFee) external {
    require(msg.sender == governance, "not governance");
    mintFee = _mintFee;
  }

  /**
   * @dev Updates the swap fee.
   */
  function setSwapFee(uint256 _swapFee) external {
    require(msg.sender == governance, "not governance");
    swapFee = _swapFee;
  }

  /**
   * @dev Updates the redeem fee.
   */
  function setRedeemFee(uint256 _redeemFee) external {
    require(msg.sender == governance, "not governance");
    redeemFee = _redeemFee;
  }

  /**
   * @dev Updates the recipient of mint/swap/redeem fees.
   */
  function setFeeRecipient(address _feeRecipient) external {
    require(msg.sender == governance, "not governance");
    require(_feeRecipient != address(0x0), "fee recipient not set");
    feeRecipient = _feeRecipient;
  }

  /**
   * @dev Updates the pool token.
   */
  function setPoolToken(address _poolToken) external {
    require(msg.sender == governance, "not governance");
    require(_poolToken != address(0x0), "pool token not set");
    poolToken = _poolToken;
  }

  /**
   * @dev Pause mint/swap/redeem actions. Can unpause later.
   */
  function pause() external {
    require(msg.sender == governance, "not governance");
    require(!paused, "paused");

    paused = true;
  }

  /**
   * @dev Unpause mint/swap/redeem actions.
   */
  function unpause() external {
    require(msg.sender == governance, "not governance");
    require(paused, "not paused");

    paused = false;
  }

  /**
   * @dev Updates the admin role for the address.
   * @param _account Address to update admin role.
   * @param _allowed Whether the address is granted the admin role.
   */
  function setAdmin(address _account, bool _allowed) external {
    require(msg.sender == governance, "not governance");
    require(_account != address(0x0), "account not set");

    admins[_account] = _allowed;
  }

  /**
   * @dev Pause update A value.
   */
  function updateA(uint256 _futureA, uint256 _futureABlock) external {
    require(msg.sender == governance, "not governance");
    require(futureABlock > block.number, "block in the past");
    initialA = getA();
    initialABlock = block.number;
    futureA = _futureA;
    futureABlock = _futureABlock;
  }

  /**
   * @dev Pause mint/swap/redeem actions. Can unpause later.
   */
  function approve(address _token, address _spender) external {
    require(msg.sender == governance, "not governance");

    IERC20Upgradeable(_token).safeApprove(_spender, 2 ** 256 - 1);
  }

  function getTokens() public view returns (address[] memory) {
    return tokens;
  }

  function getPoolToken() public view returns (address) {
    return poolToken;
  }
}
