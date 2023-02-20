#!/usr/bin/python3
# brownie test -s
# pytest -s <file location and name>
# pytest -s tests/test_bondedStaking.py

from brownie import Wizards, Token, WizardTower, network, config, accounts, reverts
from brownie.network.state import Chain

import random
import pytest
import time

########################################################
# #################
# Things to test: #
# #################
#
# ✓
# ✓  flow functions correctly
# ✓  flow functions correctly for multiple stakers
#   can add bonus stake
#   can add bonus stake for multiple stakers
#   cannot add stake after submission end period
#   cannot claim stake after submission end period
#   test airdrop? (i dont know if we're gonna use this)
##########################################################


VERBOSE = False
initial_setup_complete = False
WEEK = 60 * 60 * 24 * 7
test_counter = 0


# ignored in brownie test
def main():
    pass


def initial_setup():
    global initial_setup_complete
    initial_setup_complete = True
    # deploy_Token()
    # deploy_NFT()
    # mint_NFT(1)
    print(f'**************INITAL SETUP COMPLETE*********')


@pytest.fixture
def recurring_setup():
    global initial_setup_complete
    if not initial_setup_complete:
        initial_setup()
    # deploy_Token()
    # transfer_tokens_to_account_1()
    deploy_Token()
    deploy_NFT()
    mint_NFT(1)

    print(f'len(Token): {len(Token)}')
    print(f'len(NFT): {len(Wizards)}')
    print(f'len(tower): {len(WizardTower)}')
    deploy_wizard_tower()


def message_and_assert(msg, condition):
    global test_counter
    test_counter += 1
    print(f'### Test {test_counter}: {msg} . . . {"Passed" if condition else "FAILED"}')
    assert condition, f'Test {test_counter} has failed'


def deploy_Token():
    token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})


def deploy_NFT():
    print(f'Token: {Token}, len: {len(Token)}')
    token = Token[-1]
    wizards = Wizards.deploy("Wizards", "WZD", token.address, "http://my_BASE_URI.com", {'from': accounts[0]})


def deploy_wizard_tower():
    token = Token[-1]
    wizards = Wizards[-1]
    wizard_tower = WizardTower.deploy(token.address, wizards.address, {'from': accounts[0]})

def mint_NFT(x):
    wizards = Wizards[-1]
    tx = None
    for i in range(x):
        tx = wizards.mint(0, {'from': accounts[1]})

    tx and tx.wait(1)


def transfer_tokens_to_account_1():
    print(f'Token: {Token}, len: {len(Token)}')
    token = Token[-1]
    tx = token.transfer(accounts[1], 10**14, {'from': accounts[0]})
    tx.wait(1)




def test_do_nothing(recurring_setup):
    message_and_assert('Not a test', True)


def test_fails(recurring_setup):
    # can't stake before
    # can't stake after
    # can't withdraw until withdrawal period

    failed = False
    error_message = "no error"
    try:
        # tx = cs.buy({'from': accounts[2], 'value': EVE_to_matic(individual_max_in_EVE)})
        pass
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    # message_and_assert('can not buy > max', failed and 'revert: not whitelisted' == error_message)


def test_no_active_floors_at_start(recurring_setup):
    wizard_tower = WizardTower[-1]
    contract_settings = wizard_tower.contractSettings()
    print(f'contract_settings: {contract_settings}')
    message_and_assert('No active floors', contract_settings[0] == 0)


def test_can_claim_floor(recurring_setup):
    wizard_tower = WizardTower[-1]
    tx = wizard_tower.claimFloor(1, {'from': accounts[1]})
    active_floors = wizard_tower.contractSettings()[0]
    message_and_assert('No active floors', active_floors == 1)



# def test_chatGPT_tests(recurring_setup):
#     wizard_tower = WizardTower[-1]
#     wizard_owner = accounts[1].address
#     chatGPT_test_claim_floor(wizard_tower, wizard_owner)
#     chatGPT_test_evict(wizard_tower, wizard_owner)


# Tests from ChatGPT, edited maybe
def test_claim_floor(recurring_setup):
    # Test that a wizard can claim a floor in the tower
    wizard_tower = WizardTower[-1]
    tx = wizard_tower.claimFloor(1, {'from': accounts[1]})
    assert wizard_tower.isOnTheTower(1)


def test_evict(recurring_setup):
    # Test that the owner of the contract can evict a wizard from the tower
    wizard_tower = WizardTower[-1]
    token = Token[-1]
    chain = network.state.Chain()
    # current_block = chain.time()


    tx = wizard_tower.claimFloor(1, {'from': accounts[1]})
    tx.wait(1)
    assert wizard_tower.isOnTheTower(1)


    chain.sleep(3600*7) # sleep for a week

    tx = token.transfer(wizard_tower, 10**18, {'from': accounts[0]})
    tx.wait(1)

    initial_balance = wizard_tower.floorBalance(1)
    dao_initial_balance = token.balanceOf(accounts[0].address)
    assert initial_balance > 0

    # chain.sleep(3600*7) # sleep for a week


    # overflow happening. Lets check hte numbers
    total_floor_power = wizard_tower.totalFloorPower()
    floor_power = wizard_tower.floorPower(1)
    print(f'total_floor_power: {total_floor_power}')
    print(f'floor_power: {floor_power}')

    # Evict the wizard from the tower
    tx = wizard_tower.evict(1, {"from": accounts[0]})
    tx.wait(1)

    dao_final_balance = token.balanceOf(accounts[0].address)

    assert not wizard_tower.isOnTheTower(1)
    assert wizard_tower.floorBalance(1) == 0

    # Test that the DAO was properly compensated for eviction
    # todo
    assert dao_initial_balance + initial_balance == dao_final_balance


def test_floor_balance(recurring_setup):
    token = Token[-1]
    wizard_tower = WizardTower[-1]
    token = Token[-1]
    chain = network.state.Chain()

    # Test that the floor balance is calculated correctly
    tx = wizard_tower.claimFloor(1, {"from": accounts[1].address})
    tx.wait(1)
    total_floor_power = wizard_tower.totalFloorPower()
    print(f'total_floor_power: {total_floor_power}')
    assert wizard_tower.floorBalance(1) == wizard_tower.floorPower(1) * token.balanceOf(wizard_tower) // wizard_tower.totalFloorPower()

    chain.sleep(3600*7) # sleep for a week
    total_floor_power = wizard_tower.totalFloorPower()
    print(f'total_floor_power: {total_floor_power}')
    assert wizard_tower.floorBalance(1) == (0 if not total_floor_power else
                                            wizard_tower.floorPower(1) * token.balanceOf(wizard_tower) // wizard_tower.totalFloorPower())

def test_total_floor_power(recurring_setup):
    chain = network.state.Chain()
    wizard_tower = WizardTower[-1]
    # Test that the total floor power is calculated correctly
    tx = wizard_tower.claimFloor(1, {"from": accounts[1].address})
    tx.wait(1)
    chain.sleep(3600*7) # sleep for a week
    assert wizard_tower.totalFloorPower() == wizard_tower.floorPower(1)


def test_only_owner(recurring_setup):
    wizard_tower = WizardTower[-1]
    # Test that only the owner of the contract can call certain functions
    with reverts("Ownable: caller is not the owner"):
        wizard_tower.updateEvictionProceedsReceiver(accounts[1].address, {"from": accounts[1].address})

