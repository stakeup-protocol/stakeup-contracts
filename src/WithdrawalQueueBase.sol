// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract WithdrawalQueueBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev maximal length of the batch array provided for prefinalization. See `prefinalize()`
    uint256 public constant MAX_BATCHES_LENGTH = 36;

    /// @notice precision base for share rate
    uint256 internal constant E27_PRECISION_BASE = 1e27;
    /// @dev return value for the `find...` methods in case of no result
    uint256 internal constant NOT_FOUND = 0;

    /// @notice Underlying token
    IERC20 public immutable underlying;

    /// @dev queue for withdrawal requests, indexes (requestId) start from 1
    mapping(uint256 => WithdrawalRequest) internal _queue;
    /// @dev last index in request queue
    uint256 internal _lastRequestId;
    /// @dev last index of finalized request in the queue
    uint256 internal _lastFinalizedRequestId;
    /// @dev finalization rate history, indexes start from 1
    mapping(uint256 => uint256) internal _fromRequestIds;
    /// @dev last index in checkpoints array
    uint256 internal _lastCheckpointIndex;
    /// @dev amount of usd locked on contract for further claiming
    uint256 internal _lockedUsdAmount;
    /// @dev withdrawal requests mapped to the owners
    mapping(address => EnumerableSet.UintSet) internal _requestsByOwner;
    /// @dev timestamp of the last oracle report
    uint256 internal _lastReportTimestamp;

    /// @notice structure representing a request for withdrawal
    struct WithdrawalRequest {
        /// @notice sum of the all stUSD submitted for withdrawals including this request
        uint128 cumulativeStUSD;
        /// @notice sum of the all shares locked for withdrawal including this request
        uint128 cumulativeShares;
        /// @notice address that can claim or transfer the request
        address owner;
        /// @notice block.timestamp when the request was created
        uint40 timestamp;
        /// @notice flag if the request was claimed
        bool claimed;
        /// @notice timestamp of last oracle report for this request
        uint40 reportTimestamp;
    }

    /// @notice output format struct for `_getWithdrawalStatus()` method
    struct WithdrawalRequestStatus {
        /// @notice stUSD token amount that was locked on withdrawal queue for this request
        uint256 amountOfStUSD;
        /// @notice amount of stUSD shares locked on withdrawal queue for this request
        uint256 amountOfShares;
        /// @notice address that can claim or transfer this request
        address owner;
        /// @notice timestamp of when the request was created, in seconds
        uint256 timestamp;
        /// @notice true, if request is finalized
        bool isFinalized;
        /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
        bool isClaimed;
    }

    /// @dev Contains both stUSD token amount and its corresponding shares amount
    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed requestor,
        address indexed owner,
        uint256 amountOfStUSD,
        uint256 amountOfShares
    );
    event WithdrawalsFinalized(
        uint256 indexed from,
        uint256 indexed to,
        uint256 amountOfUSDLocked,
        uint256 sharesToBurn,
        uint256 timestamp
    );
    event WithdrawalClaimed(
        uint256 indexed requestId,
        address indexed owner,
        address indexed receiver,
        uint256 amountOfUSD
    );

    error ZeroAmountOfUSD();
    error ZeroTimestamp();
    error TooMuchUsdToFinalize(uint256 sent, uint256 maxExpected);
    error NotOwner(address _sender, address _owner);
    error InvalidRequestId(uint256 _requestId);
    error InvalidRequestIdRange(uint256 startId, uint256 endId);
    error InvalidState();
    error BatchesAreNotSorted();
    error EmptyBatches();
    error RequestNotFoundOrNotFinalized(uint256 _requestId);
    error NotEnoughUsd();
    error RequestAlreadyClaimed(uint256 _requestId);
    error InvalidHint(uint256 _hint);

    constructor(IERC20 _underlying) {
        underlying = _underlying;
    }

    /// @notice id of the last request
    ///  NB! requests are indexed from 1, so it returns 0 if there is no requests in the queue
    function getLastRequestId() public view returns (uint256) {
        return _lastRequestId;
    }

    /// @notice id of the last finalized request
    ///  NB! requests are indexed from 1, so it returns 0 if there is no finalized requests in the queue
    function getLastFinalizedRequestId() public view returns (uint256) {
        return _lastFinalizedRequestId;
    }

    /// @notice amount of USD on this contract balance that is locked for withdrawal and available to claim
    function getLockedUsdAmount() public view returns (uint256) {
        return _lockedUsdAmount;
    }

    /// @notice length of the checkpoint array. Last possible value for the hint.
    ///  NB! checkpoints are indexed from 1, so it returns 0 if there is no checkpoints
    function getLastCheckpointIndex() public view returns (uint256) {
        return _lastCheckpointIndex;
    }

    /// @notice return the number of unfinalized requests in the queue
    function unfinalizedRequestNumber() external view returns (uint256) {
        return getLastRequestId() - getLastFinalizedRequestId();
    }

    /// @notice Returns the amount of stUSD in the queue yet to be finalized
    function unfinalizedStUSD() external view returns (uint256) {
        return
            _queue[getLastRequestId()].cumulativeStUSD -
            _queue[getLastFinalizedRequestId()].cumulativeStUSD;
    }

    //
    // FINALIZATION FLOW
    //
    // Process when protocol is fixing the withdrawal request value and lock the required amount of USD.
    // The parameters that are required for finalization are:
    //  - id of the last request that can be finalized
    //  - the amount of usd that must be locked for these requests
    // To calculate the usd amount we'll need to know which requests in the queue will be finalized as nominal.
    // It's impossible to calculate without the unbounded
    // loop over the unfinalized part of the queue. So, we need to extract a part of the algorithm off-chain, bring the
    // result with oracle report and check it later and check the result later.
    // So, we came to this solution:
    // Off-chain
    // 1. Oracle iterates over the queue off-chain and calculate the id of the latest finalizable request
    // in the queue. Then it splits all the requests that will be finalized into batches the way,
    // And passes them in the report as the array of the ending ids of these batches. So it can be reconstructed like
    // `[lastFinalizedRequestId+1, batches[0]], [batches[0]+1, batches[1]] ... [batches[n-2], batches[n-1]]`
    // 2. Contract checks the validity of the batches on-chain and calculate the amount of usd required to
    //  finalize them. It can be done without unbounded loop using partial sums that are calculated on request enqueueing.
    // 3. Contract marks the request's as finalized and locks the usd for claiming.

    /// @notice transient state that is used to pass intermediate results between several `calculateFinalizationBatches`
    //   invocations
    struct BatchesCalculationState {
        /// @notice amount of usd available in the protocol that can be used to finalize withdrawal requests
        ///  Will decrease on each call and will be equal to the remainder when calculation is finished
        ///  Should be set before the first call
        uint256 remainingEthBudget;
        /// @notice flag that is set to `true` if returned state is final and `false` if more calls are required
        bool finished;
        /// @notice static array to store last request id in each batch
        uint256[MAX_BATCHES_LENGTH] batches;
        /// @notice length of the filled part of `batches` array
        uint256 batchesLength;
    }

    /// @notice Offchain view for the oracle daemon that calculates how many requests can be finalized within
    /// the given budget, time period and share rate limits. Returned requests are split into batches.
    /// @param _maxTimestamp max timestamp of the request that can be finalized
    /// @param _maxRequestsPerCall max request number that can be processed per call.
    /// @param _state structure that accumulates the state across multiple invocations to overcome gas limits.
    ///  To start calculation you should pass `state.remainingEthBudget` and `state.finished == false` and then invoke
    ///  the function with returned `state` until it returns a state with `finished` flag set
    /// @return state that is changing on each call and should be passed to the next call until `state.finished` is true
    function calculateFinalizationBatches(
        uint256 _maxTimestamp,
        uint256 _maxRequestsPerCall,
        BatchesCalculationState memory _state
    ) external view returns (BatchesCalculationState memory) {
        if (_state.finished || _state.remainingEthBudget == 0)
            revert InvalidState();

        uint256 currentId;
        WithdrawalRequest memory prevRequest;
        uint256 prevRequestShareRate;

        if (_state.batchesLength == 0) {
            currentId = getLastFinalizedRequestId() + 1;

            prevRequest = _queue[currentId - 1];
        } else {
            uint256 lastHandledRequestId = _state.batches[
                _state.batchesLength - 1
            ];
            currentId = lastHandledRequestId + 1;

            prevRequest = _queue[lastHandledRequestId];
            (prevRequestShareRate, , ) = _calcBatch(
                _queue[lastHandledRequestId - 1],
                prevRequest
            );
        }

        uint256 nextCallRequestId = currentId + _maxRequestsPerCall;
        uint256 queueLength = getLastRequestId() + 1;

        while (currentId < queueLength && currentId < nextCallRequestId) {
            WithdrawalRequest memory request = _queue[currentId];

            if (request.timestamp > _maxTimestamp) break; // max timestamp break

            (uint256 requestShareRate, uint256 usdToFinalize, ) = _calcBatch(
                prevRequest,
                request
            );

            if (usdToFinalize > _state.remainingEthBudget) break; // budget break
            _state.remainingEthBudget -= usdToFinalize;

            if (
                _state.batchesLength != 0 &&
                (// share rate of requests in the same batch can differ by 1-2 wei because of the rounding error
                // (issue: https://github.com/lidofinance/lido-dao/issues/442 )
                // so we're taking requests that are placed during the same report
                // as equal even if their actual share rate are different
                prevRequest.reportTimestamp == request.reportTimestamp)
            ) {
                _state.batches[_state.batchesLength - 1] = currentId; // extend the last batch
            } else {
                // to be able to check batches on-chain we need array to have limited length
                if (_state.batchesLength == MAX_BATCHES_LENGTH) break;

                // create a new batch
                _state.batches[_state.batchesLength] = currentId;
                ++_state.batchesLength;
            }

            prevRequestShareRate = requestShareRate;
            prevRequest = request;
            unchecked {
                ++currentId;
            }
        }

        _state.finished =
            currentId == queueLength ||
            currentId < nextCallRequestId;

        return _state;
    }

    /// @notice Checks finalization batches, calculates required usd and the amount of shares to burn
    /// @param _batches finalization batches calculated offchain using `calculateFinalizationBatches()`
    /// @return usdToLock amount of usd that should be sent with `finalize()` method
    /// @return sharesToBurn amount of shares that belongs to requests that will be finalized
    function prefinalize(
        uint256[] calldata _batches
    ) external view returns (uint256 usdToLock, uint256 sharesToBurn) {
        if (_batches.length == 0) revert EmptyBatches();

        if (_batches[0] <= getLastFinalizedRequestId())
            revert InvalidRequestId(_batches[0]);
        if (_batches[_batches.length - 1] > getLastRequestId())
            revert InvalidRequestId(_batches[_batches.length - 1]);

        uint256 currentBatchIndex;
        uint256 prevBatchEndRequestId = getLastFinalizedRequestId();
        WithdrawalRequest memory prevBatchEnd = _queue[prevBatchEndRequestId];
        while (currentBatchIndex < _batches.length) {
            uint256 batchEndRequestId = _batches[currentBatchIndex];
            if (batchEndRequestId <= prevBatchEndRequestId)
                revert BatchesAreNotSorted();

            WithdrawalRequest memory batchEnd = _queue[batchEndRequestId];

            (, uint256 stUSD, uint256 shares) = _calcBatch(
                prevBatchEnd,
                batchEnd
            );

            usdToLock += stUSD;
            sharesToBurn += shares;

            prevBatchEndRequestId = batchEndRequestId;
            prevBatchEnd = batchEnd;
            unchecked {
                ++currentBatchIndex;
            }
        }
    }

    /// @dev Finalize requests in the queue
    ///  Emits WithdrawalsFinalized event.
    function _finalize(
        uint256 _lastRequestIdToBeFinalized,
        uint256 _amountOfUSD
    ) internal {
        if (_lastRequestIdToBeFinalized > getLastRequestId())
            revert InvalidRequestId(_lastRequestIdToBeFinalized);
        uint256 lastFinalizedRequestId = getLastFinalizedRequestId();
        if (_lastRequestIdToBeFinalized <= lastFinalizedRequestId)
            revert InvalidRequestId(_lastRequestIdToBeFinalized);

        WithdrawalRequest memory lastFinalizedRequest = _queue[
            lastFinalizedRequestId
        ];
        WithdrawalRequest memory requestToFinalize = _queue[
            _lastRequestIdToBeFinalized
        ];

        uint128 stUSDToFinalize = requestToFinalize.cumulativeStUSD -
            lastFinalizedRequest.cumulativeStUSD;
        if (_amountOfUSD > stUSDToFinalize)
            revert TooMuchUsdToFinalize(_amountOfUSD, stUSDToFinalize);

        uint256 firstRequestIdToFinalize = lastFinalizedRequestId + 1;
        uint256 lastCheckpointIndex = getLastCheckpointIndex();

        // add a new checkpoint with current finalization max share rate
        _fromRequestIds[lastCheckpointIndex + 1] = firstRequestIdToFinalize;
        _setLastCheckpointIndex(lastCheckpointIndex + 1);

        _setLockedUsdAmount(getLockedUsdAmount() + _amountOfUSD);
        _setLastFinalizedRequestId(_lastRequestIdToBeFinalized);

        emit WithdrawalsFinalized(
            firstRequestIdToFinalize,
            _lastRequestIdToBeFinalized,
            _amountOfUSD,
            requestToFinalize.cumulativeShares -
                lastFinalizedRequest.cumulativeShares,
            block.timestamp
        );
    }

    /// @dev creates a new `WithdrawalRequest` in the queue
    ///  Emits WithdrawalRequested event
    function _enqueue(
        uint128 _amountOfStUSD,
        uint128 _amountOfShares,
        address _owner
    ) internal returns (uint256 requestId) {
        uint256 lastRequestId = getLastRequestId();
        WithdrawalRequest memory lastRequest = _queue[lastRequestId];

        uint128 cumulativeShares = lastRequest.cumulativeShares +
            _amountOfShares;
        uint128 cumulativeStUSD = lastRequest.cumulativeStUSD + _amountOfStUSD;

        requestId = lastRequestId + 1;

        _setLastRequestId(requestId);

        WithdrawalRequest memory newRequest = WithdrawalRequest(
            cumulativeStUSD,
            cumulativeShares,
            _owner,
            uint40(block.timestamp),
            false,
            uint40(_getLastReportTimestamp())
        );
        _queue[requestId] = newRequest;
        assert(_requestsByOwner[_owner].add(requestId));

        emit WithdrawalRequested(
            requestId,
            msg.sender,
            _owner,
            _amountOfStUSD,
            _amountOfShares
        );
    }

    /// @dev Returns the status of the withdrawal request with `_requestId` id
    function _getStatus(
        uint256 _requestId
    ) internal view returns (WithdrawalRequestStatus memory status) {
        if (_requestId == 0 || _requestId > getLastRequestId())
            revert InvalidRequestId(_requestId);

        WithdrawalRequest memory request = _queue[_requestId];
        WithdrawalRequest memory previousRequest = _queue[_requestId - 1];

        status = WithdrawalRequestStatus(
            request.cumulativeStUSD - previousRequest.cumulativeStUSD,
            request.cumulativeShares - previousRequest.cumulativeShares,
            request.owner,
            request.timestamp,
            _requestId <= getLastFinalizedRequestId(),
            request.claimed
        );
    }

    /// @dev View function to find a checkpoint hint to use in `claimWithdrawal()` and `getClaimableUsd()`
    ///  Search will be performed in the range of `[_firstIndex, _lastIndex]`
    ///
    /// @param _requestId request id to search the checkpoint for
    /// @param _start index of the left boundary of the search range, should be greater than 0
    /// @param _end index of the right boundary of the search range, should be less than or equal
    ///  to `getLastCheckpointIndex()`
    ///
    /// @return hint for later use in other methods or 0 if hint not found in the range
    function _findCheckpointHint(
        uint256 _requestId,
        uint256 _start,
        uint256 _end
    ) internal view returns (uint256) {
        if (_requestId == 0 || _requestId > getLastRequestId())
            revert InvalidRequestId(_requestId);

        uint256 lastCheckpointIndex = getLastCheckpointIndex();
        if (_start == 0 || _end > lastCheckpointIndex)
            revert InvalidRequestIdRange(_start, _end);

        if (
            lastCheckpointIndex == 0 ||
            _requestId > getLastFinalizedRequestId() ||
            _start > _end
        ) return NOT_FOUND;

        // Right boundary
        if (_requestId >= _fromRequestIds[_end]) {
            // it's the last checkpoint, so it's valid
            if (_end == lastCheckpointIndex) return _end;
            // it fits right before the next checkpoint
            if (_requestId < _fromRequestIds[_end + 1]) return _end;

            return NOT_FOUND;
        }
        // Left boundary
        if (_requestId < _fromRequestIds[_start]) {
            return NOT_FOUND;
        }

        // Binary search
        uint256 min = _start;
        uint256 max = _end - 1;

        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (_fromRequestIds[mid] <= _requestId) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /// @dev Claim the request and transfer locked usd to `_recipient`.
    ///  Emits WithdrawalClaimed event
    /// @param _requestId id of the request to claim
    /// @param _hint hint the checkpoint to use. Can be obtained by calling `findCheckpointHint()`
    /// @param _recipient address to send usd to
    function _claim(
        uint256 _requestId,
        uint256 _hint,
        address _recipient
    ) internal {
        if (_requestId == 0) revert InvalidRequestId(_requestId);
        if (_requestId > getLastFinalizedRequestId())
            revert RequestNotFoundOrNotFinalized(_requestId);

        WithdrawalRequest storage request = _queue[_requestId];

        if (request.claimed) revert RequestAlreadyClaimed(_requestId);
        if (request.owner != msg.sender)
            revert NotOwner(msg.sender, request.owner);

        request.claimed = true;
        assert(_requestsByOwner[request.owner].remove(_requestId));

        uint256 usd = _calculateClaimableUsd(request, _requestId, _hint);
        // because of the stUSD rounding issue
        // (issue: https://github.com/lidofinance/lido-dao/issues/442 )
        // some dust (1-2 wei per request) will be accumulated upon claiming
        _setLockedUsdAmount(getLockedUsdAmount() - usd);
        _transferUnderlying(_recipient, usd);

        emit WithdrawalClaimed(_requestId, msg.sender, _recipient, usd);
    }

    /// @dev Calculates usd value for the request using the provided hint. Checks if hint is valid
    /// @return claimableUsd usd for `_requestId`
    function _calculateClaimableUsd(
        WithdrawalRequest storage _request,
        uint256 _requestId,
        uint256 _hint
    ) internal view returns (uint256 claimableUsd) {
        if (_hint == 0) revert InvalidHint(_hint);

        uint256 lastCheckpointIndex = getLastCheckpointIndex();
        if (_hint > lastCheckpointIndex) revert InvalidHint(_hint);

        uint256 fromRequestId = _fromRequestIds[_hint];
        // Reverts if requestId is not in range [fromRequestIds[hint], fromRequestIds[hint+1])
        // ______(>______
        //    ^  hint
        if (_requestId < fromRequestId) revert InvalidHint(_hint);
        if (_hint < lastCheckpointIndex) {
            // ______(>______(>________
            //       hint    hint+1  ^
            uint256 nextFromRequestId = _fromRequestIds[_hint + 1];
            if (nextFromRequestId <= _requestId) revert InvalidHint(_hint);
        }

        WithdrawalRequest memory prevRequest = _queue[_requestId - 1];
        (, uint256 usd, ) = _calcBatch(prevRequest, _request);

        return usd;
    }

    /// @dev quazi-constructor
    function _initializeQueue() internal {
        // setting dummy zero structs in checkpoints and queue beginning
        // to avoid uint underflows and related if-branches
        // 0-index is reserved as 'not_found' response in the interface everywhere
        _queue[0] = WithdrawalRequest(
            0,
            0,
            address(0),
            uint40(block.timestamp),
            true,
            0
        );
        _fromRequestIds[getLastCheckpointIndex()] = 0;
    }

    function _transferUnderlying(address _recipient, uint256 _amount) internal {
        if (underlying.balanceOf(address(this)) < _amount)
            revert NotEnoughUsd();

        underlying.safeTransfer(_recipient, _amount);
    }

    /// @dev calculate batch stats (shareRate, stUSD and shares) for the range of `(_preStartRequest, _endRequest]`
    function _calcBatch(
        WithdrawalRequest memory _preStartRequest,
        WithdrawalRequest memory _endRequest
    ) internal pure returns (uint256 shareRate, uint256 stUSD, uint256 shares) {
        stUSD = _endRequest.cumulativeStUSD - _preStartRequest.cumulativeStUSD;
        shares =
            _endRequest.cumulativeShares -
            _preStartRequest.cumulativeShares;

        shareRate = (stUSD * E27_PRECISION_BASE) / shares;
    }

    function _getLastReportTimestamp() internal view returns (uint256) {
        return _lastReportTimestamp;
    }

    function _setLastRequestId(uint256 __lastRequestId) internal {
        _lastRequestId = __lastRequestId;
    }

    function _setLastFinalizedRequestId(
        uint256 __lastFinalizedRequestId
    ) internal {
        _lastFinalizedRequestId = __lastFinalizedRequestId;
    }

    function _setLastCheckpointIndex(uint256 __lastCheckpointIndex) internal {
        _lastCheckpointIndex = __lastCheckpointIndex;
    }

    function _setLockedUsdAmount(uint256 __lockedUsdAmount) internal {
        _lockedUsdAmount = __lockedUsdAmount;
    }

    function _setLastReportTimestamp(uint256 __lastReportTimestamp) internal {
        _lastReportTimestamp = __lastReportTimestamp;
    }
}
