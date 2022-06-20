#!/usr/bin/python3
# brownie test -s
# pytest -s <file location and name>
# pytest -s tests/test_bondedStaking.py

from brownie import Wizards, Token, WizardTower, network, config, accounts
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
    wizards = Wizards.deploy("Wizards", "WZD", token.address, {'from': accounts[0]})


def deploy_wizard_tower():
    token = Token[-1]
    wizards = Wizards[-1]
    wizard_tower = WizardTower.deploy(token.address, wizards.address, {'from': accounts[0]})

def mint_NFT(x):
    wizards = Wizards[-1]
    tx = None
    for i in range(x):
        tx = wizards.mint({'from': accounts[1]})

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
    active_floors = wizard_tower.activeFloors()
    message_and_assert('No active floors', active_floors == 0)


def test_can_claim_floor(recurring_setup):
    wizard_tower = WizardTower[-1]
    tx = wizard_tower.claimFloor(0, {'from': accounts[1]})
    active_floors = wizard_tower.activeFloors()
    message_and_assert('No active floors', active_floors == 1)
    floor_info = wizard_tower.floorIdToInfo(1)
    print(f'floor_info: {floor_info}')
    message_and_assert('wizard 0 occupies floor 1', floor_info[2] == 0)

