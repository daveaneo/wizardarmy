#!/usr/bin/python3
# brownie test -s
# pytest -s <file location and name>

from brownie import Token, Whitelist, Crowdsale, network, config, accounts
import random
import pytest
import time

########################################################
# #################
# Things to test: #
# #################
#
# ✓ -- placeholder
# ✓ fallback function works
# ✓ buyer cant participate under min
# ✓ buyer cant participate over max
# ✓ buyer can participate over ind cap after permission
# ✓ whitelisted buyer can buy tokens
# ✓ non-whitelisted buyer can not buy tokens
# ✓ buyer cant withdraw before end
# ✓ buyer can withdraw after end
# ✓ buyer can withdraw after admin sets flag
# ✓ buyer cant buy when over available in pool
# ✓ admin can't withdraw before end of sale
# ✓ admin can withdraw Matic after end end of sale
# ✓ admin can withdraw my_token after end end of sale
# ✓ admin can fund contract
# ✓ admin can override whitelist requirement
#
##########################################################


VERBOSE = False
initial_setup_complete = False
WEEK = 60 * 60 * 24 * 7
test_counter = 0
MATIC_PRICE = 1.5
my_token_PRICE = 0.25
min_contribution_in_dollars = 25
max_contribution_in_dollars = 1000

# return 10 ** 9 * _matic / price; // matic * (1)

tokens_for_presale = 10 * 10 ** 20
individual_min_in_my_token = 25 * 10 ** 4
individual_max_in_my_token = 25 * 10 ** 7
price_for_full_my_token = 10**18  # Eve: 9 decimals,  Matic: 18 decmials; (price_for_full_my_token*matic/10**9) == $1
sale_duration = 1 * WEEK
time_until_claim = 3 * WEEK


# ignored in brownie test
def main():
    pass


def set_price_for_full_my_token_given_price():
    # my_token_PRICE * my_token_DECIMALS * my_token_QUANTITY == MATIC_PRICE * MATIC_DECIMALS * MATIC_QUANITY
    # MATIC_QUANTITY / my_token_QUANTITY == my_token_PRICE * my_token_DECIMALS / (MATIC_PRICE * MATIC_DECIMALS )
    # my_token_QUANTITY == 1 (one full eve)
    # Solve for MATIC_QUANTITY*MATIC*DECIMALS
    global price_for_full_my_token
    # give price_for_full_my_token per 10** matic
    # price_for_full_my_token = int(10**18* my_token_PRICE * 10**9 / (MATIC_PRICE * 10**18))
    price_for_full_my_token = int(my_token_PRICE * 10**9 / (MATIC_PRICE))


def set_min_max_given_dollars():
    global individual_min_in_my_token
    global individual_max_in_my_token
    decimals = 9

    individual_min_in_my_token = int(10**9*min_contribution_in_dollars / my_token_PRICE)
    individual_max_in_my_token = int(10**9*max_contribution_in_dollars / my_token_PRICE)


def setup_and_display_initial_numbers():
    set_price_for_full_my_token_given_price()
    set_min_max_given_dollars()
    print(f'\n*****************************************\n')
    print(f'my_token Cost: ${my_token_PRICE}')
    print(f'Cost of 1 my_token in Matic (lowest unit): {price_for_full_my_token}')
    print(f'Min individual tokens: {individual_min_in_my_token}')
    print(f'Max individual tokens: {individual_max_in_my_token}')
    print(f'\n*****************************************\n')


def initial_setup():
    # deploy_Bytes()
    # deploy_NTCitizen()
    # mint_NTCitizens(1)
    # deploy_Whitelist()
    setup_and_display_initial_numbers()
    deploy_Token()
    global initial_setup_complete
    initial_setup_complete = True



@pytest.fixture
def recurring_setup():
    # global initial_setup_complete
    # if not initial_setup_complete:
    #     initial_setup()
    # initial_setup()
    if len(Token) == 0:
        initial_setup()

    deploy_Whitelist()

    # deploy_private_presale()


@pytest.fixture(scope="session", autouse=True)
def set_build_and_teardown(request):
    initial_setup()
    # Garbage collector at end of all tests
    def finalizer():
        pass


