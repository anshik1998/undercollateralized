//SPDX-License-Identifier:MIT
pragma solidity 0.8.16;

/// @title Subprime Loan Contract
/// @author Anshik Bansal <anshik@safezen.finance>

/// Importing the interface of our contract and ERCC20 token
import "./../interfaces/IBaseContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


error ActiveLoanError();
error LoanNotYetAcivatedError();
error NotRegisteredAsALenderError();
error LenderAlreadyRegisteredError();
error WrongLenderAddressInputError();
error WrongBorrowerCountEnteredError();
error EarlierApplicationPendingError();
error LenderAcceptanceOver100DAIError();

/////////////////////////////////

// Activate and approve are two different terms for us, 
// and have different meanings!

//////////////////////////////////

contract BaseContract is IBaseControl{
    uint256 counter;
    IERC20 tokenDAI;
    address public agentAddressKYC;
    
    struct BorrowInfo {
        string CID;
        address lender;
        bool isMutualTerms;
        bool isAmountRepaid;
        uint256 borrowedAmount;
        uint256 applicationStage;  // 1 - application in progress, 2- application successful, 403- application declined
        uint256 installmentAmount;
        mapping(uint256 => BillInfo) billInfo;
    }

    struct BillInfo {
        uint256 billCycle;
        uint256 repaymentDate;
        uint256 repaidAmountToDate;
        uint256 totalAmountToBePaid;
    }

    mapping(address => uint256) public lenders;
    mapping(address => uint256) public borrowCounter;
    mapping(address => mapping(uint256 => BorrowInfo)) public borrowers;

    modifier onlyKYCAgent() {
        require(msg.sender == agentAddressKYC);
        _;
    }

    event CallVerification(address indexed, uint256 indexed);

    constructor(address contractDAI, address _agentAddressKYC) {
        tokenDAI = IERC20(contractDAI);
        agentAddressKYC = _agentAddressKYC;
    }

    function startVerification() external override {
        uint256 oldBorrowerCount = borrowCounter[msg.sender];
        if (borrowers[msg.sender][oldBorrowerCount].applicationStage == 1) {
            revert EarlierApplicationPendingError();
        }
        ++borrowCounter[msg.sender];
        uint256 newBorrowerCount = borrowCounter[msg.sender];
        BorrowInfo storage borrowInfo = borrowers[msg.sender][newBorrowerCount];
        borrowInfo.applicationStage = 1;
        emit CallVerification(msg.sender, newBorrowerCount);
    } 

    function submitVerificationData(
        address userAddress,
        uint256 borrowerCount, 
        string memory CID,
        uint256 applicationStage
    ) external override onlyKYCAgent {
        BorrowInfo storage borrowInfo = borrowers[userAddress][borrowerCount];
        borrowInfo.CID = CID;
        borrowInfo.applicationStage = applicationStage;
    }
    
    function updateLenderBorrowerInfo(
        address userAddress,
        uint256 borrowerCount,
        uint256 borrowedAmount,
        uint256 installmentAmount,
        uint256 totalAmountToBePaid,
        uint256 billCycle
    ) external override {
        if (lenders[msg.sender] < 1) {
            revert NotRegisteredAsALenderError();
        }
        BorrowInfo storage borrowInfo = borrowers[userAddress][borrowerCount];
        if ((borrowInfo.isMutualTerms == true) || borrowInfo.lender != address(0)) {
            revert ActiveLoanError();
        }
        borrowInfo.borrowedAmount = borrowedAmount;
        borrowInfo.lender = msg.sender;
        borrowInfo.billInfo[borrowerCount].totalAmountToBePaid = totalAmountToBePaid;
        borrowInfo.installmentAmount = installmentAmount;
        borrowInfo.billInfo[borrowerCount].billCycle = billCycle > 0 ? borrowInfo.billInfo[borrowerCount].billCycle : billCycle;
        uint256 repaymentDate = borrowInfo.billInfo[borrowerCount].billCycle > 0 ? borrowInfo.billInfo[borrowerCount].billCycle : block.timestamp;
        borrowInfo.billInfo[borrowerCount].repaymentDate = borrowInfo.billInfo[borrowerCount].billCycle + repaymentDate;
    }

    error LenderAcceptanceAwaitedError();
    function activateLoan(uint256 borrowerCount, bool isMutualTerms) external override {
        BorrowInfo storage borrowInfo = borrowers[msg.sender][borrowerCount];
        if (borrowInfo.lender == address(0)) {
            revert LenderAcceptanceAwaitedError();
        }
        if (borrowInfo.isMutualTerms == true) {
            revert ActiveLoanError();
        }
        borrowInfo.isMutualTerms = isMutualTerms;
    }

    function payInstallments(uint256 borrowerCount, address lenderAddress) external override {
        uint256 borrowCount = borrowCounter[msg.sender];
        if (borrowCount < borrowerCount) {
            revert WrongBorrowerCountEnteredError();
        }
        BorrowInfo storage borrowInfo = borrowers[msg.sender][borrowerCount];
        if (borrowInfo.lender != lenderAddress) {
            revert WrongLenderAddressInputError();
        }
        uint256 installmentAmount = borrowInfo.installmentAmount;
        tokenDAI.transferFrom(msg.sender, lenderAddress, installmentAmount);
    }

    function closeLoan(address userAddress, uint256 borrowerCount) external override {
        uint256 borrowCount = borrowCounter[userAddress];
        if (borrowCount < borrowerCount) {
            revert WrongBorrowerCountEnteredError();
        }
        BorrowInfo storage borrowInfo = borrowers[userAddress][borrowerCount];
        if (borrowInfo.billInfo[borrowerCount].repaidAmountToDate == borrowInfo.billInfo[borrowerCount].totalAmountToBePaid) {
            borrowInfo.isAmountRepaid = true;
        }
    }

    function lenderRegistration() external {
        if (lenders[msg.sender] > 0) {
            revert LenderAlreadyRegisteredError();
        }
        if (tokenDAI.balanceOf(msg.sender) < 100 * 1e18) {
            revert LenderAcceptanceOver100DAIError();
        }
        ++counter;
        lenders[msg.sender] = counter;
    }

    function provideCapital(
        address lendersAddress, 
        uint256 borrowerCount, 
        address userAddress
    ) external {
        BorrowInfo storage borrowInfo = borrowers[userAddress][borrowerCount];
        if (borrowInfo.isMutualTerms == false) {
            revert LoanNotYetAcivatedError();
        }
        uint256 borrowedAmount = borrowInfo.borrowedAmount;
        tokenDAI.transferFrom(lendersAddress, userAddress, borrowedAmount);
    }
}