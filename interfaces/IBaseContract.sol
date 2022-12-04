//SPDX-License-Identifier:MIT
pragma solidity 0.8.16;

interface IBaseControl {

    function startVerification() external;

    function submitVerificationData(
        address userAddress,
        uint256 borrowerCount, 
        string memory CID,
        uint256 applicationStage
    ) external;

    function updateLenderBorrowerInfo(
        address userAddress,
        uint256 borrowerCount,
        uint256 borrowedAmount,
        uint256 installmentAmount,
        uint256 totalAmountToBePaid,
        uint256 billCycle
    ) external;

    function activateLoan(
        uint256 borrowerCount, 
        bool isMutualTerms
    ) external;

    function payInstallments(
        uint256 borrowerCount, 
        address lenderAddress
    ) external;

    function closeLoan(
        address userAddress, 
        uint256 borrowerCount
    ) external;
}