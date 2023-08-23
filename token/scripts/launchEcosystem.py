#!/usr/bin/python3
# brownie run scripts/launchEcosystem.py --network polygon-test

from brownie import Wizards, Token, WizardTower, Governance, Appointer, accounts, network, config
# from brownie import accounts, network, config
# from brownie import Appointer
from brownie.network.state import Chain
import json
import os
from datetime import date
import time
import brownie

# Wizards, Token, WizardTower, Governance, Appointer = brownie.Wizards, brownie.Token, brownie.WizardTower, brownie.Governance, brownie.Appointer


DUMP_ABI = True
MINT_WIZARDS = True
USE_PREVIOUS_CONTRACTS = True
dev = accounts.add(config["wallets"]["from_key"]) # accounts[0]
secondary = accounts.add(config["wallets"]["secondary"]) # accounts[1]
print(f'network: {network.show_active()}')
chain = network.state.Chain()
for i in range(2):
    print(f'accounts[{i}]: {accounts[i]}')
required_confirmations = 1 if network.show_active()=="development" else 2

print(f'required_confirmations: {required_confirmations}')


# variables
# image_base_uri = "https://gateway.pinata.cloud/ipfs/Qme17uaAhxas6YE2SC96CAstzeX9jHaZNEH1N2RKoxTRiG/" # simple images
image_base_uri = "https://gateway.pinata.cloud/ipfs/QmancBkpiTwZc5HWcnBpCcWMxXqrmwLMs57UvViKe5QC7D/" # AI Generated

def print_contract_addresses():
    token = Token[-1]
    wizards = Wizards[-1]
    wizard_tower = WizardTower[-1]
    governance = Governance[-1]
    appointer = len(Appointer) > 0 and Appointer[-1]

    print(f'token: {token.address}')
    print(f'wizards: {wizards.address}')
    print(f'wizard_tower: {wizard_tower.address}')
    print(f'governance: {governance.address}')
    print(f'appointer: {appointer and appointer.address}')