def message_and_assert(msg, condition):
    global test_counter
    test_counter += 1
    print(f'### Test {test_counter}: {msg} . . . {"Passed" if condition else "FAILED"}')
    assert condition, f'Test {test_counter} has failed'


def deploy_Token():
    token = Token.deploy("Simple Token", "SIMP", 18, 10 ** 24, {'from': accounts[0]}, publish_source=False)
    print(f'token has been deployed: {token}')
    print(f'token[]: {Token}, len : {len(Token)}')
    for t in Token:
        print(f't: {t}')

    print(f'##############################\n')

def deploy_Whitelist():
    wl = Whitelist.deploy({'from': accounts[0]})
    wl.addToWhiteList([accounts[0], accounts[1]])
    message_and_assert("Whitelist deploys successfully", True)


# def deploy_Crowdsale(duration=1 * WEEK, time_until_end=3 * WEEK, price=1, available_tokens=10 ** 20,
#                      min_purchase=10 ** 4, individual_caps=10 ** 10):
#     my_token = Token[-1]
#     wl = Whitelist[-1]
#     cs = Crowdsale.deploy(my_token.address, wl.address, duration, time_until_end, price, available_tokens,
#                            min_purchase, individual_caps, {'from': accounts[0]})
#     return cs


def my_token_to_matic(amount_my_token):
    return int(price_for_full_my_token * amount_my_token / (10**9))


def test_do_nothing(recurring_setup):
    message_and_assert('Not a test', True)


def deploy_private_presale(_sale_duration=sale_duration, _time_until_claim=time_until_claim, _tokens_for_presale=tokens_for_presale):
    my_token = Token[-1]
    wl = Whitelist[-1]
    cs = Crowdsale.deploy(my_token.address, wl.address, _sale_duration, _time_until_claim, price_for_full_my_token, _tokens_for_presale,
                          individual_min_in_my_token, individual_max_in_my_token, {'from': accounts[0]})
    return cs


def test_cant_buy_before_start(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]
    # individual_min_in_matic = int(price_for_full_my_token * individual_min_in_my_token / (10**9))

    # test -- can't buy before ICO starts
    failed = False
    try:
        tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Minting turned off', failed and 'revert: ICO must be active' == error_message)


def test_admin_can_allow_early_withdrawal(recurring_setup):
    _sale_duration = 3
    _time_until_claim = 600
    cs = deploy_private_presale(_sale_duration=_sale_duration, _time_until_claim=_time_until_claim)
    start_time = time.time()
    token = Token[-1]

    # start sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})

    # first test -- should fail
    time_to_sleep = 0 if (time.time() - start_time > _sale_duration) else _sale_duration - (time.time() - start_time)
    time.sleep(time_to_sleep)
    failed = False
    error_message = ""
    try:
        tx = cs.withdrawTokens({'from': accounts[1]})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not claim during sale', failed and "revert: Not time to claim" == error_message)

    # second test -- should fail

    # Third test -- should succeed
    tx = cs.setBuyersCanWithdrawAdminOverride(True, {'from': accounts[0]})
    tokens_before = token.balanceOf(accounts[1])
    tx = cs.withdrawTokens({'from': accounts[1]})
    tokens_after = token.balanceOf(accounts[1])
    message_and_assert('Successfully claimed tokens after admin override', tokens_after == tokens_before + individual_min_in_my_token)


