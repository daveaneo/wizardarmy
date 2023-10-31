const { expect } = require("chai");
const { ethers } = require("hardhat");

const advanceTime = async (seconds) => {
    await network.provider.send("evm_increaseTime", [seconds])
    await ethers.provider.send("evm_mine");
};

async function getBlockTimestamp() {
    // Get the latest block number
    const blockNumber = await ethers.provider.getBlockNumber();

    // Get the block details using the block number
    const block = await ethers.provider.getBlock(blockNumber);

    // Return the timestamp of the latest block
    return block.timestamp;
}


describe("WizardTower", function() {
  let WizardTower, wizardTower, owner, addr1, addr2;
  let token, wizards, deploymentTimeWizardTower;

    let initialContractSettings = {
        mintCost: 5,
        initiationCost: 10,
        maxSupply: 8192,
        maxActiveWizards: 8192,
        protectionTimeExtension: 86400, // 1 day in seconds
        exileTimePenalty: 2592000,      // 30 days in seconds
        ecosystemTokenAddress: "_ERC20Address", // replace with actual address or variable
        phaseDuration: 3600,           // 60 minutes in seconds
        totalPhases: 8,
        maturityThreshold: 4,
        imageBaseURI: "https://raw.githubusercontent.com/daveaneo/wizardarmy/master/token/wizard_army_pinata",
        wizardSaltSet: false
    };


  beforeEach(async function() {
    // ... code to deploy your token, wizardsNFT and WizardTower contracts

    // Assign roles
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();



    // Deploying the CommonDefinitions Library
    const CommonDefinitions = await ethers.getContractFactory("CommonDefinitions");
    const commonDefinitions = await CommonDefinitions.deploy();

    // Deploying the GeneLogic Library
    const GeneLogic = await ethers.getContractFactory("GeneLogic");
    const geneLogic = await GeneLogic.deploy();

    // Link the GeneLogic library to the SVGGenerator and deploy
    const SVGGenerator = await ethers.getContractFactory("SVGGenerator", {
      libraries: {
        "GeneLogic": geneLogic.address,
      },
    });
    const svgGenerator = await SVGGenerator.deploy();

    // Deploying the TokenURILibrary
    const TokenURILibrary = await ethers.getContractFactory("TokenURILibrary", {
      libraries: {
        "GeneLogic": geneLogic.address,
        "SVGGenerator": svgGenerator.address,
      },
    });
    const tokenURILibrary = await TokenURILibrary.deploy();

    // Deploying the Token
    Token = await ethers.getContractFactory("Token");
    token = await Token.deploy("Wizard Gold", "WGLD", 18, ethers.utils.parseEther("1000"));


    // Deploying the Wizards Contract
    Wizards = await ethers.getContractFactory("Wizards", {
      libraries: {
        "TokenURILibrary": tokenURILibrary.address,
      },
    });
    wizards = await Wizards.deploy("Wizards", "WZD", token.address, "https://gateway.pinata.cloud/ipfs/");


    // Deploy the WizardTower
    WizardTower = await ethers.getContractFactory("WizardTower");
    wizardTower = await WizardTower.deploy(token.address, wizards.address);
    await wizardTower.deployed();

    // get timestampe of deployment
    deploymentTimeWizardTower = await getBlockTimestamp();


    // mint 3 wizards, initatiate first 2
    await wizards.connect(addr1).mint(0); // wizid 1
    await wizards.connect(addr1).initiate(1, {value: initialContractSettings.initiationCost});
    await wizards.connect(owner).increaseProtectedUntilTimestamp(1, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

    await wizards.connect(addr2).mint(1); // wizid 2
    await wizards.connect(addr2).initiate(2, {value: initialContractSettings.initiationCost});
    await wizards.connect(owner).increaseProtectedUntilTimestamp(2, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

    await wizards.connect(addr3).mint(2);

    // advance time until wizards are mature
    await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

  });

    describe("Initialization and Setup", function() {
        it("should set the correct token address", async function() {
            expect(await wizardTower.token()).to.equal(token.address, "WizardTower token address mismatch");
        });

        it("should set the correct wizardsNFT address", async function() {
            expect(await wizardTower.wizardsNFT()).to.equal(wizards.address, "WizardTower wizardsNFT address mismatch");
        });

        it("should start 0 for totalPowerSnapshot", async function() {
            expect(await wizardTower.totalPowerSnapshotTimestamp()).to.equal(deploymentTimeWizardTower, "Initial totalPowerSnapshotTimestamp should be time of deployment");
        });

        it("should have owner as eviction proceeds receiver", async function() {
            let currentContractSettings = await wizardTower.contractSettings();
            expect(await currentContractSettings.evictionProceedsReceiver).to.equal(owner.address, "Owner should be the eviction proceeds receiver initially");
        });

        it("should have owner as evictor", async function() {
            let currentContractSettings = await wizardTower.contractSettings();
            expect(await currentContractSettings.evictor).to.equal(owner.address, "Owner should be the eviction proceeds receiver initially");
        });

        it("should start with 0 active floors", async function() {
            let currentContractSettings = await wizardTower.contractSettings();
            expect(await currentContractSettings.activeFloors).to.equal(0, "Initial active floors should be 0");
        });

        it("should have an initial balance of 0 tokens", async function() {
            expect(await token.balanceOf(wizardTower.address)).to.equal(0, "Initial WizardTower token balance should be 0");
        });
    }); // end Initialization and Setup


    describe("Claiming Floors", function() {

        it("should allow a mature, initiated wizard to claim a floor", async function() {
            await wizardTower.connect(addr1).claimFloor(1);
            expect(await wizardTower.isOnTheTower(1)).to.be.true, "A mature, initiated wizard should be able to claim a floor";
        });

        it("should not allow an uninitiated wizard to claim a floor", async function() {
            await expect(wizardTower.connect(addr3).claimFloor(3)).to.be.reverted, "An uninitiated wizard should not be able to claim a floor";
        });

        it("should not allow a non-mature wizard to claim a floor", async function() {
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            const isActive = await wizards.isActive(3);
            expect(isActive).to.be.true, "Wizard 3 should be active";

            const isMature = await wizards.isMature(3);
            expect(isMature).to.be.false, "Wizard 3 should not be mature";

            await expect(wizardTower.connect(addr3).claimFloor(3)).to.be.reverted, "A non-mature wizard should not be able to claim a floor";
        });

        // Assuming you have a function to get the active status of a wizard, let's say `isActive`
        it("should not allow an inactive wizard to claim a floor", async function() {
            const isActive = await wizards.isActive(3);
            expect(isActive).to.be.false, "Wizard 3 should be inactive";

            await expect(wizardTower.connect(addr3).claimFloor(3)).to.be.reverted, "An inactive wizard should not be able to claim a floor";
        });

        // Assuming you have a function to get the exile status of a wizard, let's say `isExiled`
        it("should not allow an exiled wizard to claim a floor", async function() {
            // For the sake of demonstration, let's assume wizardId 5 is exiled.
            await wizards.connect(owner).cull(1);

            const isExiled = await wizards.isExiled(1);
            expect(isExiled).to.be.true, "Wizard 1 should be exiled";

            await expect(wizardTower.connect(addr1).claimFloor(1)).to.be.reverted, "An exiled wizard should not be able to claim a floor";
        });

        it("should not allow an invalid wizard to claim a floor", async function() {
            // For the sake of demonstration, let's assume wizardId 9999 is invalid.
            await expect(wizardTower.connect(addr1).claimFloor(9999)).to.be.reverted, "An invalid wizard should not be able to claim a floor";
        });

        it("should not allow a wizard to claim a floor more than once", async function() {
            await wizardTower.connect(addr1).claimFloor(1);
            await expect(wizardTower.connect(addr1).claimFloor(1)).to.be.reverted, "A wizard should not be able to claim a floor more than once";
        });


        it("should show correct floor info for a claimed wizard", async function() {

            await wizardTower.connect(addr1).claimFloor(1);
            let ts = await getBlockTimestamp();

            const floorInfo = await wizardTower.getFloorInfoGivenWizard(1);
            expect(floorInfo.lastWithdrawalTimestamp).to.be.equal(ts, "should equal time of claim");
        });

    }); // end Claiming Floors

    describe("Eviction", function() {

        beforeEach(async function() {
            // Transfer 10**18 tokens to the wizardTower contract
            await token.transfer(wizardTower.address, ethers.utils.parseEther("1"));

            // Wizard 1 and 2 claim a floor
            await wizardTower.connect(addr1).claimFloor(1);
            await wizardTower.connect(addr2).claimFloor(2);
        });

        it("should allow evictor to evict a valid wizard", async function() {
            await wizardTower.connect(owner).evict(1);
            expect(await wizardTower.isOnTheTower(1)).to.be.false, "Evicted wizard should not be on the tower";
        });

        it("should not allow non-evictor to evict a valid wizard", async function() {
            await expect(wizardTower.connect(addrs[0]).evict(1)).to.be.reverted, "Non-evictor can not evict";
        });


        it("should emit the correct event when a wizard is evicted", async function() {
            await expect(wizardTower.connect(owner).evict(1))
                .to.emit(wizardTower, 'WizardEvicted')
                .withArgs(1);
        });

        it("should not allow the owner to evict an invalid wizard", async function() {
            await expect(wizardTower.connect(owner).evict(9999)).to.be.reverted, "Evicting an invalid wizard should revert";
        });

        it("should send eviction proceeds to the designated receiver if above dust threshold", async function() {
            // owner will be benefactor, evictor will be evictor
            const evictor = addrs[0];
            await wizardTower.updateEvictor(evictor.address);
            const prevBalance = await token.balanceOf(owner.address);
            await wizardTower.connect(evictor).evict(1);
            const newBalance = await token.balanceOf(owner.address);

            console.log("bal before and after:");
            console.log(prevBalance.toString());
            console.log(newBalance.toString());

            expect(newBalance.sub(prevBalance)).to.be.equal(ethers.utils.parseEther("0.5")), "Eviction proceeds receiver should receive half the tokens since there are two wizards on the tower";
        });

        // More tests for checking the balance before and after eviction if below dust threshold...

    }); // end Eviction

    describe("Floor Balance", function() {

        let initialTowerBalance;

        // notes
        // wizards need to be mature for 1 month. That means they are unpaid and active wizards receive their payment
        // todo -- in order to increaseTime, you must pay. This is handled in the wizardsSmartContract??
        // what if wizardToewr migrates or has issues?

        beforeEach(async function() {
            // Transfer 10**18 tokens to the wizardTower contract
            initialTowerBalance = ethers.utils.parseEther("1");
            await token.transfer(wizardTower.address, initialTowerBalance);

            // Wizard 1 and 2 claim a floor
            await wizardTower.connect(addr1).claimFloor(1);
            await wizardTower.connect(addr2).claimFloor(2);
        });

        it("should return correct balance for a given floor", async function() {
            await advanceTime(100);

            const balance = await wizardTower.floorBalance(1);
            // some time has passed, so balance should be non-zero
            expect(balance).to.be.gt(0).and.to.be.lte(initialTowerBalance), "Balance for a claimed floor should be greater than zero and less than or equal to initial tower balance";
        });

        it("total floor balance increases over time -- before rewardReleasePeriod ends", async function() {
            const contractSettings = await wizardTower.contractSettings();

            // advance time until wizards are mature
            let initBalance = await wizardTower.connect(addrs[0]).netAvailableBalance();

            // advance more time
            await advanceTime(contractSettings.rewardReleasePeriod/2);
            let finalBalance = await wizardTower.connect(addrs[0]).netAvailableBalance();

            expect(initBalance).to.be.lt(finalBalance), "final balance should increase";
        });

        it("total floor balance at max after waiting period", async function() {
            const contractSettings = await wizardTower.contractSettings();

            // advance time until wizards are mature
            await advanceTime(contractSettings.rewardReleasePeriod);
            let initBalance = await wizardTower.connect(addrs[0]).netAvailableBalance();

            // advance more time
            await advanceTime(contractSettings.rewardReleasePeriod);
            let finalBalance = await wizardTower.connect(addrs[0]).netAvailableBalance();

            expect(initBalance).to.be.equal(finalBalance), "balance should not increase after rewardReleasePeriod --without updates";
        });

        // withdraw recalculates timestamp correctly

        it("floor balance should be 0 immediately after claiming", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity)
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            // advance time until wizards are mature
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

            await wizardTower.connect(addr3).claimFloor(3);
            const balance = await wizardTower.floorBalance(3);
            expect(balance).to.be.equal(0), "Initial balance should be 0";
        });


        it("adding more wizards to tower does not decrease existing wizards balance", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity)
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            // advance time until wizards are mature
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

            const initBalOne = await wizardTower.floorBalance(1);
            await wizardTower.connect(addr3).claimFloor(3);
            const finalBalOne = await wizardTower.floorBalance(1);

            expect(finalBalOne).to.be.gte(initBalOne), "Balance of other wizards should increase";
        });

        it("adding more wizards to tower decreases rate for existing wizards", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity)
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            // advance time until wizards are mature

            // get initial rate before adding new wizard
            let initBalOne = await wizardTower.floorBalance(1);
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            let finalBalOne = await wizardTower.floorBalance(1);
            const initRateOne = (finalBalOne.sub(initBalOne).div(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold))


            // add new wizard
            await wizardTower.connect(addr3).claimFloor(3);

            // get new rate after adding new wizard
            initBalOne = await wizardTower.floorBalance(1);
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            finalBalOne = await wizardTower.floorBalance(1);
            finalRateOne = (finalBalOne.sub(initBalOne).div(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold))

            expect(finalRateOne).to.be.lt(initRateOne), "Reward rate should decrease";
        });

        it("adding one wizard w/ contribution keeps rates same", async function() {
            expect(0).to.be.equal(1), "Test not implemented.";
        });


        it("adding one wizard w/o contribution from two to tower changes reward rate to 2/3", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity)
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            // advance time until wizards are mature
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

            // get initial rate before adding new wizard
            let initBalOne = await wizardTower.floorBalance(1);
            await advanceTime(36000);
            let finalBalOne = await wizardTower.floorBalance(1);
            const initRateOne = (finalBalOne.sub(initBalOne).div(36000))


            console.log('initBalOne:')
            console.log(initBalOne.toString())
            console.log('finalBalOne:')
            console.log(finalBalOne.toString())
            console.log('diff:')
            console.log(finalBalOne.sub(initBalOne).toString())
            console.log('initRateOne:')
            console.log(initRateOne.toString())


            // add new wizard
            await wizardTower.connect(addr3).claimFloor(3);

            // get new rate after adding new wizard
            initBalOne = await wizardTower.floorBalance(1);
            await advanceTime(36000);
            finalBalOne = await wizardTower.floorBalance(1);
            const finalRateOne = (finalBalOne.sub(initBalOne).div(36000))


            console.log('initBalOne:')
            console.log(initBalOne.toString())
            console.log('finalBalOne:')
            console.log(finalBalOne.toString())
            console.log('diff:')
            console.log(finalBalOne.sub(initBalOne).toString())
            console.log('finalRateOne:')
            console.log(finalRateOne.toString())


            expect(finalRateOne).to.be.equal(initRateOne.mul(2).div(3)), "Reward rate should 2/3 of initial rate";
        });


        it("claiming floor doesn't decrease values of other floors", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity),
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

            // get balances
            const initBalOne = await wizardTower.floorBalance(1);
            const initBalTwo = await wizardTower.floorBalance(2);

            // get on tower
            await wizardTower.connect(addr3).claimFloor(3);

            const finalBalOne = await wizardTower.floorBalance(1);
            const finalBalTwo = await wizardTower.floorBalance(2);

            expect(finalBalOne).to.be.at.least(initBalOne), "Balance should not decrease";
            expect(finalBalTwo).to.be.at.least(initBalTwo), "Balance should not decrease";
        });


        it("all floors increase in value equally with time", async function() {
            // initialize wizard and give him extra protection (equal to needed time for maturity),
            await wizards.connect(addr3).initiate(3, {value: initialContractSettings.initiationCost});
            await wizards.connect(owner).increaseProtectedUntilTimestamp(3, initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);
            // get on tower
            await wizardTower.connect(addr3).claimFloor(3);

            const initBalOne = await wizardTower.floorBalance(1);
            const initBalTwo = await wizardTower.floorBalance(2);
            const initBalThree = await wizardTower.floorBalance(3);


            // advance time until wizards are mature
            await advanceTime(initialContractSettings.phaseDuration * initialContractSettings.maturityThreshold);

            const finalBalOne = await wizardTower.floorBalance(1);
            const finalBalTwo = await wizardTower.floorBalance(2);
            const finalBalThree = await wizardTower.floorBalance(3);

            console.log("**************************************");

            console.log(`Initial Balances:`);
            console.log(`Floor 1: ${ethers.utils.formatEther(initBalOne.toString())} tokens`);
            console.log(`Floor 2: ${ethers.utils.formatEther(initBalTwo.toString())} tokens`);
            console.log(`Floor 3: ${ethers.utils.formatEther(initBalThree.toString())} tokens`);

            console.log(`\nFinal Balances:`);
            console.log(`Floor 1: ${ethers.utils.formatEther(finalBalOne.toString())} tokens`);
            console.log(`Floor 2: ${ethers.utils.formatEther(finalBalTwo.toString())} tokens`);
            console.log(`Floor 3: ${ethers.utils.formatEther(finalBalThree.toString())} tokens`);



            console.log(`\nDifferentials:`);
            console.log(`Floor 1: ${ethers.utils.formatEther(finalBalOne.sub(initBalOne).toString())} tokens`);
            console.log(`Floor 2: ${ethers.utils.formatEther(finalBalTwo.sub(initBalTwo).toString())} tokens`);
            console.log(`Floor 3: ${ethers.utils.formatEther(finalBalThree.sub(initBalThree).toString())} tokens`);


            expect(finalBalOne.sub(initBalOne)).to.be.equal(finalBalTwo.sub(initBalTwo)), "Balances should grow at same rate, r(1)==r(2)";
            expect(finalBalOne.sub(initBalOne)).to.be.equal(finalBalThree.sub(initBalThree)), "Balances should grow at same rate, r(1)==r(3)";
        });



        it("wizard should have equal share after a long time.", async function() {
            await advanceTime(100000000000);
            const balance = await wizardTower.floorBalance(1);
            expect(balance).to.be.gt(0).and.to.be.lte(initialTowerBalance), "Balance for a claimed floor should be greater than zero and less than or equal to initial tower balance";
        });


        it("should return 0 for invalid floors", async function() {
            expect(await wizardTower.floorBalance(9999)).to.be.equal(0), "Querying balance of an invalid floor should return 0"; // changed from revert
        });

        // This test may need specific conditions or simulation to validate the calculation's accuracy
        it("sum of floor balances should equal total tower balance after rewardReleasePeriod", async function() {
            // advance time until wizards are mature
            const contractSettings = await wizardTower.contractSettings();
            await advanceTime(contractSettings.rewardReleasePeriod + 1);

            // get balances
            const floor1Balance = await wizardTower.floorBalance(1);
            const floor2Balance = await wizardTower.floorBalance(2);
            expect(floor1Balance.add(floor2Balance)).to.be.closeTo(initialTowerBalance, 10), "Sum of floor balances should equal initial tower balance";
            expect(floor2Balance).to.be.lt(floor1Balance), "Second flor balance should be slightly less than first floor";
        });

        it("floor power increases over time", async function() {
            const initialPower = await wizardTower.floorPower(1);
            const timeToAdvance = 3600;
            await advanceTime(timeToAdvance); // Advance time by 1 hour
            const newPower = await wizardTower.floorPower(1);
            expect(newPower).to.be.gt(initialPower), "Balance should grow over time";
            expect(initialPower).to.be.equal(1), "power increases with time 1:1";
            expect(newPower).to.be.closeTo(timeToAdvance+1, 2), "power increases with time 1:1";
        });

        it("totalFloorPower increases over time", async function() {
            const initialPower = await wizardTower.totalFloorPower();
            const timeToAdvance = 3600;
            await advanceTime(timeToAdvance); // Advance time by 1 hour
            const newPower = await wizardTower.totalFloorPower();

            expect(newPower).to.be.gt(initialPower), "Balance should grow over time";
            expect(initialPower).to.be.equal(1), "power increases with time 1:1";
            expect(newPower).to.be.equal(timeToAdvance*2 + 1), "power increases with time 1:1";
        });


        it("balance should increase over time", async function() {
            const initialBalance = await wizardTower.floorBalance(1);
            await advanceTime(3600); // Advance time by 1 hour
            const newBalance = await wizardTower.floorBalance(1);
            console.log("initial, newbalance");
            console.log(initialBalance.toString());
            console.log(newBalance.toString());

            expect(newBalance).to.be.gt(initialBalance), "Balance should grow over time";
        });

        it("should update balance after withdrawals", async function() {
            await advanceTime(3600); // Advance time by 1 hour
            const initialBalance = await wizardTower.floorBalance(1);
            await wizardTower.connect(addr1).withdraw(1);
            const postWithdrawBalance = await wizardTower.floorBalance(1);
            expect(postWithdrawBalance).to.be.lt(initialBalance), "Balance should decrease after withdrawal";
        });

        // This assumes eviction affects the balance, if not, you can modify/remove
        it("should update balance after evictions", async function() {
            const evictor = addrs[0];
            await wizardTower.updateEvictor(evictor.address);

            const initialBalance = await wizardTower.floorBalance(1);
            await wizardTower.connect(evictor).evict(1);
            const postEvictionBalance = await wizardTower.floorBalance(1);
            expect(initialBalance).to.be.gt(0), "Should have a starting balance";
            expect(postEvictionBalance).to.be.equal(0), "Balance should be zero";

        });

    }); // end Floor Balance



});