def main():
    print_contract_addresses()
    if USE_PREVIOUS_CONTRACTS:
        token = Token[-1]
        wizards = Wizards[-1]
        wizard_tower = WizardTower[-1]
        governance = Governance[-1]
        appointer = Appointer[-1]
        # appointer = Appointer.deploy(wizards.address, {'from': accounts[0]})
    else:
        token = Token.deploy("Test Token", "TST", 18, 1e21, {'from': accounts[0]})
        wizards = Wizards.deploy("Wizards", "WZD", token.address, image_base_uri, {'from': accounts[0]})
        wizard_tower = WizardTower.deploy(token.address, wizards.address, {'from': accounts[0]})
        # wizard_battle = WizardBattle.deploy(token.address, wizards.address, wizard_tower.address, {'from': accounts[0]})
        governance = Governance.deploy(wizards.address, wizard_tower.address, {'from': accounts[0]})
        appointer = Appointer.deploy(wizards.address, {'from': accounts[0]})

    print_contract_addresses()

    # save addresses
    directory = os.getcwd()
    # path = os.path.join(directory, "abi_dump")
    # print(f'path: {path}')
    abi = str(wizards.abi)
    file_path = os.path.join(directory, "deployed_contracts.txt")
    with open(file_path, 'a') as file:
        file.write("\n\n******************************************")
        file.write(f"\n*********   {date.today()}    **************")
        file.write("\n******************************************")
        file.write(f'\ntoken: {token}')
        file.write(f'\nwizardsNFT: {wizards}')
        file.write(f'\nwizard_tower: {wizard_tower}')
        # file.write(f'\nwizard_battle: {wizard_battle}')

    # set modifier addresses
    # tx = wizards.updateBattler(wizard_battle.address, {'from': accounts[0]})
    # tx = wizard_tower.updateBattler(wizard_battle.address, {'from': accounts[0]})
    # tx.wait(required_confirmations)

    contract_settings = wizards.contractSettings()
    initation_cost = contract_settings[1]
    print(f'contractSettings: {contract_settings}')
    print(f'initation_cost: {initation_cost}')

    # create wizards (unitiated, active, exiled, regular)
    if MINT_WIZARDS:
        for i in range(1, 3):
            tx = wizards.mint(i-1, {'from': (accounts[1] if i > 1 else accounts[0])}) # different uplines
            tx.wait(required_confirmations)
            tx = wizards.initiate(i, {'from': (accounts[1] if i > 1 else accounts[0]), "value": initation_cost})
            tx.wait(required_confirmations)
            print(f'wizard {i} initiated, resulting in event: {tx.events}')
            tx = wizard_tower.claimFloor(i, {'from': (accounts[1] if i > 1 else accounts[0])})
            tx.wait(required_confirmations)
            upline = wizards.getUplineId(i)
            print(f'upline of wizard: {upline}')

    # mint uninitiated
    tx = wizards.mint(0, {'from': accounts[1]}) # different uplines
    tx = wizards.mint(0, {'from': accounts[1]}) # different uplines
    tx.wait(required_confirmations)

    # cull (exile) wizard
    tx = wizards.cull(4, {'from': accounts[0]}) # different uplines

    ts = wizards.totalSupply()
    print(f'total wizards: {ts}')

    # fuel tower
    tx = token.transfer(wizard_tower.address, 10**10, {'from': accounts[0]} )
    tx.wait(required_confirmations)

    exit(0)

    # create role contract
    roles_controlled = [i for i in range(15)]
    tx = appointer.createRole("boss", roles_controlled)
    tx.wait(1)
    role = appointer.getRole(1)
    print(f'roll for boss: {role}')





    # chain.sleep(60*9)
    # chain.mine(1)

    # for i in range(5):
    #     outcome = wizard_battle.battle(0, 1)
    #     print(f' battle outcome: {outcome}')
    #     chain.sleep(60)
    #     chain.mine(1)
    #
    # for i in range(5):
    #     outcome = wizard_battle.battle(1, 0)
    #     print(f' battle outcome: {outcome}')
    #     chain.sleep(60)
    #     chain.mine(1)

    '''
    try:
        uri = wizards.tokenURI(1)
        print(f'uri: {uri}')

        uri = wizards.tokenURI(2)
        print(f'uri: {uri}')
    except Exception as e:
        print(f'failed get get uri. error: {e}')
    '''

    # Governance
    #     function createTaskType(string calldata _IPFSHash, uint8 _numFieldsToHash, uint24 _timeBonus, uint40 _begTimestamp,
    #                 uint40 _endTimestamp, uint40 _availableSlots) external onlyBoard {

    '''
    hex_string = "FirstOne"
    tx = governance.createTaskType(hex_string, 1, 24*60*60, 0, 999999999999, 25)
    tx.wait(required_confirmations)
    tasks = governance.getMyAvailableTaskTypes()
    print(f'my tasks: {tasks}')
    print(f'events: {tx.events}')
    tt = governance.getTaskTypeFields(0);
    print(f'tt: {tt}')

    hex_string = "SecondOne"
    tx = governance.createTaskType(hex_string, 5, 24*60*60, 0, 999999999999, 25)
    tx.wait(required_confirmations)
    tasks = governance.getMyAvailableTaskTypes()
    print(f'my tasks: {tasks}')
    print(f'events: {tx.events}')
    tt = governance.getTaskTypeFields(1)
    print(f'tt: {tt}')
    '''


    # Task-claim testing
    '''
    hex_string = "FirstOne"
    tx = governance.createTaskType(hex_string, 5, 24*60*60, 0, 999999999999, 25, {'from': accounts[0]})
    tx.wait(required_confirmations)
    print(f'tasktype created.')

    tx = governance.completeTask(hex_string, "0x0", 1, {'from': accounts[0]})
    tx.wait(required_confirmations)
    print(f'task completed.')

    tx = governance.claimRandomTaskForVerification(2, {'from': accounts[1]})
    tx.wait(required_confirmations)

    tasks = governance.getTasksAssignedToWiz(2, {'from': accounts[1]})
    print(f'tasks for wiz2: {tasks}')

    tasks = governance.getTasksAssignedToWiz(1, {'from': accounts[1]})
    print(f'tasks for wiz1: {tasks}')
    '''

    '''
    hex_string = "SecondOne"
    tx = governance.createTaskType(hex_string, 5, 24*60*60, 0, 999999999999, 25, {'from': accounts[0]})
    tx.wait(required_confirmations)
    print(f'tasktype created.')

    tx = governance.completeTask(hex_string, "0x0", 1, {'from': accounts[0]})
    tx.wait(required_confirmations)
    print(f'task completed.')


    are_tasks_available_to_confirm = governance.areTasksAvailableToConfirm(2)
    print(f'are_tasks_available_to_confirm: {are_tasks_available_to_confirm}')

    tx = governance.claimRandomTaskForVerification(2)
    if tx:
        tx.wait(required_confirmations)
    print(f'tx.events: {tx.events}')

    tx = governance.claimRandomTaskForVerification(2)
    if tx:
        tx.wait(required_confirmations)
    print(f'tx.events: {tx.events}')
    // end Task-Claim testing
    '''



    # For testng hash
    '''
    # not refuted
    # hex_string = 0xc9d2b9a1987d380a8c8b45cf8ad43d19ccea73584eb50c57bd601558fc64a404
    bytes_array = ["0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8", "0x18e9b451e5bb9a4a819352109126d2346a89373c4522fc9538ca265404dae958" ]

    # refuted
    hex_string = 0xfdc8dd941e43d934262f1805847ae879102598ee969b05eee95efbe8d9c21646
    # bytes_array = ["0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8", "0x18e9b451e5bb9a4a819352109126d2346a89373c4522fc9538ca265404dae958"]

    # bytes_array = [ "0x00000000000000000000000000000000000000000000000000000068656c6c6f", "0x0000000000000000000000000000000000000000000000000000006d6f74746f" ]

    tx = governance.testHashing(hex_string, bytes_array, True)
    tx.wait(required_confirmations)
    print(f'events: {tx.events}')
    '''

    # Wizard Battle
    # won; // 0 = > loss, 1 = > win, 2 = > tie?, 3 = > capture



    '''
    wiz_1 = wizards.getStatsGivenId(1)
    wiz_2 = wizards.getStatsGivenId(2)

    print(f'wiz_1: {wiz_1}')
    print(f'wiz_2: {wiz_2}')

    uri = wizards.tokenURI(1)
    print(f'uri: \n\n{uri}')
    '''



    '''
    outcomes = dict()
    for i in range(10):
        wiz_on_floor_1 = wizard_tower.getWizardOnFloor(1)
        wiz_on_floor_2 = wizard_tower.getWizardOnFloor(2)
        wiz_1_floor = wizard_tower.wizardIdToFloor(1)
        wiz_2_floor = wizard_tower.wizardIdToFloor(2)
        print(f'wiz_on_floor_1: {wiz_on_floor_1}')
        print(f'floor for wiz 1: {wiz_1_floor}')
        print(f'wiz_on_floor_2: {wiz_on_floor_2}')
        print(f'floor for wiz 2: {wiz_2_floor}')
        floor_to_attack = wiz_2_floor

        tx = wizard_battle.attack(1, floor_to_attack, {'from': accounts[0], 'value': 1000*100})
        tx.wait(required_confirmations)
        print(f'events: {tx.events}')
        # print(f'outcome: {tx.events["Attack"]["outcome"]}')
        outcome = tx.events["Attack"]["outcome"]
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
    print(f'outcomes: {outcomes}')
    '''

    # test isCallerOnBoard
    '''
    on_board = governance.isCallerOnBoard({'from': accounts[0]})
    print(f'on_board: {on_board}')
    on_board = governance.isCallerOnBoard({'from': accounts[1]})
    print(f'on_board: {on_board}')
    '''






    # PRBMATH
    # a = 9999*10**14
    # b = 10*10**18
    # result = wizard_tower.unsignedPow(a, b)
    # print(f'{a} ^ {b} = {result}')
    # print(f'standard format: {result/(10**18)}')
    # result = wizard_tower.doTheMath()
    # print(f'result: {result} => {result/(10**18)}')
    # for i in range(1, 10):
    #     result = wizard_tower.testGeometricSeriesSum(i)
    #     print(f'result: {result} => {result}')




    if DUMP_ABI:
        print(f'dumping wizardTower...') # sdf sfd sdfsdf sdf
        directory = os.getcwd()
        path = os.path.join(directory, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizard_tower.abi)
        file_path = os.path.join(path, "wizardtower.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)

        print(f'dumping wizards...') # sdf sfd sdfsdf sdf
        directory = os.getcwd()
        path = os.path.join(directory, "abi_dump")
        # print(f'path: {path}')
        abi = str(wizards.abi)
        file_path = os.path.join(path, "wizards.json")
        with open(file_path, 'w') as file:
            # file.write(abi)
            json.dump(abi, file)

        # print(f'dumping wizardBattle...') # sdf sfd sdfsdf sdf
        # directory = os.getcwd()
        # path = os.path.join(directory, "abi_dump")
        # # print(f'path: {path}')
        # abi = str(wizard_battle.abi)
        # file_path = os.path.join(path, "wizardbattle.json")
        # with open(file_path, 'w') as file:
        #     # file.write(abi)
        #     json.dump(abi, file)


        # todo -- save addresses

    # return Wizards.deploy("Wizards", "WZD", {'from': accounts[0]})
