// Importing necessary modules and functions from Hardhat and Chai for testing
const {
  loadFixture,
  time,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Describing a test suite for the CollateralizedLoan contract
describe("CollateralizedLoan", function () {
  // A fixture to deploy the contract before each test. This helps in reducing code repetition.
  async function deployCollateralizedLoanFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    // Deploying the CollateralizedLoan contract and returning necessary variables
    collaterlizedLoan = await ethers.getContractFactory("CollateralizedLoan");
    // TODO: Complete the deployment setup
    const contract = await collaterlizedLoan.deploy();
    await contract.waitForDeployment();

    return { contract, owner, addr1, addr2 };
  }

  // Test suite for the loan request functionality
  describe("Loan Request", function () {
    it("Should let a borrower deposit collateral and request a loan", async function () {
      // Loading the fixture
      const { contract, addr1 } = await loadFixture(
        deployCollateralizedLoanFixture
      );

      const collateralAmount = ethers.parseEther("1");
      const interestRate = 5;
      const duration = 300;
      await expect(
        contract
          .connect(addr1)
          .depositCollateralAndRequestLoan(interestRate, duration, {
            value: collateralAmount,
          })
      )
        .to.emit(contract, "LoanRequested")
        .withArgs(
          addr1.address,
          ethers.parseEther("0.8"),
          interestRate,
          duration
        );
    });
  });

  // Test suite for funding a loan
  describe("Funding a Loan", function () {
    it("Allows a lender to fund a requested loan", async function () {
      // Loading the fixture
      const { contract, addr1, addr2 } = await loadFixture(
        deployCollateralizedLoanFixture
      );
      const collateralAmount = ethers.parseEther("1");
      await contract
        .connect(addr1)
        .depositCollateralAndRequestLoan(5, 300, { value: collateralAmount });

      const loanAmount = ethers.parseEther("0.8");
      await expect(contract.connect(addr2).fundLoan(1, { value: loanAmount }))
        .to.emit(contract, "LoanFunded")
        .withArgs(1, loanAmount, addr2.address, addr1.address);
    });
  });

  // Test suite for repaying a loan
  describe("Repaying a Loan", function () {
    it("Enables the borrower to repay the loan fully", async function () {
      // Loading the fixture
      const { contract, addr1, addr2 } = await loadFixture(
        deployCollateralizedLoanFixture
      );
      const collateralAmount = ethers.parseEther("1");
      await contract
        .connect(addr1)
        .depositCollateralAndRequestLoan(5, 300, { value: collateralAmount });
      await contract
        .connect(addr2)
        .fundLoan(1, { value: ethers.parseEther("0.8") });

      const repaymentAmount = ethers.parseEther("0.84"); // 0.8 + 5% interest
      await expect(
        contract.connect(addr1).repayLoan(1, { value: repaymentAmount })
      )
        .to.emit(contract, "LoanRepaid")
        .withArgs(1, repaymentAmount, addr2.address, addr1.address);
    });
  });

  // Test suite for claiming collateral
  describe("Claiming Collateral", function () {
    it("Permits the lender to claim collateral if the loan isn't repaid on time", async function () {
      // Loading the fixture
      const { contract, addr1, addr2 } = await loadFixture(
        deployCollateralizedLoanFixture
      );
      const collateralAmount = ethers.parseEther("1");
      await contract
        .connect(addr1)
        .depositCollateralAndRequestLoan(5, 300, { value: collateralAmount });
      await contract
        .connect(addr2)
        .fundLoan(1, { value: ethers.parseEther("0.8") });

      // Simulate passage of time
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");

      await expect(contract.connect(addr2).claimCollateral(1))
        .to.emit(contract, "LoanCollateralClaimed")
        .withArgs(1, addr1.address, addr2.address, collateralAmount);
    });
  });
});