def test_cant_buy_when_over_total_max(recurring_setup):
    cs = deploy_private_presale(_tokens_for_presale=individual_max_in_my_token + 100)
    start_time = time.time()
    token = Token[-1]
    wl = Whitelist[-1]

    # start sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_max_in_my_token)})

    # Over total max should fail
    failed = False
    error_message = "no error"
    tx = wl.addToWhiteList([accounts[2]], {'from': accounts[0]})
    try:
        tx = cs.buy({'from': accounts[2], 'value': my_token_to_matic(individual_max_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    print(f'error message: {error_message}')
    message_and_assert('Can not claim more than available', failed and "revert: Not enough tokens left for sale" == error_message)


def test_cant_buy_after_sale_ends(recurring_setup):
    # todo -- can't buy after ICO is over
    _sale_duration = 1
    _time_until_claim = 8
    cs = deploy_private_presale(_sale_duration=_sale_duration, _time_until_claim=_time_until_claim)
    start_time = time.time()
    token = Token[-1]

    # start sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    # Can't buy after sale, before claiming
    time_to_sleep = 0 if (time.time() - start_time > _sale_duration) else _sale_duration - (time.time() - start_time)
    time.sleep(time_to_sleep+1)
    failed = False
    error_message = "no error occurred"
    try:
        tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not buy after sale before claiming',
                       failed and 'revert: ICO must be active' == error_message)

    # Fails during claiming period
    time_to_sleep = 0 if (time.time() - start_time > _time_until_claim) else _time_until_claim - (
                time.time() - start_time)
    time.sleep(time_to_sleep)
    failed = False
    try:
        tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not buy during claiming period',
                       failed and 'revert: ICO must be active' == error_message)


def test_withdraw_at_appropriate_times(recurring_setup):
    _sale_duration = 3
    _time_until_claim = 6
    cs = deploy_private_presale(_sale_duration=_sale_duration, _time_until_claim=_time_until_claim)
    start_time = time.time()
    token = Token[-1]

    # start sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})

    # first test -- should fail
    failed = False
    error_message = ""
    try:
        tx = cs.withdrawTokens({'from': accounts[1]})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not claim during sale', failed and "revert: Not time to claim" == error_message)

    # second test -- should fail
    time_to_sleep = 0 if (time.time() - start_time > _sale_duration) else _sale_duration - (time.time() - start_time)
    time.sleep(time_to_sleep)
    failed = False
    try:
        tx = cs.withdrawTokens({'from': accounts[1]})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not claim after sale before claiming',
                       failed and 'revert: Not time to claim' == error_message)

    # Third test -- should succeed
    time_to_sleep = 0 if (time.time() - start_time > _time_until_claim) else _time_until_claim - (
                time.time() - start_time)
    time.sleep(time_to_sleep + 1)
    tokens_before = token.balanceOf(accounts[1])
    tx = cs.withdrawTokens({'from': accounts[1]})
    tokens_after = token.balanceOf(accounts[1])
    message_and_assert('Successfully claimed tokens', tokens_after == tokens_before + individual_min_in_my_token)



def test_cant_buy_beyond_min_max(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]
    token = Token[-1]

    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)
    failed = False
    error_message = "no error"
    try:
        tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token - 1)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('can not buy < min',
                       failed and 'revert: have to buy between minPurchase and maxPurchase.' == error_message)

    error_message = "no error"
    failed = False
    try:
        tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_max_in_my_token + 100000)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('can not buy > max',
                       failed and 'revert: have to buy between minPurchase and maxPurchase.' == error_message)


def test_whitelist_works(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]
    token = Token[-1]

    # begin token sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    # Whitelisted
    tokens_available_a = cs.availableTokens()
    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})
    tokens_available_b = cs.availableTokens()
    tx.wait(1)

    message_and_assert('Whitelisted address can purchase', tokens_available_a == tokens_available_b + individual_min_in_my_token)

    # Not whitelisted
    failed = False
    error_message = ""
    try:
        tx = cs.buy({'from': accounts[2], 'value': my_token_to_matic(individual_max_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('can not buy > max', failed and 'revert: not whitelisted' == error_message)


def test_cant_start_without_funding(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]

    error_message = ""
    failed = False
    try:
        tx = cs.start({'from': accounts[0]})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('can not buy > max', failed and 'revert: Sale not yet funded.' == error_message)


def test_can_buy(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]
    token = Token[-1]

    # begin token sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    # Normal purchase
    tokens_available_a = cs.availableTokens()
    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})
    tokens_available_b = cs.availableTokens()
    tx.wait(1)
    message_and_assert('tokens purchased', tokens_available_a == tokens_available_b + individual_min_in_my_token)

    # Fallback Function purchase
    tokens_available_a = cs.availableTokens()
    tx = accounts[1].transfer(cs.address, my_token_to_matic(individual_min_in_my_token))
    tokens_available_b = cs.availableTokens()
    tx.wait(1)
    message_and_assert('tokens purchased via fallback', tokens_available_a == tokens_available_b + individual_min_in_my_token)

    # remove permissions for individual maximum
    tx = cs.setIndividualCapsTurnedOn(False, {'from': accounts[0]})
    tx.wait(1)
    tokens_bought_a = cs.getMyAmountOfTokensBought({'from': accounts[1]})
    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_max_in_my_token + 100000)})
    tokens_bought_b = cs.getMyAmountOfTokensBought({'from': accounts[1]})
    tx.wait(1)
    message_and_assert('tokens purchased via fallback', tokens_bought_b > tokens_bought_a + individual_max_in_my_token) # There round errors exist


