// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Collateralized Loan Contract
contract CollateralizedLoan {
    // Define the structure of a loan
    struct Loan {
        address borrower; // Address of the person requesting the loan
        address lender; // Address of the person funding the loan
        uint collateralAmount; // Amount of collateral provided by the borrower
        uint amount; // Amount of the loan
        uint interestRate; // Interest rate for the loan
        uint dueDate; // Timestamp when the loan is due
        bool isFunded; // Flag to indicate if the loan has been funded
        bool isRepaid; // Flag to indicate if the loan has been repaid
    }

    // Create a mapping to manage the loans
    // The key is the loan ID, and the value is the Loan struct
    mapping(uint => Loan) public loans;
    uint public nextLoanId; // Counter to keep track of the next loan ID

    // The percentage of collateral a borrower can receive for a loan
    // This means the loan amount will be 80% of the collateral value
    uint public collateralPercentage = 20;

    // Define events for loan lifecycle
    event LoanRequested(
        address indexed borrower,
        uint amount,
        uint interestRate,
        uint dueDate
    );
    event LoanFunded(
        uint loanId,
        uint amount,
        address lender,
        address borrower
    );
    event LoanRepaid(
        uint loanId,
        uint amount,
        address lender,
        address borrower
    );
    event LoanCollateralClaimed(
        uint loanId,
        address borrower,
        address lender,
        uint amount
    );

    // Modifiers for checking loan state
    modifier onlyLoanExists(uint loanId) {
        require(loans[loanId].amount > 0, "The loan does not exist");
        _;
    }
    modifier onlyLoanNotFunded(uint loanId) {
        require(!loans[loanId].isFunded, "The loan is already funded");
        _;
    }
    modifier onlyLoanFunded(uint loanId) {
        require(loans[loanId].isFunded, "The loan is not funded yet!");
        _;
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(
        uint _interestRate,
        uint _duration
    ) external payable {
        require(msg.value > 0, "Collateral must be bigger than zero");

        // Calculate loan amount as 80% of the collateral value
        uint loanAmount = msg.value -
            ((msg.value * collateralPercentage) / 100);

        // Increment loan ID and create new loan
        nextLoanId += 1;
        Loan memory userLoan = Loan({
            borrower: msg.sender,
            lender: address(0), // No lender yet
            collateralAmount: msg.value,
            amount: loanAmount,
            interestRate: _interestRate,
            dueDate: (block.timestamp + _duration),
            isFunded: false,
            isRepaid: false
        });
        loans[nextLoanId] = userLoan;

        // Emit event for loan request
        emit LoanRequested(msg.sender, loanAmount, _interestRate, _duration);
    }

    // Function to fund a loan
    function fundLoan(
        uint loanId
    ) external payable onlyLoanExists(loanId) onlyLoanNotFunded(loanId) {
        require(
            msg.value == loans[loanId].amount,
            "You should fund the user with proper value"
        );
        require(
            block.timestamp < loans[loanId].dueDate,
            "The dueDate is not valid anymore for this fund"
        );

        // Transfer funds to borrower
        (bool sent, ) = payable(loans[loanId].borrower).call{value: msg.value}(
            ""
        );
        require(sent, "Failed to send Ether for funding loan");

        // Update loan status
        loans[loanId].isFunded = true;
        loans[loanId].lender = msg.sender;

        emit LoanFunded(loanId, msg.value, msg.sender, loans[loanId].borrower);
    }

    // Function to repay a loan
    function repayLoan(
        uint loanId
    ) external payable onlyLoanExists(loanId) onlyLoanFunded(loanId) {
        require(!loans[loanId].isRepaid, "Loan already has been repaid.");

        // Calculate repayment amount (loan amount + interest)
        uint256 repaymentAmount = loans[loanId].amount +
            ((loans[loanId].amount * loans[loanId].interestRate) / 100);
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        // Transfer repayment to lender
        (bool sent, ) = payable(loans[loanId].lender).call{value: msg.value}(
            ""
        );
        require(sent, "Failed to send Ether for repaying loan");

        // Mark loan as repaid
        loans[loanId].isRepaid = true;

        emit LoanRepaid(
            loanId,
            repaymentAmount,
            loans[loanId].lender,
            msg.sender
        );
    }

    // Function to claim collateral on default
    function claimCollateral(
        uint loanId
    ) external payable onlyLoanExists(loanId) {
        require(
            loans[loanId].dueDate <= block.timestamp,
            "Due date has not been reached yet"
        );
        require(loans[loanId].isFunded, "Loan is not funded");
        require(!loans[loanId].isRepaid, "Loan is already repaid");
        require(
            msg.sender == loans[loanId].lender,
            "Only the lender can claim collateral"
        );

        // Transfer collateral to lender
        (bool sent, ) = address(loans[loanId].lender).call{
            value: loans[loanId].collateralAmount
        }("");
        require(sent, "Failed to send Ether for claiming collateral");

        emit LoanCollateralClaimed(
            loanId,
            loans[loanId].borrower,
            loans[loanId].lender,
            loans[loanId].collateralAmount
        );
    }
}