def test_price_for_full_my_token_work(recurring_setup):
    cs = deploy_private_presale()
    individual_min_in_matic = int(price_for_full_my_token * individual_min_in_my_token / (10**9))
    expected_tokens = cs.maticToTokenAmount(individual_min_in_matic)
    message_and_assert('conversion price_for_full_my_tokens work', int(expected_tokens * my_token_PRICE/10**9) == min_contribution_in_dollars)


def test_overrides_whitelist(recurring_setup):
    cs = deploy_private_presale()
    # cs = Crowdsale[-1]
    token = Token[-1]

    # begin token sale
    tx = token.approve(cs.address, tokens_for_presale)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tx = cs.start({'from': accounts[0]})
    tx.wait(1)

    # Not whitelisted fails
    failed = False
    error_message = "no error"
    try:
        tx = cs.buy({'from': accounts[2], 'value': my_token_to_matic(individual_max_in_my_token)})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('can not buy > max', failed and 'revert: not whitelisted' == error_message)

    # Admin Override, non-whitelisted passes
    tx = cs.setOnlyWhitelisted(False, {'from': accounts[0]})
    tokens_available_a = cs.availableTokens()
    tx = cs.buy({'from': accounts[2], 'value': my_token_to_matic(individual_min_in_my_token)})
    tokens_available_b = cs.availableTokens()
    tx.wait(1)
    message_and_assert('Whitelisted address can purchase', tokens_available_a == tokens_available_b + individual_min_in_my_token)


def test_admin_withdrawal(recurring_setup):
    _sale_duration = 6
    _time_until_claim = 12
    cs = deploy_private_presale(_sale_duration=_sale_duration, _time_until_claim=_time_until_claim)
    start_time = time.time()
    token = Token[-1]

    # admin can fund contract
    tx = token.approve(cs.address, tokens_for_presale)
    tokens_before = token.balanceOf(cs)
    tx = cs.fundTokenSale({'from': accounts[0]})
    tokens_after = token.balanceOf(cs)
    message_and_assert('Successfully funded token sale', tokens_after == tokens_before + tokens_for_presale)

    tx = cs.start({'from': accounts[0]})
    tx.wait(1)
    tx = cs.buy({'from': accounts[1], 'value': my_token_to_matic(individual_min_in_my_token)})

    # admin can't withdraw before end of sale
    failed = False
    error_message = ""
    try:
        tx = cs.withdrawMatic({'from': accounts[0]})
    except Exception as e:
        failed = True
        error_message = str(e).split('\n')[0]
    message_and_assert('Can not claim during sale', failed and "revert: ICO has ended" == error_message)

    # admin can withdraw Matic after end end of sale
    time_to_sleep = 0 if (time.time() - start_time > _time_until_claim) else _time_until_claim - (time.time() - start_time)
    time.sleep(time_to_sleep)
    matic_before = accounts[0].balance()
    tx = cs.withdrawMatic({'from': accounts[0]})
    matic_after = accounts[0].balance()

    message_and_assert('admin can claim matic', matic_after > matic_before)
    # message_and_assert('correct amount of matic claimed', matic_after == matic_before + individual_min_in_my_token)

    # admin can withdraw my_token after end end of sale
    tokens_before = token.balanceOf(accounts[0])
    unsold_tokens = cs.availableTokens()
    tx = cs.withdrawToken({'from': accounts[0]})
    tokens_after = token.balanceOf(accounts[0])
    message_and_assert('admin can claim my_token', tokens_after > tokens_before)
    message_and_assert('correct amount of my_token claimed', tokens_after == tokens_before + unsold_tokens)

